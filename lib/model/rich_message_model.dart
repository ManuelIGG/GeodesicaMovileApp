// lib/model/rich_message_model.dart
// Extiende la lógica de UserMessageModel para soportar mensajes con
// reportes, gráficas y timestamps. Usado por messageProvider y chatMain.

import 'package:flutter/widgets.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';

/// Tipo de contenido del mensaje en el chat
enum MessageContentType { text, report }

/// Mensaje enriquecido que puede contener texto plano o un reporte
/// con gráfica interactiva. Compatible con el flujo existente de
/// UserMessageModel pero con capacidades extendidas.
class RichMessage {
  final String id;
  final String rol; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  final MessageContentType contentType;

  /// Si contentType == report, aquí está el modelo completo
  final ReportModel? report;

  /// Widget de gráfica preconstruido por ReportService.generateChart()
  /// Se almacena como Widget para insertarlo directamente en la burbuja
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

  bool get isUser => rol == 'user';
  bool get isReport => contentType == MessageContentType.report;

  /// Texto legible del tiempo transcurrido desde la generación
  /// Ejemplo: "justo ahora", "hace 5 min", "hace 2 h"
  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  /// Convierte a Map para guardar en Firestore (solo texto, sin widget)
  Map<String, dynamic> toFirestoreMap(String chatId) => {
    'chat_id': chatId,
    'rol': rol,
    'message': text,
    'content_type': contentType.name,
  };

  /// Crea un RichMessage plano desde un mapa de Firestore
  factory RichMessage.fromFirestoreMap(Map<String, dynamic> map) {
    return RichMessage(
      id: map['id']?.toString() ?? '',
      rol: map['rol'] ?? 'assistant',
      text: map['message'] ?? '',
      timestamp: DateTime.now(),
      contentType: MessageContentType.text,
    );
  }
}
