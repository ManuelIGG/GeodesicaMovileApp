// lib/presentation/providers/messageProvider.dart
// ============================================================================
// CAMBIO PRINCIPAL respecto a la versión anterior:
//
//   _handleReportOrChart() ahora pasa intent.originalText a generateReport()
//   como parámetro [userPrompt]. Ese texto es el que la IA usa para decidir
//   qué SQL generar, qué datos traer y qué gráfica construir.
//
//   SIN ESTE CAMBIO: generateReport() recibe solo el tipo ('resultados') y
//   el rango de fechas, lo cual siempre produce el mismo reporte genérico.
//
//   CON ESTE CAMBIO: generateReport() recibe el texto completo del usuario,
//   por ejemplo "muéstrame ventas por producto esta semana en gráfica pastel",
//   y la IA construye exactamente eso.
//
//   El resto del archivo no cambia — persistencia, exportación y streams
//   funcionan igual que antes.
// ============================================================================

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

  String _currentChatId = '';

  // ── Getters ───────────────────────────────────────────────────────────────
  List<RichMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;

  // ── CARGAR MENSAJES DESDE FIRESTORE (sin cambios) ─────────────────────────
  Future<void> loadMessagesFromChat(String chatId) async {
    _currentChatId = chatId;

    final dbMessages = await _dbHelper.getMessagesForChat(chatId);
    final mensajesBase =
        dbMessages.map((m) => RichMessage.fromFirestoreMap(m)).toList();

    _messages =
        mensajesBase.map((msg) {
          if (msg.isReport && msg.report != null) {
            final chartData = msg.report!.chartData;
            final chartType = _chartTypeStr(msg.report!.chartType);
            final chartWidget = _reportService.generateChart(
              chartType,
              chartData,
            );
            return msg.withChartWidget(chartWidget);
          }
          return msg;
        }).toList();

    notifyListeners();
  }

  // ── STREAM EN TIEMPO REAL (sin cambios) ───────────────────────────────────
  Stream<List<RichMessage>> getMessagesStream(String chatId) {
    return _dbHelper
        .getMessagesForChatStream(chatId)
        .map(
          (list) => list.map((m) => RichMessage.fromFirestoreMap(m)).toList(),
        );
  }

  // ── ENVIAR MENSAJE (sin cambios estructurales) ────────────────────────────
  Future<void> enviarMensajeConIA(String chatId, String textoUsuario) async {
    _currentChatId = chatId;

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
      final intent = _chatService.parseCommand(textoUsuario);

      if (intent.isReportRequest || intent.isChartRequest) {
        // ── CAMBIO: se pasa el intent completo (con originalText) ────────────
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

  // ═══════════════════════════════════════════════════════════════════════════
  // FLUJO DE REPORTE Y GRÁFICA — CAMBIO PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // ANTES: generateReport(intent.reportType, from: ..., to: ...)
  //   El tipo 'resultados' siempre producía el mismo reporte genérico.
  //
  // AHORA: generateReport(intent.reportType, ..., userPrompt: intent.originalText)
  //   El texto completo del usuario llega a ChatService.generateReportFromPrompt()
  //   donde la IA decide qué SQL ejecutar, qué datos traer y qué gráfica hacer.
  //
  // EJEMPLO:
  //   Usuario: "muéstrame las ventas por vendedor de esta semana en barras"
  //   intent.originalText = "muéstrame las ventas por vendedor de esta semana en barras"
  //   → IA genera: SELECT u.nombre AS label, SUM(v.total) AS value
  //                FROM ventas v JOIN usuarios u ON u.idUsuario = v.idVendedor
  //                WHERE v.fecha_venta >= '2025-05-26' AND v.fecha_venta <= '2025-06-01'
  //                AND v.estado != 'cancelada' GROUP BY u.idUsuario ORDER BY value DESC
  //   → chartType: 'bar'
  //   → title: 'Ventas por Vendedor — Semana del 26/05 al 01/06'
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _handleReportOrChart(String chatId, CommandIntent intent) async {
    // 1. Generar reporte dinámico según el texto exacto del usuario
    //    CAMBIO CLAVE: se pasa userPrompt: intent.originalText
    final report = await _reportService.generateReport(
      intent.reportType ?? 'resultados',
      from: intent.timeRange.start,
      to: intent.timeRange.end,
      userPrompt: intent.originalText, // ← CAMBIO: texto original del usuario
    );

    // 2. El chartType ahora viene de la IA (no del intent hardcodeado)
    //    Pero si el usuario especificó uno en el intent, lo respetamos
    final chartTypeStr = intent.chartType ?? _chartTypeStr(report.chartType);

    // 3. Crear widget de gráfica con los datos que trajo la IA
    final chartWidget = _reportService.generateChart(
      chartTypeStr,
      report.chartData,
    );

    // 4. Construir timestamp legible
    final now = report.generatedAt;
    final hora = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // 5. Asignar ID fijo al mensaje para referenciarlo en el upload
    final msgId = _newId();

    // 6. Construir el RichMessage
    //    El título ahora es dinámico (viene de la IA, no hardcodeado)
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

    // 8. Persistir en Firestore con snapshot del reporte
    await _persistir(chatId, botMsg);
  }

  // ── EXPORTAR A PDF (sin cambios) ──────────────────────────────────────────
  Future<void> exportReportToPDF(String messageId) async {
    final msg = _findById(messageId);
    if (msg?.report == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final file = await _reportService.exportToPDF(
        msg!.report!,
        mensajeId: messageId,
        chatId: _currentChatId,
      );

      if (msg.report!.pdfPublicUrl != null) {
        await _actualizarUrlEnFirestore(
          messageId: messageId,
          campo: 'pdf_public_url',
          url: msg.report!.pdfPublicUrl!,
          report: msg.report!,
        );
      }

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

  // ── EXPORTAR A EXCEL (sin cambios) ────────────────────────────────────────
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

  // ── ACTUALIZAR URL EN FIRESTORE (sin cambios) ─────────────────────────────
  Future<void> _actualizarUrlEnFirestore({
    required String messageId,
    required String campo,
    required String url,
    required ReportModel report,
  }) async {
    try {
      final snapshotActualizado = report.toSnapshotMap();
      await _dbHelper.updateMessageFields(messageId, {
        campo: url,
        'report_snapshot': snapshotActualizado,
      });
      debugPrint('[ChatProvider] ✅ URL actualizada en Firestore: $url');
    } catch (e) {
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
