// lib/services/report_service.dart
// Servicio central de reportes financieros.
// Orquesta: DataService → procesamiento → ChatService (IA) → helpers de exportación.
//
// Conexiones:
//   messageProvider.dart llama a generateReport() y generateChart()
//   chatMain.dart llama a exportToPDF() y exportToExcel() desde los botones
//   ReportService llama internamente a DataService, ChatService, PdfHelper, ExcelHelper

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';
import 'package:flutter_application_4_geodesica/services/chat_service.dart';
import 'package:flutter_application_4_geodesica/services/data_service.dart';
import 'package:flutter_application_4_geodesica/helpers/pdf_helper.dart';
import 'package:flutter_application_4_geodesica/helpers/excel_helper.dart';
import 'package:flutter_application_4_geodesica/widgets/chart_widget.dart';

class ReportService {
  final ChatService _chatService = ChatService();

  // ─────────────────────────────────────────────────────────────
  // GENERAR REPORTE COMPLETO
  // Llamado desde messageProvider._handleReportOrChart()
  // Devuelve un ReportModel listo para mostrar en el chat y exportar
  // ─────────────────────────────────────────────────────────────
  Future<ReportModel> generateReport(
    String type, {
    DateTime? from,
    DateTime? to,
  }) async {
    final now = DateTime.now();
    final rangeFrom = from ?? DateTime(now.year, now.month, 1);
    final rangeTo = to ?? now;

    // 1. Obtener datos crudos y filtrar por fecha
    final rawData = await _fetchFiltered(rangeFrom, rangeTo);

    // 2. Calcular cifras financieras
    final financialData = _calcularCifras(rawData);

    // 3. Construir datos para gráfica
    final chartData = _buildChartData(rawData);

    // 4. Solicitar resumen a IA
    final summary = await _chatService.generateReportText({
      'tipo': _labelTipo(type),
      'periodo': _formatPeriodo(rangeFrom, rangeTo),
      'ingresos': financialData['ingresos'],
      'gastos': financialData['gastos'],
      'utilidad': financialData['utilidad'],
    });

    return ReportModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _labelTipo(type),
      type: _parseTipo(type),
      chartType: _chartDefault(type),
      from: rangeFrom,
      to: rangeTo,
      generatedAt: DateTime.now(),
      chartData: chartData,
      summary: summary,
      financialData: financialData,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // GENERAR WIDGET DE GRÁFICA
  // Llamado desde messageProvider._handleReportOrChart()
  // El widget resultante se guarda en RichMessage.chartWidget
  // ─────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────
  // EXPORTAR A PDF
  // Llamado desde messageProvider.exportReportToPDF()
  // Retorna el File para que chatMain pueda compartirlo con Share
  // ─────────────────────────────────────────────────────────────
  Future<File> exportToPDF(ReportModel report) async {
    final file = await PdfHelper.generateReportPdf(report);
    report.pdfFile = file;
    return file;
  }

  // ─────────────────────────────────────────────────────────────
  // EXPORTAR A EXCEL
  // Llamado desde messageProvider.exportReportToExcel()
  // ─────────────────────────────────────────────────────────────
  Future<File> exportToExcel(ReportModel report) async {
    final file = await ExcelHelper.generateReportExcel(report);
    report.excelFile = file;
    return file;
  }

  // ─────────────────────────────────────────────────────────────
  // MÉTODO LEGACY — compatibilidad con el chatMain.dart original
  // que llamaba a ReportService().getIncomeStatement()
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getIncomeStatement({String? period}) async {
    final rawData = await DataService.getMovimientosRaw();

    // Filtrar por período si se especifica (formato 'YYYY-MM')
    List<Map<String, dynamic>> filtered = rawData;
    if (period != null) {
      filtered =
          rawData
              .where(
                (m) =>
                    m['periodo']?.toString().startsWith(period) == true ||
                    m['fecha_creacion']?.toString().startsWith(period) == true,
              )
              .toList();
    }

    final cifras = _calcularCifras(filtered);
    return {
      'periodo': period ?? 'Actual',
      'ingresos': cifras['ingresos'],
      'gastos': cifras['gastos'],
      'utilidad': cifras['utilidad'],
    };
  }

  // ─────────────────────────────────────────────────────────────
  // INTERNOS
  // ─────────────────────────────────────────────────────────────

  /// Obtiene movimientos crudos del backend y los filtra por rango de fechas
  Future<List<Map<String, dynamic>>> _fetchFiltered(
    DateTime from,
    DateTime to,
  ) async {
    final raw = await DataService.getMovimientosRaw();
    return raw.where((m) {
      final fechaStr =
          m['fecha_creacion']?.toString() ?? m['periodo']?.toString() ?? '';
      final fecha = DateTime.tryParse(fechaStr);
      if (fecha == null) return true; // incluir si no parseable
      return !fecha.isBefore(from) && !fecha.isAfter(to);
    }).toList();
  }

  /// Calcula ingresos, gastos y utilidad a partir de los movimientos
  Map<String, dynamic> _calcularCifras(List<Map<String, dynamic>> data) {
    double ingresos = 0;
    double gastos = 0;

    for (final m in data) {
      final valor = double.tryParse(m['valor_cop']?.toString() ?? '0') ?? 0;
      final cat = (m['categoria'] ?? '').toString().toLowerCase();

      if (cat.contains('ingreso') ||
          cat.contains('venta') ||
          cat.contains('cobro')) {
        ingresos += valor;
      } else if (cat.contains('gasto') ||
          cat.contains('costo') ||
          cat.contains('pago') ||
          cat.contains('egreso')) {
        gastos += valor;
      } else {
        // Si no se puede clasificar, se asume ingreso si positivo
        if (valor > 0) {
          ingresos += valor;
        } else {
          gastos += valor.abs();
        }
      }
    }

    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'utilidad': ingresos - gastos,
      'total_movimientos': data.length,
    };
  }

  /// Agrupa por categoría para alimentar las gráficas
  List<Map<String, dynamic>> _buildChartData(List<Map<String, dynamic>> data) {
    final Map<String, double> porCategoria = {};
    for (final m in data) {
      final cat = m['categoria']?.toString() ?? 'Sin categoría';
      final valor = double.tryParse(m['valor_cop']?.toString() ?? '0') ?? 0;
      porCategoria[cat] = (porCategoria[cat] ?? 0) + valor.abs();
    }

    // Ordenar de mayor a menor valor
    final entries =
        porCategoria.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((e) => {'label': e.key, 'value': e.value}).toList();
  }

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

  ChartType _chartDefault(String type) {
    switch (type.toLowerCase()) {
      case 'flujo':
        return ChartType.line;
      case 'balance':
        return ChartType.pie;
      default:
        return ChartType.bar;
    }
  }

  String _formatPeriodo(DateTime from, DateTime to) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Del ${fmt(from)} al ${fmt(to)}';
  }
}
