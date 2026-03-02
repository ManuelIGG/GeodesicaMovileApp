// lib/services/data_service.dart
// Se añade método executeSql para enviar consultas SQL al backend.
// Se conservan los métodos originales para compatibilidad (report_service).

import 'dart:convert';
import 'package:http/http.dart' as http;

class DataService {
  static const String _movimientosUrl =
      'https://araragricola.com/backend-geodesica/movimientos.php';
  static const String _executeSqlUrl =
      'https://araragricola.com/backend-geodesica/execute_query.php';
  static const int _timeoutSeconds = 30;

  // ── Método original (report_service aún lo usa) ──
  static Future<List<Map<String, dynamic>>> getMovimientosRaw() async {
    try {
      final response = await http.get(
        Uri.parse(_movimientosUrl),
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

  // ── Ejecutar una consulta SQL segura en el backend ──
  static Future<List<Map<String, dynamic>>> executeSql(String sql) async {
    try {
      final response = await http
          .post(
            Uri.parse(_executeSqlUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'sql': sql}),
          )
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data is Map && data.containsKey('error')) {
          throw Exception(data['error']);
        } else {
          return [];
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('DataService.executeSql error: $e');
      // Devolvemos una lista con un mapa de error para que la IA lo interprete
      return [
        {'error': e.toString()},
      ];
    }
  }
}
