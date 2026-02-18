// lib/services/data_service.dart
// Servicio de datos del backend.
// Modificado: se añade getMovimientosRaw() que devuelve la lista de objetos
// sin formatear, para que report_service pueda filtrar y procesar los datos.

import 'dart:convert';
import 'package:http/http.dart' as http;

class DataService {
  static const String _apiUrl =
      'https://araragricola.com/backend-geodesica/movimientos.php';

  // ─────────────────────────────────────────────────────────────
  // TEXTO PARA IA (método original, sin cambios)
  // Usado por chat_service.getChatResponse()
  // ─────────────────────────────────────────────────────────────
  static Future<String> getExtractosResumen() async {
    try {
      final movimientos = await getMovimientosRaw();
      if (movimientos.isEmpty) {
        return 'No hay movimientos financieros disponibles.';
      }
      return movimientos
          .map(
            (m) => '''
ID (DB): ${m['id']}
ID Movimiento: ${m['id_movimiento']}
Período: ${m['periodo']}
Categoría: ${m['categoria']}
Descripción: ${m['descripcion']}
Valor COP: \$${_formatearNumero(m['valor_cop'])}
Fecha Creación: ${m['fecha_creacion']}
Fecha Actualización: ${m['fecha_actualizacion']}
''',
          )
          .join('\n\n');
    } catch (e) {
      return 'Error al obtener los datos financieros. Por favor, intenta más tarde.';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LISTA RAW (NUEVO) — usado por report_service.dart
  // Devuelve los movimientos como lista de Map sin formatear,
  // permitiendo filtrar por fecha y agrupar por categoría.
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMovimientosRaw() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Error HTTP ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      print('DataService.getMovimientosRaw error: $e');
      return [];
    }
  }

  // Formatea número con separadores de miles
  static String _formatearNumero(dynamic valor) {
    if (valor == null) return '0';
    try {
      final n = double.parse(valor.toString());
      return n
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    } catch (_) {
      return valor.toString();
    }
  }
}
