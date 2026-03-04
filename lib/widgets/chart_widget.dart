// =============================================================================
// lib/widgets/chart_widget.dart
// =============================================================================
// CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR:
//
//   1. Se añade GeodesicaChartExpanded — widget de vista completa para cada
//      tipo de gráfica. Renderiza con mayor altura (360px), ejes X/Y con
//      valores visibles, etiquetas completas sin truncar, y leyenda amplia.
//      Se abre desde el botón "Vista completa" en chatMain.dart.
//
//   2. Las gráficas originales (GeodesicaPieChart, GeodesicaBarChart,
//      GeodesicaLineChart) NO cambian — siguen siendo los widgets compactos
//      que van dentro de la burbuja del chat.
//
//   3. GeodesicaExpandedChartDialog — diálogo que envuelve el chart expandido
//      con título, fondo oscurecido y botón de cierre. Llamado desde chatMain.
//
// CONEXIONES:
//   → chatMain.dart importa y usa GeodesicaExpandedChartDialog
//   → report_service.dart sigue usando generateChart() sin cambios
// =============================================================================

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ─── Paleta corporativa Geodésica ────────────────────────────────
const _kColors = [
  Color(0xFF46E0C9),
  Color(0xFF59A897),
  Color(0xFF1D413E),
  Color(0xFF2196F3),
  Color(0xFFFFA726),
  Color(0xFFEF5350),
  Color(0xFFAB47BC),
  Color(0xFF26A69A),
  Color(0xFF66BB6A),
  Color(0xFFEC407A),
];

// =============================================================================
// GRÁFICAS COMPACTAS (sin cambios — para la burbuja del chat)
// =============================================================================

// ── PIE CHART compacto ────────────────────────────────────────────
class GeodesicaPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  const GeodesicaPieChart({super.key, required this.data});

  @override
  State<GeodesicaPieChart> createState() => _GeodesicaPieChartState();
}

class _GeodesicaPieChartState extends State<GeodesicaPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const _EmptyChart();

    final total = widget.data.fold<double>(
      0,
      (sum, d) => sum + ((d['value'] as num?)?.toDouble() ?? 0),
    );

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex =
                          (event.isInterestedForInteractions &&
                                  response?.touchedSection != null)
                              ? response!.touchedSection!.touchedSectionIndex
                              : -1;
                    });
                  },
                ),
                sections:
                    widget.data.asMap().entries.map((entry) {
                      final isTouched = entry.key == _touchedIndex;
                      final value =
                          (entry.value['value'] as num?)?.toDouble() ?? 0;
                      final pct = total > 0 ? (value / total * 100) : 0;
                      return PieChartSectionData(
                        color: _kColors[entry.key % _kColors.length],
                        value: value,
                        title: '${pct.toStringAsFixed(1)}%',
                        radius: isTouched ? 70 : 58,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                centerSpaceRadius: 32,
                sectionsSpace: 2,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.data.length,
              itemBuilder:
                  (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _kColors[i % _kColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.data[i]['label']?.toString() ?? '',
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BAR CHART compacto ────────────────────────────────────────────
class GeodesicaBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const GeodesicaBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();

    final maxY = data.fold<double>(
      0,
      (m, d) => max(m, (d['value'] as num?)?.toDouble() ?? 0),
    );

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.25,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: const BorderRadius.all(Radius.circular(8)),
              getTooltipItem: (group, _, rod, __) {
                final label = data[group.x]['label']?.toString() ?? '';
                return BarTooltipItem(
                  '$label\n\$${_fmt(rod.toY)}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          barGroups:
              data.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: (entry.value['value'] as num?)?.toDouble() ?? 0,
                      gradient: LinearGradient(
                        colors: [
                          _kColors[entry.key % _kColors.length],
                          _kColors[entry.key % _kColors.length].withOpacity(
                            0.6,
                          ),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ],
                );
              }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final label = data[idx]['label']?.toString() ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label.length > 8 ? '${label.substring(0, 8)}…' : label,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine:
                (_) =>
                    FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ── LINE CHART compacto ───────────────────────────────────────────
class GeodesicaLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const GeodesicaLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBorderRadius: const BorderRadius.all(Radius.circular(8)),
              getTooltipItems:
                  (spots) =>
                      spots
                          .map(
                            (s) => LineTooltipItem(
                              '\$${s.y.toStringAsFixed(0)}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          )
                          .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots:
                  data
                      .asMap()
                      .entries
                      .map(
                        (entry) => FlSpot(
                          entry.key.toDouble(),
                          (entry.value['value'] as num?)?.toDouble() ?? 0,
                        ),
                      )
                      .toList(),
              isCurved: true,
              color: const Color(0xFF46E0C9),
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter:
                    (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFF46E0C9),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF46E0C9).withOpacity(0.2),
                    const Color(0xFF46E0C9).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final label = data[idx]['label']?.toString() ?? '';
                  return Text(
                    label.length > 6 ? '${label.substring(0, 6)}…' : label,
                    style: const TextStyle(fontSize: 9),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine:
                (_) =>
                    FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// =============================================================================
// GRÁFICAS EXPANDIDAS — versión de vista completa con ejes y valores visibles
// =============================================================================

// ── PIE CHART expandido ───────────────────────────────────────────
// Mayor radio, leyenda completa con valores y porcentajes
class GeodesicaPieChartExpanded extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final bool isDark;
  const GeodesicaPieChartExpanded({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<GeodesicaPieChartExpanded> createState() =>
      _GeodesicaPieChartExpandedState();
}

class _GeodesicaPieChartExpandedState extends State<GeodesicaPieChartExpanded> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const _EmptyChart();

    final total = widget.data.fold<double>(
      0,
      (sum, d) => sum + ((d['value'] as num?)?.toDouble() ?? 0),
    );
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1D413E);

    return Column(
      children: [
        // Gráfica de torta grande
        SizedBox(
          height: 280,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex =
                        (event.isInterestedForInteractions &&
                                response?.touchedSection != null)
                            ? response!.touchedSection!.touchedSectionIndex
                            : -1;
                  });
                },
              ),
              sections:
                  widget.data.asMap().entries.map((entry) {
                    final isTouched = entry.key == _touchedIndex;
                    final value =
                        (entry.value['value'] as num?)?.toDouble() ?? 0;
                    final pct = total > 0 ? (value / total * 100) : 0;
                    return PieChartSectionData(
                      color: _kColors[entry.key % _kColors.length],
                      value: value,
                      // Mostrar porcentaje Y valor en la sección expandida
                      title:
                          isTouched
                              ? '${_fmtValor(value)}\n${pct.toStringAsFixed(1)}%'
                              : '${pct.toStringAsFixed(1)}%',
                      radius: isTouched ? 105 : 88,
                      titleStyle: TextStyle(
                        fontSize: isTouched ? 13 : 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
              centerSpaceRadius: 48,
              sectionsSpace: 3,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Leyenda completa con valor y porcentaje — sin truncar
        Expanded(
          child: ListView.separated(
            itemCount: widget.data.length,
            separatorBuilder:
                (_, __) =>
                    Divider(color: textColor.withOpacity(0.08), height: 1),
            itemBuilder: (_, i) {
              final item = widget.data[i];
              final value = (item['value'] as num?)?.toDouble() ?? 0;
              final pct = total > 0 ? (value / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    // Indicador de color
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _kColors[i % _kColors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Etiqueta — sin truncar en vista completa
                    Expanded(
                      child: Text(
                        item['label']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Valor formateado
                    Text(
                      _fmtValor(value),
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Porcentaje en chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kColors[i % _kColors.length].withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: _kColors[i % _kColors.length],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── BAR CHART expandido ───────────────────────────────────────────
// Eje Y con valores, etiquetas X completas en diagonal, tooltip rico
class GeodesicaBarChartExpanded extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool isDark;
  const GeodesicaBarChartExpanded({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();

    final maxY = data.fold<double>(
      0,
      (m, d) => max(m, (d['value'] as num?)?.toDouble() ?? 0),
    );
    final textColor = isDark ? Colors.white70 : const Color(0xFF5A7A77);

    return Column(
      children: [
        // Barra chart con eje Y visible
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipBorderRadius: const BorderRadius.all(
                    Radius.circular(10),
                  ),
                  tooltipPadding: const EdgeInsets.all(10),
                  getTooltipItem: (group, _, rod, __) {
                    final item = data[group.x];
                    final label = item['label']?.toString() ?? '';
                    return BarTooltipItem(
                      '$label\n',
                      TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: _fmtValor(rod.toY),
                          style: const TextStyle(
                            color: Color(0xFF46E0C9),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups:
                  data.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value['value'] as num?)?.toDouble() ?? 0,
                          gradient: LinearGradient(
                            colors: [
                              _kColors[entry.key % _kColors.length],
                              _kColors[entry.key % _kColors.length].withOpacity(
                                0.5,
                              ),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          // Barras más anchas en vista expandida
                          width:
                              data.length <= 5
                                  ? 36
                                  : data.length <= 10
                                  ? 24
                                  : 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY * 1.2,
                            color:
                                isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.black.withOpacity(0.03),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
              titlesData: FlTitlesData(
                // Eje X — etiquetas completas (sin truncar en vista expandida)
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length)
                        return const SizedBox();
                      final label = data[idx]['label']?.toString() ?? '';
                      return SideTitleWidget(
                        meta: meta,
                        angle: data.length > 6 ? -0.5 : 0,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            // Truncar solo si hay muchos elementos
                            data.length > 10 && label.length > 10
                                ? '${label.substring(0, 9)}…'
                                : label,
                            style: TextStyle(fontSize: 11, color: textColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Eje Y con valores formateados — visible en vista expandida
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    interval: maxY / 4,
                    getTitlesWidget: (value, _) {
                      if (value == 0) return const SizedBox();
                      return Text(
                        _fmtValor(value),
                        style: TextStyle(fontSize: 10, color: textColor),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.06),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.1),
                  ),
                  left: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── LINE CHART expandido ──────────────────────────────────────────
// Ejes X/Y con valores, puntos más grandes, área rellena, tooltip completo
class GeodesicaLineChartExpanded extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool isDark;
  const GeodesicaLineChartExpanded({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();

    final maxY = data.fold<double>(
      0,
      (m, d) => max(m, (d['value'] as num?)?.toDouble() ?? 0),
    );
    final textColor = isDark ? Colors.white70 : const Color(0xFF5A7A77);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBorderRadius: const BorderRadius.all(Radius.circular(10)),
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItems:
                (spots) =>
                    spots.map((s) {
                      final idx = s.x.toInt();
                      final label =
                          idx >= 0 && idx < data.length
                              ? data[idx]['label']?.toString() ?? ''
                              : '';
                      return LineTooltipItem(
                        '$label\n',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: _fmtValor(s.y),
                            style: const TextStyle(
                              color: Color(0xFF46E0C9),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots:
                data
                    .asMap()
                    .entries
                    .map(
                      (entry) => FlSpot(
                        entry.key.toDouble(),
                        (entry.value['value'] as num?)?.toDouble() ?? 0,
                      ),
                    )
                    .toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: const Color(0xFF46E0C9),
            barWidth: 3,
            // Puntos más grandes en vista expandida
            dotData: FlDotData(
              show: true,
              getDotPainter:
                  (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 6,
                    color: const Color(0xFF46E0C9),
                    strokeWidth: 2.5,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF46E0C9).withOpacity(0.25),
                  const Color(0xFF46E0C9).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          // Eje X — etiquetas completas
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                final label = data[idx]['label']?.toString() ?? '';
                return SideTitleWidget(
                  meta: meta,
                  angle: data.length > 7 ? -0.5 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data.length > 12 && label.length > 8
                          ? '${label.substring(0, 7)}…'
                          : label,
                      style: TextStyle(fontSize: 10, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          // Eje Y con valores
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              interval: maxY / 4,
              getTitlesWidget: (value, _) {
                if (value == 0) return const SizedBox();
                return Text(
                  _fmtValor(value),
                  style: TextStyle(fontSize: 10, color: textColor),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: maxY / 4,
          verticalInterval: 1,
          getDrawingHorizontalLine:
              (_) => FlLine(
                color:
                    isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.06),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
          getDrawingVerticalLine:
              (_) => FlLine(
                color:
                    isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.03),
                strokeWidth: 1,
              ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.1),
            ),
            left: BorderSide(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.1),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DIÁLOGO DE VISTA COMPLETA
// =============================================================================
// Llamado desde chatMain.dart al pulsar el botón "Vista completa".
// Muestra la gráfica expandida en un panel de casi pantalla completa con:
//   - Fondo semitransparente
//   - Título del reporte
//   - Período
//   - Gráfica con ejes y valores visibles
//   - Botón de cierre
//
// USO en chatMain.dart:
//   showDialog(
//     context: context,
//     builder: (_) => GeodesicaExpandedChartDialog(
//       titulo: report.title,
//       periodo: report.periodoFormateado,
//       chartType: report.chartType,
//       data: report.chartData,
//       isDark: isDark,
//     ),
//   );
class GeodesicaExpandedChartDialog extends StatelessWidget {
  final String titulo;
  final String periodo;
  final String chartType; // 'bar', 'pie', 'line'
  final List<Map<String, dynamic>> data;
  final bool isDark;

  const GeodesicaExpandedChartDialog({
    super.key,
    required this.titulo,
    required this.periodo,
    required this.chartType,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0F2A28) : const Color(0xFFF0F9F7);
    final cardColor = isDark ? const Color(0xFF1A3735) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D413E);
    final subColor = isDark ? Colors.white54 : const Color(0xFF5A7A77);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Encabezado del diálogo ─────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1D413E).withOpacity(isDark ? 0.6 : 0.07),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForChart(chartType),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          periodo,
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  // Botón cerrar
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Gráfica expandida ──────────────────────────────
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildExpandedChart(),
              ),
            ),

            // ── Pie de diálogo con total ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${data.length} elementos',
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                  Text(
                    'Total: ${_fmtValor(data.fold(0.0, (s, d) => s + ((d['value'] as num?)?.toDouble() ?? 0)))}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF46E0C9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedChart() {
    switch (chartType.toLowerCase()) {
      case 'pie':
        return GeodesicaPieChartExpanded(data: data, isDark: isDark);
      case 'line':
        return GeodesicaLineChartExpanded(data: data, isDark: isDark);
      default:
        return GeodesicaBarChartExpanded(data: data, isDark: isDark);
    }
  }

  IconData _iconForChart(String type) {
    switch (type.toLowerCase()) {
      case 'pie':
        return Icons.pie_chart_rounded;
      case 'line':
        return Icons.show_chart_rounded;
      default:
        return Icons.bar_chart_rounded;
    }
  }
}

// =============================================================================
// HELPERS COMPARTIDOS
// =============================================================================

// Formatea valores numéricos para ejes y leyendas
String _fmtValor(double v) {
  if (v >= 1000000000) return '\$${(v / 1000000000).toStringAsFixed(1)}B';
  if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
  return '\$${v.toStringAsFixed(0)}';
}

// Widget vacío cuando no hay datos
class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(
        child: Text(
          'Sin datos para mostrar',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
