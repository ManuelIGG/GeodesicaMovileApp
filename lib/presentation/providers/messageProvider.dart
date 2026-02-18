// lib/presentation/providers/messageProvider.dart
// Provider central del chat. Modificado para:
//   1. Soportar RichMessage (mensajes con gráficas y reportes)
//   2. Detectar intención del usuario con ChatService.parseCommand()
//   3. Generar reportes completos con ReportService
//   4. Exportar a PDF/Excel y compartir
//
// Conexiones:
//   → ChatService (parseCommand, getChatResponse)
//   → ReportService (generateReport, generateChart, exportToPDF, exportToExcel)
//   → DatabaseHelper (persistir mensajes en Firestore)
//   → chatMain.dart (consume messages, isLoading, exportar)

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_application_4_geodesica/data/database_helper.dart';
import 'package:flutter_application_4_geodesica/model/rich_message_model.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';
import 'package:flutter_application_4_geodesica/services/chat_service.dart';
import 'package:flutter_application_4_geodesica/services/report_service.dart';

class ChatProvider with ChangeNotifier {
  // ── Estado ────────────────────────────────────────────────────
  List<RichMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  // ── Dependencias ──────────────────────────────────────────────
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ChatService _chatService = ChatService();
  final ReportService _reportService = ReportService();

  // ── Getters ───────────────────────────────────────────────────
  List<RichMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;

  // ─────────────────────────────────────────────────────────────
  // CARGAR MENSAJES DESDE FIRESTORE
  // Llamado por chatMain._loadChat()
  // ─────────────────────────────────────────────────────────────
  Future<void> loadMessagesFromChat(String chatId) async {
    final dbMessages = await _dbHelper.getMessagesForChat(chatId);
    _messages = dbMessages.map((m) => RichMessage.fromFirestoreMap(m)).toList();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // STREAM EN TIEMPO REAL (para chatMain si se usa StreamBuilder)
  // ─────────────────────────────────────────────────────────────
  Stream<List<RichMessage>> getMessagesStream(String chatId) {
    return _dbHelper
        .getMessagesForChatStream(chatId)
        .map(
          (list) => list.map((m) => RichMessage.fromFirestoreMap(m)).toList(),
        );
  }

  // ─────────────────────────────────────────────────────────────
  // ENVIAR MENSAJE — PUNTO DE ENTRADA PRINCIPAL
  // Llamado por chatMain._sendMessage()
  // Detecta si es conversacional, reporte o solicitud de gráfica
  // ─────────────────────────────────────────────────────────────
  Future<void> enviarMensajeConIA(String chatId, String textoUsuario) async {
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
      // 2. Parsear intención
      final intent = _chatService.parseCommand(textoUsuario);

      if (intent.isReportRequest || intent.isChartRequest) {
        // ── Flujo de reporte / gráfica ─────────────────────────
        await _handleReportOrChart(chatId, intent);
      } else {
        // ── Flujo conversacional ───────────────────────────────
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

  // ─────────────────────────────────────────────────────────────
  // FLUJO DE REPORTE Y GRÁFICA
  // Llamado internamente cuando se detecta una CommandIntent válida
  // ─────────────────────────────────────────────────────────────
  Future<void> _handleReportOrChart(String chatId, CommandIntent intent) async {
    // Generar reporte completo (datos + resumen IA)
    final report = await _reportService.generateReport(
      intent.reportType ?? 'resultados',
      from: intent.timeRange.start,
      to: intent.timeRange.end,
    );

    // Determinar tipo de gráfica (explícita o por defecto del reporte)
    final chartTypeStr = intent.chartType ?? _chartTypeStr(report.chartType);

    // Crear widget de gráfica
    final chartWidget = _reportService.generateChart(
      chartTypeStr,
      report.chartData,
    );

    // Construir timestamp legible para el mensaje
    final now = report.generatedAt;
    final hora = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // Construir el mensaje enriquecido
    final botMsg = RichMessage(
      id: _newId(),
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

    _addMessage(botMsg);
    // Los mensajes de reporte también se guardan en Firestore (solo texto)
    await _persistir(chatId, botMsg);
  }

  // ─────────────────────────────────────────────────────────────
  // EXPORTAR A PDF — llamado desde chatMain botón "PDF"
  // ─────────────────────────────────────────────────────────────
  Future<void> exportReportToPDF(String messageId) async {
    final msg = _findById(messageId);
    if (msg?.report == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final file = await _reportService.exportToPDF(msg!.report!);
      // Compartir el archivo PDF con la app de sistema
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte financiero — ${msg.report!.title}');
    } catch (e) {
      debugPrint('Error exportando PDF: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // EXPORTAR A EXCEL — llamado desde chatMain botón "Excel"
  // ─────────────────────────────────────────────────────────────
  Future<void> exportReportToExcel(String messageId) async {
    final msg = _findById(messageId);
    if (msg?.report == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final file = await _reportService.exportToExcel(msg!.report!);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte Excel — ${msg.report!.title}');
    } catch (e) {
      debugPrint('Error exportando Excel: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UTILIDADES
  // ─────────────────────────────────────────────────────────────
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
