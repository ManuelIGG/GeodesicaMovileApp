// lib/helpers/excel_helper.dart
// Genera archivos Excel con hojas separadas para resumen y categorías.
// Llamado desde report_service.exportToExcel().
//
// Dependencias: excel: ^4.0.3, path_provider: ^2.1.3

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';

class ExcelHelper {
  // ── Colores predefinidos como non-nullable ────────────────────
  // ExcelColor.fromHexString espera formato AARRGGBB (8 chars con alpha).
  // Al definirlos como static final evitamos el error de nullable
  // al pasarlos a CellStyle que espera ExcelColor no-nullable.
  static final ExcelColor _colorVerde = ExcelColor.fromHexString('FF1D413E');
  static final ExcelColor _colorBlanco = ExcelColor.fromHexString('FFFFFFFF');
  static final ExcelColor _colorVerdeClaro = ExcelColor.fromHexString(
    'FFE8F5E9',
  );
  static final ExcelColor _colorGris = ExcelColor.fromHexString('FFF5F5F5');

  static Future<File> generateReportExcel(ReportModel report) async {
    final excel = Excel.createExcel();

    // ── Hoja 1: Resumen financiero ──────────────────────────────
    final Sheet resumen = excel['Resumen'];
    excel.setDefaultSheet('Resumen');

    _cellColored(
      resumen,
      0,
      0,
      'EMPRESA DEMOS S.A.S.',
      bold: true,
      fontSize: 14,
      bg: _colorVerde,
      fg: _colorBlanco,
    );
    _cellPlain(resumen, 1, 0, 'NIT: 900.123.456-7', italic: true);
    _cellPlain(
      resumen,
      2,
      0,
      report.typeName.toUpperCase(),
      bold: true,
      fontSize: 12,
    );
    _cellPlain(resumen, 3, 0, report.periodoFormateado);
    _cellPlain(
      resumen,
      4,
      0,
      'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(report.generatedAt)}',
      italic: true,
    );

    // Encabezados de tabla
    _cellColored(
      resumen,
      6,
      0,
      'CONCEPTO',
      bold: true,
      bg: _colorVerde,
      fg: _colorBlanco,
    );
    _cellColored(
      resumen,
      6,
      1,
      'VALOR COP',
      bold: true,
      bg: _colorVerde,
      fg: _colorBlanco,
    );

    // Filas financieras
    final filas = [
      ['Ingresos por actividades ordinarias', report.ingresos],
      ['Gastos por naturaleza', report.gastos],
      ['RESULTADO INTEGRAL TOTAL', report.utilidad],
    ];

    for (var i = 0; i < filas.length; i++) {
      final isLast = i == filas.length - 1;

      if (isLast) {
        _cellColored(
          resumen,
          7 + i,
          0,
          filas[i][0] as String,
          bold: true,
          bg: _colorVerdeClaro,
          fg: _colorVerde,
        );
      } else {
        _cellPlain(resumen, 7 + i, 0, filas[i][0] as String);
      }

      // Valor como número (para que Excel pueda operar con él)
      final valueCell = resumen.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 7 + i),
      );
      valueCell.value = DoubleCellValue((filas[i][1] as double));
      if (isLast) {
        valueCell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: _colorVerdeClaro,
          fontColorHex: _colorVerde,
        );
      }
    }

    // Nota normativa
    _cellPlain(
      resumen,
      11,
      0,
      'Preparado según el Marco Técnico Normativo para Microempresas — Decreto 2420 de 2015',
      italic: true,
      fontSize: 8,
    );

    // Resumen IA
    _cellPlain(resumen, 13, 0, 'ANÁLISIS IA', bold: true);
    _cellPlain(resumen, 14, 0, report.summary);

    // ── Hoja 2: Detalle por categoría ──────────────────────────
    if (report.chartData.isNotEmpty) {
      final Sheet categorias = excel['Categorías'];

      _cellColored(
        categorias,
        0,
        0,
        'CATEGORÍA',
        bold: true,
        bg: _colorVerde,
        fg: _colorBlanco,
      );
      _cellColored(
        categorias,
        0,
        1,
        'VALOR COP',
        bold: true,
        bg: _colorVerde,
        fg: _colorBlanco,
      );

      for (var i = 0; i < report.chartData.length; i++) {
        _cellPlain(
          categorias,
          i + 1,
          0,
          report.chartData[i]['label']?.toString() ?? '',
        );

        final cell = categorias.cell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1),
        );
        cell.value = DoubleCellValue(
          (report.chartData[i]['value'] as num?)?.toDouble() ?? 0,
        );

        // Fondo alternado para legibilidad
        if (i.isEven) {
          cell.cellStyle = CellStyle(backgroundColorHex: _colorGris);
        }
      }
    }

    // Eliminar hoja vacía por defecto
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dir = await getTemporaryDirectory();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(report.generatedAt);
    final file = File('${dir.path}/geodesica_${report.type.name}_$ts.xlsx');
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS PRIVADOS
  //
  // Se dividen en dos métodos (_cellColored / _cellPlain) para NO
  // pasar ExcelColor? (nullable) donde CellStyle exige ExcelColor
  // (non-nullable). Es el patrón correcto para el paquete excel ^4.
  // ─────────────────────────────────────────────────────────────

  /// Celda con fondo y fuente de color explícito (ambos non-nullable).
  static void _cellColored(
    Sheet sheet,
    int row,
    int col,
    String value, {
    bool bold = false,
    bool italic = false,
    double fontSize = 11,
    required ExcelColor bg,
    required ExcelColor fg,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      italic: italic,
      fontSize: fontSize.toInt(),
      backgroundColorHex: bg,
      fontColorHex: fg,
    );
  }

  /// Celda de texto plano sin color (evita pasar null a CellStyle).
  static void _cellPlain(
    Sheet sheet,
    int row,
    int col,
    String value, {
    bool bold = false,
    bool italic = false,
    double fontSize = 11,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      italic: italic,
      fontSize: fontSize.toInt(),
    );
  }
}
