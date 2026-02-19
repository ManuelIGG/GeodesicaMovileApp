// =============================================================================
// lib/model/rich_message_model.dart
// =============================================================================
// CAMBIOS RESPECTO A LA VERSIÓN ORIGINAL:
//   1. toFirestoreMap() ahora incluye el snapshot del ReportModel y las URLs
//      públicas → permite reconstruir el reporte al recargar el chat.
//   2. fromFirestoreMap() ahora reconstruye el ReportModel si hay snapshot
//      guardado en Firestore (campo 'report_snapshot').
//   3. Se añade campo `reportPublicUrl` como acceso rápido a la URL.
//
// FLUJO DE PERSISTENCIA:
//   [Creación]   messageProvider._handleReportOrChart()
//                  → RichMessage con report: ReportModel
//                  → _persistir() → toFirestoreMap() → guardado en Firestore
//                     Incluye: report_snapshot (toda la data del reporte)
//
//   [Restauración] messageProvider.loadMessagesFromChat()
//                  → Firestore devuelve map con 'report_snapshot'
//                  → fromFirestoreMap() → reconstruye RichMessage
//                     con report: ReportModel.fromSnapshotMap()
//                     y chartWidget: reconstruido en messageProvider
//
// CONEXIONES:
//   → messageProvider.dart llama toFirestoreMap() / fromFirestoreMap()
//   → chatMain.dart lee isReport, chartWidget, report.anyPublicUrl
//   → report_service.dart asigna report.pdfPublicUrl / excelPublicUrl
// =============================================================================

import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';

/// Tipo de contenido del mensaje en el chat
enum MessageContentType { text, report }

/// Mensaje enriquecido que puede contener texto plano o un reporte
/// con gráfica interactiva y persistencia en Firestore.
class RichMessage {
  final String id;
  final String rol; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  final MessageContentType contentType;

  /// Si contentType == report, aquí está el modelo completo.
  /// Se reconstruye desde Firestore al recargar el chat.
  final ReportModel? report;

  /// Widget de gráfica preconstruido por ReportService.generateChart().
  /// NO se persiste en Firestore (los Widgets no son serializables).
  /// Se reconstruye en messageProvider.loadMessagesFromChat() desde chartData.
  Widget? chartWidget;

  RichMessage({
    required this.id,
    required this.rol,
    required this.text,
    required this.timestamp,
    this.contentType = MessageContentType.text,
    this.report,
    this.chartWidget,
  });

  // ── GETTERS ───────────────────────────────────────────────────────────────
  bool get isUser => rol == 'user';
  bool get isReport => contentType == MessageContentType.report;

  /// URL pública del primer formato disponible del reporte (PDF > Excel)
  /// Null si aún no se ha subido al servidor.
  String? get reportPublicUrl => report?.anyPublicUrl;

  /// Texto legible del tiempo transcurrido desde la generación.
  /// Ejemplo: "justo ahora", "hace 5 min", "hace 2 h", "hace 3 d"
  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  // ── SERIALIZACIÓN → FIRESTORE ─────────────────────────────────────────────

  /// Convierte el mensaje a Map para guardar en Firestore.
  ///
  /// NUEVO: si el mensaje es de tipo reporte, incluye:
  ///   - 'report_snapshot': Map con toda la data del ReportModel (sin File/Widget)
  ///   - 'pdf_public_url' / 'excel_public_url': URLs del servidor
  ///
  /// Esto permite reconstruir completamente el mensaje al recargar el chat,
  /// incluyendo los datos de la gráfica y las cifras financieras.
  Map<String, dynamic> toFirestoreMap(String chatId) {
    final map = <String, dynamic>{
      'chat_id': chatId,
      'rol': rol,
      'message': text,
      'content_type': contentType.name,
      // El timestamp se guarda para restaurar el orden y el relativeTime
      'timestamp': timestamp.toIso8601String(),
    };

    // ── DATOS ADICIONALES PARA MENSAJES DE REPORTE ───────────────────────
    if (isReport && report != null) {
      // Snapshot serializado del ReportModel → permite reconstrucción offline
      // Usamos jsonEncode + jsonDecode para asegurar que los tipos sean primitivos
      // y compatibles con Firestore (que no acepta tipos personalizados de Dart)
      map['report_snapshot'] = report!.toSnapshotMap();

      // URLs del servidor guardadas también a nivel de mensaje para acceso rápido
      if (report!.pdfPublicUrl != null) {
        map['pdf_public_url'] = report!.pdfPublicUrl!;
      }
      if (report!.excelPublicUrl != null) {
        map['excel_public_url'] = report!.excelPublicUrl!;
      }
    }

    return map;
  }

  // ── DESERIALIZACIÓN ← FIRESTORE ───────────────────────────────────────────

  /// Crea un RichMessage desde un mapa de Firestore.
  ///
  /// NUEVO: Si el mapa contiene 'report_snapshot', reconstruye el ReportModel
  /// completo incluyendo chartData y financialData.
  /// El chartWidget se reconstruye en messageProvider (no se guarda en Firestore).
  factory RichMessage.fromFirestoreMap(Map<String, dynamic> map) {
    // ── Parsear contentType ───────────────────────────────────────────────
    final contentTypeStr = map['content_type']?.toString() ?? 'text';
    final contentType = MessageContentType.values.firstWhere(
      (e) => e.name == contentTypeStr,
      orElse: () => MessageContentType.text,
    );

    // ── Parsear timestamp ─────────────────────────────────────────────────
    final timestampStr = map['timestamp']?.toString();
    final timestamp =
        timestampStr != null
            ? DateTime.tryParse(timestampStr) ?? DateTime.now()
            : DateTime.now();

    // ── Reconstruir ReportModel si hay snapshot ───────────────────────────
    ReportModel? report;
    if (contentType == MessageContentType.report) {
      final rawSnapshot = map['report_snapshot'];

      if (rawSnapshot != null) {
        // El snapshot puede venir como Map (Firestore lo guarda así)
        // o como String JSON (si se guardó serializado)
        Map<String, dynamic> snapshotMap;
        if (rawSnapshot is Map) {
          snapshotMap = Map<String, dynamic>.from(rawSnapshot);
        } else if (rawSnapshot is String) {
          try {
            snapshotMap = jsonDecode(rawSnapshot) as Map<String, dynamic>;
          } catch (_) {
            snapshotMap = {};
          }
        } else {
          snapshotMap = {};
        }

        if (snapshotMap.isNotEmpty) {
          // Sobrescribir URLs con las guardadas a nivel de mensaje si existen
          // (pueden haber sido actualizadas después de la exportación)
          if (map['pdf_public_url'] != null) {
            snapshotMap['pdfPublicUrl'] = map['pdf_public_url'];
          }
          if (map['excel_public_url'] != null) {
            snapshotMap['excelPublicUrl'] = map['excel_public_url'];
          }

          try {
            report = ReportModel.fromSnapshotMap(snapshotMap);
          } catch (e) {
            // Si falla la reconstrucción, el mensaje aparecerá sin gráfica
            // pero con el texto del resumen (no rompe la UI)
            report = null;
          }
        }
      }
    }

    return RichMessage(
      id: map['id']?.toString() ?? '',
      rol: map['rol']?.toString() ?? 'assistant',
      text: map['message']?.toString() ?? '',
      timestamp: timestamp,
      contentType: contentType,
      report: report,
      // chartWidget se asigna después por messageProvider.loadMessagesFromChat()
      // porque requiere construir un Widget de Flutter (no serializable)
    );
  }

  /// Crea una copia del mensaje con el chartWidget asignado.
  /// Usado por messageProvider para agregar la gráfica reconstruida
  /// después de deserializar el mensaje desde Firestore.
  RichMessage withChartWidget(Widget? widget) {
    return RichMessage(
      id: id,
      rol: rol,
      text: text,
      timestamp: timestamp,
      contentType: contentType,
      report: report,
      chartWidget: widget,
    );
  }
}
