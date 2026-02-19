// =============================================================================
// lib/services/report_service.dart
// =============================================================================
// CAMBIOS RESPECTO A LA VERSIÓN ORIGINAL:
//   1. exportToPDF() ahora llama a UploadService.subirReporte() automáticamente
//      después de generar el PDF local → asigna report.pdfPublicUrl
//   2. exportToExcel() hace lo mismo → asigna report.excelPublicUrl
//   3. Se añade _subirArchivoYActualizar() como método interno reutilizable
//      que encapsula toda la lógica de subida y actualización del modelo
//   4. Los métodos de exportación ahora devuelven (File, String?) donde
//      String? es la URL pública (puede ser null si la subida falló)
//
// FLUJO COMPLETO NUEVO:
//   1. messageProvider llama a generateReport()      → ReportModel local
//   2. Usuario pulsa "PDF" en la burbuja del chat
//   3. messageProvider llama a exportToPDF(report)
//      a. PdfHelper.generateReportPdf()              → File local
//      b. UploadService.subirReporte()               → URL pública en Donweb
//      c. report.pdfPublicUrl = url                 → modelo actualizado
//      d. Share.shareXFiles()                        → compartir localmente
//   4. messageProvider llama a _actualizarMensajeEnFirestore()
//      → persiste la URL pública en el snapshot de Firestore
//
// CONEXIONES:
//   → messageProvider.dart llama a generateReport(), exportToPDF(), exportToExcel()
//   → UploadService maneja la comunicación HTTP con el servidor PHP
//   → ReportModel recibe las URLs y las persiste vía toSnapshotMap()
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';
import 'package:flutter_application_4_geodesica/services/chat_service.dart';
import 'package:flutter_application_4_geodesica/services/data_service.dart';
import 'package:flutter_application_4_geodesica/services/upload_service.dart';
import 'package:flutter_application_4_geodesica/helpers/pdf_helper.dart';
import 'package:flutter_application_4_geodesica/helpers/excel_helper.dart';
import 'package:flutter_application_4_geodesica/widgets/chart_widget.dart';

class ReportService {
  final ChatService _chatService = ChatService();

  // ── GENERAR REPORTE COMPLETO ──────────────────────────────────────────────
  // Sin cambios respecto a la versión original.
  // Llamado desde messageProvider._handleReportOrChart()
  // Devuelve un ReportModel listo para mostrar en el chat y exportar.
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

    // 4. Solicitar resumen a la IA (OpenAI)
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
      // pdfPublicUrl / excelPublicUrl son null hasta que el usuario exporte
    );
  }

  // ── GENERAR WIDGET DE GRÁFICA ─────────────────────────────────────────────
  // Sin cambios. Llamado desde messageProvider._handleReportOrChart()
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

  // ── EXPORTAR A PDF + SUBIR AL SERVIDOR ───────────────────────────────────
  // MODIFICADO: ahora sube automáticamente el PDF al servidor Donweb.
  //
  // Parámetros:
  //   [report]    — ReportModel con los datos financieros
  //   [mensajeId] — ID del RichMessage en Firestore (para vincular en la BD)
  //   [chatId]    — ID del chat (para la consulta por chat en reporte_query.php)
  //
  // Retorna el File local (para compartir con Share.shareXFiles).
  // Como efecto secundario: asigna report.pdfPublicUrl si la subida fue exitosa.
  Future<File> exportToPDF(
    ReportModel report, {
    String mensajeId = '',
    String chatId = '',
  }) async {
    // Paso 1: Generar el archivo PDF localmente (sin cambios)
    final file = await PdfHelper.generateReportPdf(report);
    report.pdfFile = file;

    // Paso 2: Subir el PDF al servidor Donweb (NUEVO)
    await _subirArchivoYActualizar(
      archivo: file,
      report: report,
      formato: 'pdf',
      mensajeId: mensajeId,
      chatId: chatId,
    );

    // Retornamos el archivo local para que messageProvider pueda compartirlo
    return file;
  }

  // ── EXPORTAR A EXCEL + SUBIR AL SERVIDOR ──────────────────────────────────
  // MODIFICADO: ahora sube automáticamente el Excel al servidor Donweb.
  Future<File> exportToExcel(
    ReportModel report, {
    String mensajeId = '',
    String chatId = '',
  }) async {
    // Paso 1: Generar el archivo Excel localmente (sin cambios)
    final file = await ExcelHelper.generateReportExcel(report);
    report.excelFile = file;

    // Paso 2: Subir el Excel al servidor Donweb (NUEVO)
    await _subirArchivoYActualizar(
      archivo: file,
      report: report,
      formato: 'excel',
      mensajeId: mensajeId,
      chatId: chatId,
    );

    return file;
  }

  // ── MÉTODO INTERNO: SUBIR ARCHIVO Y ACTUALIZAR EL MODELO ─────────────────
  // Encapsula la lógica de subida para evitar duplicar código entre PDF y Excel.
  //
  // FLUJO:
  //   1. Llama a UploadService.subirReporte() con los metadatos del reporte
  //   2. Si la subida fue exitosa, asigna la URL al campo correspondiente
  //      del ReportModel (pdfPublicUrl o excelPublicUrl)
  //   3. Si falla, imprime el error pero NO lanza excepción
  //      → el reporte sigue funcionando localmente aunque falle la subida
  Future<void> _subirArchivoYActualizar({
    required File archivo,
    required ReportModel report,
    required String formato, // 'pdf' | 'excel'
    required String mensajeId,
    required String chatId,
  }) async {
    // Intentar subir al servidor
    final resultado = await UploadService.subirReporte(
      archivo: archivo,
      mensajeId: mensajeId,
      chatId: chatId,
      tipo: report.type.name, // Ej: 'estadoResultados'
      titulo: report.title, // Ej: 'Estado de Resultados'
      periodo: report.periodoFormateado, // Ej: 'Del 01/01/2025 al 31/01/2025'
      formato: formato,
    );

    if (resultado.success && resultado.publicUrl != null) {
      // ✅ Subida exitosa: asignar URL pública al modelo
      if (formato == 'pdf') {
        report.pdfPublicUrl = resultado.publicUrl;
      } else {
        report.excelPublicUrl = resultado.publicUrl;
      }
      report.dbReporteId = resultado.dbId;

      debugPrint('[ReportService] ✅ $formato subido: ${resultado.publicUrl}');
    } else {
      // ⚠️ Fallo silencioso: el reporte sigue funcionando localmente
      // La URL quedará null y la burbuja no mostrará el botón "Ver online"
      debugPrint(
        '[ReportService] ⚠️ No se pudo subir $formato: ${resultado.errorMessage}',
      );
    }
  }

  // ── MÉTODO LEGACY ─────────────────────────────────────────────────────────
  // Compatibilidad con el chatMain.dart original
  Future<Map<String, dynamic>> getIncomeStatement({String? period}) async {
    final rawData = await DataService.getMovimientosRaw();

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

  // ── MÉTODOS INTERNOS ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchFiltered(
    DateTime from,
    DateTime to,
  ) async {
    final raw = await DataService.getMovimientosRaw();
    return raw.where((m) {
      final fechaStr =
          m['fecha_creacion']?.toString() ?? m['periodo']?.toString() ?? '';
      final fecha = DateTime.tryParse(fechaStr);
      if (fecha == null) return true;
      return !fecha.isBefore(from) && !fecha.isAfter(to);
    }).toList();
  }

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
        if (valor > 0)
          ingresos += valor;
        else
          gastos += valor.abs();
      }
    }

    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'utilidad': ingresos - gastos,
      'total_movimientos': data.length,
    };
  }

  List<Map<String, dynamic>> _buildChartData(List<Map<String, dynamic>> data) {
    final Map<String, double> porCategoria = {};
    for (final m in data) {
      final cat = m['categoria']?.toString() ?? 'Sin categoría';
      final valor = double.tryParse(m['valor_cop']?.toString() ?? '0') ?? 0;
      porCategoria[cat] = (porCategoria[cat] ?? 0) + valor.abs();
    }

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
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return 'Del ${fmt(from)} al ${fmt(to)}';
  }
}
