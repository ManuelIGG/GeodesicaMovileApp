// =============================================================================
// lib/model/report_model.dart
// =============================================================================
// CAMBIOS RESPECTO A LA VERSIÓN ORIGINAL:
//   1. Se añade `publicUrl` (String?) — URL del archivo subido al servidor
//   2. Se añade `pdfPublicUrl` y `excelPublicUrl` separados por formato
//   3. Se añade `toSnapshotMap()` — serializa datos para guardar en Firestore
//      (permite reconstruir el reporte al recargar el chat sin datos del backend)
//   4. Se añade `fromSnapshotMap()` — reconstruye ReportModel desde Firestore
//
// FLUJO NUEVO:
//   generateReport() → ReportModel creado
//   exportToPDF()    → genera archivo local → sube al servidor → pdfPublicUrl asignado
//   exportToExcel()  → genera archivo local → sube al servidor → excelPublicUrl asignado
//   toFirestoreMap() → persiste snapshot en Firestore (incluyendo publicUrl)
//   fromFirestoreMap() → al recargar, reconstruye el ReportModel sin llamar al backend
//
// CONEXIONES:
//   → report_service.dart crea y exporta instancias de este modelo
//   → rich_message_model.dart usa toSnapshotMap() / fromSnapshotMap()
//   → messageProvider.dart restaura reportes desde Firestore usando fromSnapshotMap()
// =============================================================================

import 'dart:io';

/// Tipos de reporte según Decreto 2420 de 2015
enum ReportType {
  balanceGeneral,
  estadoResultados,
  flujoEfectivo,
  estadoCambiosPatrimonio,
}

/// Tipos de visualización gráfica soportados
enum ChartType { pie, bar, line }

class ReportModel {
  final String id;
  final String title;
  final ReportType type;
  final ChartType chartType;

  /// Rango temporal del reporte
  final DateTime from;
  final DateTime to;

  /// Momento exacto de generación — usado para timestamps relativos en el chat
  final DateTime generatedAt;

  /// Datos procesados para gráfica: [{label, value}, ...]
  final List<Map<String, dynamic>> chartData;

  /// Resumen generado por la IA
  final String summary;

  /// Cifras financieras clave
  final Map<String, dynamic> financialData;

  /// Archivos exportados localmente (temporales, se pierden al cerrar la app)
  File? pdfFile;
  File? excelFile;

  // ── CAMPOS NUEVOS ─────────────────────────────────────────────────────────

  /// URL pública del PDF en el servidor Donweb.
  /// Se asigna automáticamente después de exportToPDF() + upload exitoso.
  /// Null si aún no se ha exportado/subido.
  String? pdfPublicUrl;

  /// URL pública del Excel en el servidor Donweb.
  /// Se asigna automáticamente después de exportToExcel() + upload exitoso.
  String? excelPublicUrl;

  /// ID de la fila en la tabla `reportes` del servidor (para referencia)
  int? dbReporteId;

  ReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.chartType,
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.chartData,
    required this.summary,
    required this.financialData,
    this.pdfFile,
    this.excelFile,
    this.pdfPublicUrl, // ← NUEVO
    this.excelPublicUrl, // ← NUEVO
    this.dbReporteId, // ← NUEVO
  });

  // ── GETTERS DE CONVENIENCIA ───────────────────────────────────────────────

  /// Nombre legible del tipo de reporte
  String get typeName {
    switch (type) {
      case ReportType.balanceGeneral:
        return 'Balance General';
      case ReportType.estadoResultados:
        return 'Estado de Resultados';
      case ReportType.flujoEfectivo:
        return 'Flujo de Efectivo';
      case ReportType.estadoCambiosPatrimonio:
        return 'Estado de Cambios en el Patrimonio';
    }
  }

  /// Período formateado para encabezados normativos
  String get periodoFormateado {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Del ${fmt(from)} al ${fmt(to)}';
  }

  double get ingresos => (financialData['ingresos'] as num?)?.toDouble() ?? 0.0;
  double get gastos => (financialData['gastos'] as num?)?.toDouble() ?? 0.0;
  double get utilidad => ingresos - gastos;

  /// Devuelve la primera URL pública disponible (PDF preferido sobre Excel)
  /// Null si ninguno ha sido subido aún.
  String? get anyPublicUrl => pdfPublicUrl ?? excelPublicUrl;

  /// true si al menos un formato ya fue subido al servidor
  bool get isUploaded => pdfPublicUrl != null || excelPublicUrl != null;

  // ── SERIALIZACIÓN PARA FIRESTORE ──────────────────────────────────────────

  /// Convierte el ReportModel a un Map serializable para guardar en Firestore.
  /// IMPORTANTE: No incluye File ni Widget (no son serializables).
  /// Este snapshot permite reconstruir el reporte al recargar la conversación.
  Map<String, dynamic> toSnapshotMap() => {
    // Identificación
    'id': id,
    'title': title,
    'type': type.name, // Ej: 'estadoResultados'
    'chartType': chartType.name, // Ej: 'bar'
    // Rango temporal
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'generatedAt': generatedAt.toIso8601String(),

    // Datos de gráfica (List<Map>) — se serializa como JSON
    'chartData': chartData,

    // Resumen IA
    'summary': summary,

    // Cifras financieras
    'financialData': financialData,

    // URLs públicas del servidor (clave para la recarga dinámica)
    'pdfPublicUrl': pdfPublicUrl,
    'excelPublicUrl': excelPublicUrl,
    'dbReporteId': dbReporteId,
  };

  /// Reconstruye un ReportModel desde el snapshot guardado en Firestore.
  /// Llamado por RichMessage.fromFirestoreMap() al recargar el chat.
  factory ReportModel.fromSnapshotMap(Map<String, dynamic> map) {
    // Parsear el enum ReportType desde su nombre en string
    final reportType = ReportType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => ReportType.estadoResultados,
    );

    // Parsear el enum ChartType desde su nombre en string
    final chartType = ChartType.values.firstWhere(
      (e) => e.name == map['chartType'],
      orElse: () => ChartType.bar,
    );

    // Parsear fechas desde ISO 8601
    DateTime parseDate(String? val) =>
        val != null ? DateTime.tryParse(val) ?? DateTime.now() : DateTime.now();

    // Parsear chartData (puede venir como List<dynamic> desde Firestore)
    final rawChartData = map['chartData'];
    List<Map<String, dynamic>> chartData = [];
    if (rawChartData is List) {
      chartData =
          rawChartData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
    }

    // Parsear financialData
    final rawFinancial = map['financialData'];
    final financialData =
        rawFinancial is Map
            ? Map<String, dynamic>.from(rawFinancial)
            : <String, dynamic>{};

    return ReportModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      type: reportType,
      chartType: chartType,
      from: parseDate(map['from']),
      to: parseDate(map['to']),
      generatedAt: parseDate(map['generatedAt']),
      chartData: chartData,
      summary: map['summary']?.toString() ?? '',
      financialData: financialData,
      pdfPublicUrl: map['pdfPublicUrl']?.toString(),
      excelPublicUrl: map['excelPublicUrl']?.toString(),
      dbReporteId: map['dbReporteId'] as int?,
    );
  }
}
