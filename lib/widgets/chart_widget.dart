// lib/widgets/chart_widget.dart
// Widgets de gráficas interactivas basados en fl_chart.
// Son insertados directamente en las burbujas del chat por chatMain.dart
// Los datos llegan desde report_service.generateChart().
//
// Conexiones:
//   report_service.dart → genera estos widgets
//   chatMain.dart → los renderiza dentro de RichMessageBubble

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// Paleta de colores corporativa Geodésica
const _kColors = [
  Color(0xFF46E0C9),
  Color(0xFF59A897),
  Color(0xFF1D413E),
  Color(0xFF2196F3),
  Color(0xFFFFA726),
  Color(0xFFEF5350),
  Color(0xFFAB47BC),
  Color(0xFF26A69A),
];

// ─────────────────────────────────────────────────────────────────
// PIE CHART — Distribución por categoría
// Uso típico: "ventas por producto", "gastos por área"
// ─────────────────────────────────────────────────────────────────
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
          // Leyenda
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

// ─────────────────────────────────────────────────────────────────
// BAR CHART — Comparativas entre categorías
// Uso típico: "productos más vendidos", "gastos por categoría"
// ─────────────────────────────────────────────────────────────────
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
              tooltipBorderRadius: BorderRadius.all(Radius.circular(8)),
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
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox();
                  }
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

// ─────────────────────────────────────────────────────────────────
// LINE CHART — Evolución temporal
// Uso típico: "tendencia de ventas", "ingresos última semana"
// ─────────────────────────────────────────────────────────────────
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
              tooltipBorderRadius: BorderRadius.all(Radius.circular(8)),
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
                  data.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      (entry.value['value'] as num?)?.toDouble() ?? 0,
                    );
                  }).toList(),
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

// ─── Widget vacío cuando no hay datos ────────────────────────────
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
