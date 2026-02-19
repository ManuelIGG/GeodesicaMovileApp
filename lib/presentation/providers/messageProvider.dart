// =============================================================================
// lib/presentation/providers/messageProvider.dart
// =============================================================================
// CAMBIOS RESPECTO A LA VERSIÓN ORIGINAL:
//
//   1. loadMessagesFromChat() ahora:
//      a. Carga mensajes desde Firestore (igual que antes)
//      b. Para cada mensaje de tipo 'report' que tiene snapshot guardado,
//         reconstruye el chartWidget usando ReportService.generateChart()
//         → el reporte vuelve a aparecer con su gráfica al reabrir el chat
//
//   2. _handleReportOrChart() ahora:
//      a. Genera el reporte (igual que antes)
//      b. Persiste el snapshot en Firestore ANTES de exportar
//         → el mensaje ya queda guardado aunque el usuario no exporte
//
//   3. exportReportToPDF() / exportReportToExcel() ahora:
//      a. Pasan mensajeId y chatId a report_service para que UploadService
//         pueda vincular el archivo subido con el mensaje en Firestore
//      b. Después de exportar, llaman a _actualizarUrlEnFirestore()
//         para persistir la URL pública recién obtenida en el snapshot
//
//   4. Se añade _actualizarUrlEnFirestore() — actualiza el campo
//      pdf_public_url / excel_public_url en el documento Firestore
//      del mensaje correspondiente, sin borrar los demás campos.
//
// CONEXIONES:
//   → ChatService (parseCommand, getChatResponse)
//   → ReportService (generateReport, generateChart, exportToPDF, exportToExcel)
//   → DatabaseHelper (persistir y actualizar mensajes en Firestore)
//   → chatMain.dart (consume messages, isLoading, exportar, reportPublicUrl)
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_application_4_geodesica/data/database_helper.dart';
import 'package:flutter_application_4_geodesica/model/rich_message_model.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';
import 'package:flutter_application_4_geodesica/services/chat_service.dart';
import 'package:flutter_application_4_geodesica/services/report_service.dart';

class ChatProvider with ChangeNotifier {
  // ── Estado ────────────────────────────────────────────────────────────────
  List<RichMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  // ── Dependencias ──────────────────────────────────────────────────────────
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ChatService _chatService = ChatService();
  final ReportService _reportService = ReportService();

  // chatId activo — se asigna en loadMessagesFromChat() y se usa en los exports
  String _currentChatId = '';

  // ── Getters ───────────────────────────────────────────────────────────────
  List<RichMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;

  // ── CARGAR MENSAJES DESDE FIRESTORE ───────────────────────────────────────
  // MODIFICADO: después de cargar los mensajes de texto, reconstruye los
  // chartWidgets de los mensajes de tipo 'report' que tienen snapshot guardado.
  //
  // Esto permite que al reabrir el chat, las burbujas de reporte aparezcan
  // completas con su gráfica, sin necesidad de volver a llamar al backend.
  Future<void> loadMessagesFromChat(String chatId) async {
    _currentChatId = chatId;

    // 1. Cargar todos los mensajes desde Firestore
    //    RichMessage.fromFirestoreMap() ya reconstruye el ReportModel si
    //    existe 'report_snapshot' en el documento.
    final dbMessages = await _dbHelper.getMessagesForChat(chatId);
    final mensajesBase =
        dbMessages.map((m) => RichMessage.fromFirestoreMap(m)).toList();

    // 2. Para cada mensaje de reporte, reconstruir el chartWidget
    //    (Los widgets no se pueden serializar, hay que recrearlos en memoria)
    _messages =
        mensajesBase.map((msg) {
          if (msg.isReport && msg.report != null) {
            final chartData = msg.report!.chartData;
            final chartType = _chartTypeStr(msg.report!.chartType);

            // Reconstruir el widget de gráfica con los mismos datos guardados
            final chartWidget = _reportService.generateChart(
              chartType,
              chartData,
            );

            // Devolver una copia del mensaje con el widget asignado
            return msg.withChartWidget(chartWidget);
          }
          // Mensajes de texto: sin cambios
          return msg;
        }).toList();

    notifyListeners();
  }

  // ── STREAM EN TIEMPO REAL ─────────────────────────────────────────────────
  // Sin cambios respecto a la versión original.
  Stream<List<RichMessage>> getMessagesStream(String chatId) {
    return _dbHelper
        .getMessagesForChatStream(chatId)
        .map(
          (list) => list.map((m) => RichMessage.fromFirestoreMap(m)).toList(),
        );
  }

  // ── ENVIAR MENSAJE — PUNTO DE ENTRADA PRINCIPAL ───────────────────────────
  // Sin cambios estructurales. Se añade guardado de _currentChatId.
  Future<void> enviarMensajeConIA(String chatId, String textoUsuario) async {
    _currentChatId = chatId;

    // 1. Agregar mensaje del usuario al estado local y a Firestore
    final userMsg = RichMessage(
      id: _newId(),
      rol: 'user',
      text: textoUsuario,
      timestamp: DateTime.now(),
    );
    _addMessage(userMsg);
    await _persistir(chatId, userMsg);

    _isTyping = true;
    notifyListeners();

    try {
      // 2. Parsear intención (reporte/gráfica vs. conversacional)
      final intent = _chatService.parseCommand(textoUsuario);

      if (intent.isReportRequest || intent.isChartRequest) {
        await _handleReportOrChart(chatId, intent);
      } else {
        final respuesta = await _chatService.getChatResponse(textoUsuario);
        final botMsg = RichMessage(
          id: _newId(),
          rol: 'assistant',
          text: respuesta,
          timestamp: DateTime.now(),
        );
        _addMessage(botMsg);
        await _persistir(chatId, botMsg);
      }
    } catch (e) {
      final errorMsg = RichMessage(
        id: _newId(),
        rol: 'assistant',
        text:
            '⚠️ Ocurrió un error al procesar tu solicitud. '
            'Por favor, intenta de nuevo.',
        timestamp: DateTime.now(),
      );
      _addMessage(errorMsg);
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // ── FLUJO DE REPORTE Y GRÁFICA ────────────────────────────────────────────
  // MODIFICADO: el snapshot del reporte se persiste en Firestore tan pronto
  // como se genera el mensaje (sin esperar a que el usuario exporte).
  // Esto garantiza que el reporte aparezca al recargar aunque nunca se exporte.
  Future<void> _handleReportOrChart(String chatId, CommandIntent intent) async {
    // 1. Generar reporte completo (datos + resumen IA)
    final report = await _reportService.generateReport(
      intent.reportType ?? 'resultados',
      from: intent.timeRange.start,
      to: intent.timeRange.end,
    );

    // 2. Determinar tipo de gráfica
    final chartTypeStr = intent.chartType ?? _chartTypeStr(report.chartType);

    // 3. Crear widget de gráfica
    final chartWidget = _reportService.generateChart(
      chartTypeStr,
      report.chartData,
    );

    // 4. Construir timestamp legible
    final now = report.generatedAt;
    final hora = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // 5. Asignar un ID fijo al mensaje para poder referenciarlo en el upload
    final msgId = _newId();

    // 6. Construir el RichMessage con el reporte
    final botMsg = RichMessage(
      id: msgId,
      rol: 'assistant',
      text:
          '📊 **${report.title}**\n'
          '🕐 Actualizado a las $hora · ${report.periodoFormateado}\n\n'
          '${report.summary}',
      timestamp: now,
      contentType: MessageContentType.report,
      report: report,
      chartWidget: chartWidget,
    );

    // 7. Mostrar en la UI
    _addMessage(botMsg);

    // 8. Persistir en Firestore CON el snapshot del reporte
    //    → el mensaje queda guardado con todos los datos de la gráfica
    //    → al reabrir el chat, fromFirestoreMap() reconstruirá el ReportModel
    await _persistir(chatId, botMsg);
  }

  // ── EXPORTAR A PDF ────────────────────────────────────────────────────────
  // MODIFICADO:
  //   - Pasa mensajeId y chatId a exportToPDF() para el upload
  //   - Después de exportar, actualiza la URL pública en Firestore
  Future<void> exportReportToPDF(String messageId) async {
    final msg = _findById(messageId);
    if (msg?.report == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Exportar localmente Y subir al servidor
      final file = await _reportService.exportToPDF(
        msg!.report!,
        mensajeId: messageId, // ← NUEVO: para vincular en la BD del servidor
        chatId: _currentChatId, // ← NUEVO: para agrupar por chat
      );

      // Si la subida fue exitosa, persistir la URL en Firestore
      // para que esté disponible al recargar el chat
      if (msg.report!.pdfPublicUrl != null) {
        await _actualizarUrlEnFirestore(
          messageId: messageId,
          campo: 'pdf_public_url',
          url: msg.report!.pdfPublicUrl!,
          report: msg.report!,
        );
      }

      // Compartir el archivo localmente (comportamiento original)
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte financiero — ${msg.report!.title}');
    } catch (e) {
      debugPrint('[ChatProvider] Error exportando PDF: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── EXPORTAR A EXCEL ──────────────────────────────────────────────────────
  // MODIFICADO: igual que exportReportToPDF() pero para Excel.
  Future<void> exportReportToExcel(String messageId) async {
    final msg = _findById(messageId);
    if (msg?.report == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final file = await _reportService.exportToExcel(
        msg!.report!,
        mensajeId: messageId,
        chatId: _currentChatId,
      );

      if (msg.report!.excelPublicUrl != null) {
        await _actualizarUrlEnFirestore(
          messageId: messageId,
          campo: 'excel_public_url',
          url: msg.report!.excelPublicUrl!,
          report: msg.report!,
        );
      }

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte Excel — ${msg.report!.title}');
    } catch (e) {
      debugPrint('[ChatProvider] Error exportando Excel: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── ACTUALIZAR URL EN FIRESTORE ────────────────────────────────────────────
  // NUEVO: actualiza el campo de URL pública en el documento Firestore del mensaje
  // y también actualiza el snapshot del reporte para que incluya la nueva URL.
  //
  // Esto garantiza que al recargar el chat, la URL esté disponible en el snapshot
  // y el botón "Ver Online" aparezca en la burbuja.
  // chatId se eliminó de los parámetros: updateMessageFields() del
  // database_helper real solo recibe (messageId, campos) — sin chatId.
  Future<void> _actualizarUrlEnFirestore({
    required String messageId,
    required String campo, // 'pdf_public_url' o 'excel_public_url'
    required String url,
    required ReportModel report,
  }) async {
    try {
      // Snapshot actualizado del reporte con la nueva URL ya asignada
      // (report.pdfPublicUrl / excelPublicUrl ya fueron seteados por ReportService)
      final snapshotActualizado = report.toSnapshotMap();

      // Llamada correcta: 2 parámetros, igual que la firma de database_helper.dart
      await _dbHelper.updateMessageFields(messageId, {
        campo: url,
        'report_snapshot': snapshotActualizado,
      });

      debugPrint('[ChatProvider] ✅ URL actualizada en Firestore: $url');
    } catch (e) {
      // Fallo silencioso — el archivo ya fue compartido, la URL se pierde
      // solo en Firestore pero está en memoria para esta sesión
      debugPrint(
        '[ChatProvider] ⚠️ No se pudo actualizar URL en Firestore: $e',
      );
    }
  }

  // ── UTILIDADES ────────────────────────────────────────────────────────────
  void _addMessage(RichMessage msg) {
    _messages.add(msg);
    notifyListeners();
  }

  Future<void> _persistir(String chatId, RichMessage msg) async {
    await _dbHelper.insertChatMessage(msg.toFirestoreMap(chatId));
  }

  RichMessage? _findById(String id) {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _chartTypeStr(ChartType t) {
    switch (t) {
      case ChartType.pie:
        return 'pie';
      case ChartType.line:
        return 'line';
      default:
        return 'bar';
    }
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void addMessage(RichMessage message) {
    _addMessage(message);
  }
}
