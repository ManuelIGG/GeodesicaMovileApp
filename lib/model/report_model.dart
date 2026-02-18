// lib/model/report_model.dart
// Modelo central de reportes financieros.
// Conecta: report_service.dart → messageProvider.dart → chatMain.dart

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

  /// Archivos exportados (se asignan después de llamar a exportToPDF/Excel)
  File? pdfFile;
  File? excelFile;

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
  });

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
}
