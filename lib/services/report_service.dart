// lib/services/report_service.dart
// ============================================================================
// CAMBIO PRINCIPAL respecto a la versión anterior:
//
//   generateReport() ya NO usa getMovimientosRaw() + _calcularCifras() fijos.
//   Ahora llama a ChatService.generateReportFromPrompt(userPrompt) que:
//     1. Le pide a la IA que genere el SQL exacto para lo que pidió el usuario
//     2. Ejecuta ese SQL en la BD real vía DataService.executeSql()
//     3. Devuelve chartData, financialData, chartType y summary ya construidos
//
//   RESULTADO: cada reporte es diferente según la solicitud del usuario.
//   Ejemplos:
//     "ventas por producto esta semana en pastel"
//       → SQL: SELECT p.nombre AS label, SUM(...) AS value ... GROUP BY producto
//       → chartType: pie, datos reales de esa semana
//
//     "evolución de ingresos del último mes"
//       → SQL: SELECT DATE(fecha_venta) AS label, SUM(total) AS value ... GROUP BY día
//       → chartType: line, un punto por día
//
//     "stock crítico por categoría"
//       → SQL: SELECT c.nombre AS label, COUNT(*) AS value ... WHERE stock<=minimo
//       → chartType: bar, solo productos en riesgo
//
//   ARCHIVOS QUE CAMBIAN JUNTO A ESTE:
//     → chat_service.dart   (agrega generateReportFromPrompt)
//     → messageProvider.dart (pasa originalText a generateReport)
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';
import 'package:flutter_application_4_geodesica/services/chat_service.dart';
import 'package:flutter_application_4_geodesica/services/upload_service.dart';
import 'package:flutter_application_4_geodesica/helpers/pdf_helper.dart';
import 'package:flutter_application_4_geodesica/helpers/excel_helper.dart';
import 'package:flutter_application_4_geodesica/widgets/chart_widget.dart';

class ReportService {
  final ChatService _chatService = ChatService();

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAR REPORTE — AHORA DINÁMICO
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // CAMBIO: se añade el parámetro obligatorio [userPrompt] con el texto
  // original del usuario. Es el que se pasa a generateReportFromPrompt()
  // para que la IA sepa exactamente qué tipo de reporte construir.
  //
  // Los parámetros [from] y [to] se mantienen por compatibilidad pero ya no
  // se usan para filtrar directamente — la IA los interpreta desde el prompt.
  //
  // LLAMADO DESDE: messageProvider._handleReportOrChart()
  Future<ReportModel> generateReport(
    String type, {
    DateTime? from,
    DateTime? to,
    // NUEVO: texto original del usuario para que la IA lo interprete
    String userPrompt = '',
  }) async {
    final now = DateTime.now();
    final rangeFrom = from ?? DateTime(now.year, now.month, 1);
    final rangeTo = to ?? now;

    // ── El prompt para la IA incluye el texto del usuario Y el rango detectado
    // Si el usuario no pasó prompt (llamada legacy), usamos el tipo como base.
    final promptEfectivo =
        userPrompt.isNotEmpty
            ? userPrompt
            : 'Genera un reporte de ${_labelTipo(type)} '
                'del período ${_formatPeriodo(rangeFrom, rangeTo)}';

    // ── Llamar al nuevo método de ChatService que hace todo el trabajo ───────
    // generateReportFromPrompt:
    //   1. Genera el SQL correcto para lo que pide el usuario
    //   2. Ejecuta el SQL en la BD real
    //   3. Construye chartData, financialData, title, chartType y summary
    ReportPromptResult resultado;
    try {
      resultado = await _chatService.generateReportFromPrompt(
        promptEfectivo,
        from: rangeFrom,
        to: rangeTo,
      );
    } catch (e) {
      // Fallback: si falla la IA, crear un reporte vacío con mensaje de error
      debugPrint('[ReportService] Error en generateReportFromPrompt: $e');
      resultado = ReportPromptResult(
        title: _labelTipo(type),
        chartType: 'bar',
        reportType: type,
        chartData: [],
        financialData: {'ingresos': 0.0, 'gastos': 0.0, 'utilidad': 0.0},
        summary:
            'No fue posible obtener los datos. '
            'Verifica tu conexión e intenta de nuevo.',
      );
    }

    // ── Construir el ReportModel con los datos que la IA trajo ───────────────
    return ReportModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: resultado.title,
      type: _parseTipo(resultado.reportType),
      chartType: _parseChartType(resultado.chartType),
      from: rangeFrom,
      to: rangeTo,
      generatedAt: DateTime.now(),
      chartData: resultado.chartData,
      summary: resultado.summary,
      financialData: resultado.financialData,
      // pdfPublicUrl / excelPublicUrl siguen siendo null hasta que el usuario exporte
    );
  }

  // ── GENERAR WIDGET DE GRÁFICA (sin cambios) ───────────────────────────────
  Widget generateChart(String chartType, List<Map<String, dynamic>> data) {
    switch (chartType.toLowerCase()) {
      case 'pie':
        return GeodesicaPieChart(data: data);
      case 'line':
        return GeodesicaLineChart(data: data);
      case 'bar':
      default:
        return GeodesicaBarChart(data: data);
    }
  }

  // ── EXPORTAR A PDF (sin cambios) ──────────────────────────────────────────
  Future<File> exportToPDF(
    ReportModel report, {
    String mensajeId = '',
    String chatId = '',
  }) async {
    final file = await PdfHelper.generateReportPdf(report);
    report.pdfFile = file;

    await _subirArchivoYActualizar(
      archivo: file,
      report: report,
      formato: 'pdf',
      mensajeId: mensajeId,
      chatId: chatId,
    );

    return file;
  }

  // ── EXPORTAR A EXCEL (sin cambios) ────────────────────────────────────────
  Future<File> exportToExcel(
    ReportModel report, {
    String mensajeId = '',
    String chatId = '',
  }) async {
    final file = await PdfHelper.generateReportPdf(report);
    report.excelFile = file;

    await _subirArchivoYActualizar(
      archivo: file,
      report: report,
      formato: 'excel',
      mensajeId: mensajeId,
      chatId: chatId,
    );

    return file;
  }

  // ── SUBIR ARCHIVO AL SERVIDOR (sin cambios) ───────────────────────────────
  Future<void> _subirArchivoYActualizar({
    required File archivo,
    required ReportModel report,
    required String formato,
    required String mensajeId,
    required String chatId,
  }) async {
    final resultado = await UploadService.subirReporte(
      archivo: archivo,
      mensajeId: mensajeId,
      chatId: chatId,
      tipo: report.type.name,
      titulo: report.title,
      periodo: report.periodoFormateado,
      formato: formato,
    );

    if (resultado.success && resultado.publicUrl != null) {
      if (formato == 'pdf') {
        report.pdfPublicUrl = resultado.publicUrl;
      } else {
        report.excelPublicUrl = resultado.publicUrl;
      }
      report.dbReporteId = resultado.dbId;
      debugPrint('[ReportService] ✅ $formato subido: ${resultado.publicUrl}');
    } else {
      debugPrint(
        '[ReportService] ⚠️ No se pudo subir $formato: ${resultado.errorMessage}',
      );
    }
  }

  // ── MÉTODO LEGACY — compatibilidad con chatMain.dart ─────────────────────
  Future<Map<String, dynamic>> getIncomeStatement({String? period}) async {
    // Mantiene compatibilidad pero ya no se usa en el flujo principal
    return {
      'periodo': period ?? 'Actual',
      'ingresos': 0.0,
      'gastos': 0.0,
      'utilidad': 0.0,
    };
  }

  // ── UTILIDADES DE PARSEO ─────────────────────────────────────────────────

  String _labelTipo(String type) {
    const m = {
      'balance': 'Balance General',
      'resultados': 'Estado de Resultados',
      'flujo': 'Flujo de Efectivo',
      'patrimonio': 'Estado de Cambios en el Patrimonio',
    };
    return m[type.toLowerCase()] ?? 'Reporte Financiero';
  }

  ReportType _parseTipo(String type) {
    switch (type.toLowerCase()) {
      case 'balance':
        return ReportType.balanceGeneral;
      case 'flujo':
        return ReportType.flujoEfectivo;
      case 'patrimonio':
        return ReportType.estadoCambiosPatrimonio;
      default:
        return ReportType.estadoResultados;
    }
  }

  ChartType _parseChartType(String type) {
    switch (type.toLowerCase()) {
      case 'pie':
        return ChartType.pie;
      case 'line':
        return ChartType.line;
      default:
        return ChartType.bar;
    }
  }

  String _formatPeriodo(DateTime from, DateTime to) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Del ${fmt(from)} al ${fmt(to)}';
  }
}
