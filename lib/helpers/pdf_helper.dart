// lib/helpers/pdf_helper.dart
// Genera PDFs normativos según Decreto 2420 de 2015.
// Llamado desde report_service.exportToPDF() y desde chatMain cuando
// el usuario presiona "Exportar PDF" en la burbuja de reporte.
//
// Dependencias: pdf: ^3.10.8, path_provider: ^2.1.3, printing: ^5.12.0

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_application_4_geodesica/model/report_model.dart';

class PdfHelper {
  // ── Colores ──────────────────────────────────────────────────
  static const _primario = PdfColor.fromInt(0xFF1D413E);
  static const _acento = PdfColor.fromInt(0xFF46E0C9);
  static const _fondo = PdfColor.fromInt(0xFFF0F9F7);
  static const _rojo = PdfColor.fromInt(0xFFD32F2F);
  static const _grisClaro = PdfColor.fromInt(0xFFB0C4C2);

  static Future<File> generateReportPdf(ReportModel report) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(
      locale: 'es_CO',
      symbol: 'COP ',
      decimalDigits: 0,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        // Encabezado normativo que aparece en cada página
        header: (_) => _header(report),
        // Pie de página con número de página y timestamp
        footer: (ctx) => _footer(ctx, report),
        build:
            (_) => [
              pw.SizedBox(height: 12),
              _notaNormativa(),
              pw.SizedBox(height: 16),
              _tablaFinanciera(report, fmt),
              pw.SizedBox(height: 16),
              _seccionResumen(report),
              pw.SizedBox(height: 20),
              if (report.chartData.isNotEmpty) _tablaCategorias(report, fmt),
            ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(report.generatedAt);
    final file = File('${dir.path}/geodesica_${report.type.name}_$ts.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Encabezado ────────────────────────────────────────────────
  static pw.Widget _header(ReportModel report) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _primario,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EMPRESA DEMOS S.A.S.',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'NIT: 900.123.456-7',
            style: pw.TextStyle(color: _grisClaro, fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            report.typeName.toUpperCase(),
            style: pw.TextStyle(
              color: _acento,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            report.periodoFormateado,
            style: pw.TextStyle(color: _grisClaro, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ── Nota normativa ────────────────────────────────────────────
  static pw.Widget _notaNormativa() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _fondo,
        border: pw.Border.all(color: _acento, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        'Este reporte fue preparado de acuerdo con el Marco Técnico Normativo '
        'para Microempresas establecido en el Decreto 2420 de 2015 y sus '
        'modificaciones, adoptado en Colombia por la Contaduría General de la Nación.',
        style: pw.TextStyle(
          fontSize: 8,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  // ── Tabla financiera principal ────────────────────────────────
  static pw.Widget _tablaFinanciera(ReportModel report, NumberFormat fmt) {
    final esNegativo = report.utilidad < 0;
    final filas = [
      ['Ingresos por actividades ordinarias', fmt.format(report.ingresos)],
      ['Gastos por naturaleza', fmt.format(report.gastos)],
      ['RESULTADO INTEGRAL TOTAL', fmt.format(report.utilidad)],
    ];

    final borderStyle = pw.TableBorder.all(
      color: PdfColors.grey300,
      width: 0.5,
    );

    return pw.Table(
      border: borderStyle,
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.5),
      },
      children: [
        // Encabezado
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primario),
          children:
              ['CONCEPTO', 'VALOR (COP)'].map((h) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              }).toList(),
        ),
        // Filas
        ...filas.asMap().entries.map((e) {
          final isLast = e.key == filas.length - 1;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isLast ? _fondo : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  e.value[0],
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isLast ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  e.value[1],
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isLast ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: isLast && esNegativo ? _rojo : PdfColors.black,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Resumen IA ────────────────────────────────────────────────
  static pw.Widget _seccionResumen(ReportModel report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Análisis del período',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          report.summary,
          style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
        ),
      ],
    );
  }

  // ── Tabla de categorías (datos de la gráfica) ─────────────────
  static pw.Widget _tablaCategorias(ReportModel report, NumberFormat fmt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalle por categoría',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _primario),
              children:
                  ['CATEGORÍA', 'VALOR'].map((h) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    );
                  }).toList(),
            ),
            ...report.chartData.map((item) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      item['label']?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      fmt.format((item['value'] as num?)?.toDouble() ?? 0),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Pie de página ─────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx, ReportModel report) {
    final ts = DateFormat('dd/MM/yyyy HH:mm').format(report.generatedAt);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Geodésica • Generado el $ts',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
        ),
        pw.Text(
          'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
        ),
      ],
    );
  }
}
