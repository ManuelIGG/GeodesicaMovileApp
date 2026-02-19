// =============================================================================
// lib/services/upload_service.dart
// =============================================================================
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class UploadResult {
  final bool success;
  final String? publicUrl;
  final int? dbId;
  final String? errorMessage;

  const UploadResult({
    required this.success,
    this.publicUrl,
    this.dbId,
    this.errorMessage,
  });

  factory UploadResult.error(String message) =>
      UploadResult(success: false, errorMessage: message);
}

class UploadService {
  static const String _uploadEndpoint =
      'https://araragricola.com/backend-geodesica/reporte_upload.php';

  static const Duration _timeout = Duration(seconds: 60);

  static Future<UploadResult> subirReporte({
    required File archivo,
    required String mensajeId,
    required String chatId,
    required String tipo,
    required String titulo,
    required String periodo,
    required String formato,
  }) async {
    try {
      // ── 1. VALIDAR QUE EL ARCHIVO EXISTE Y TIENE CONTENIDO ────────────────
      if (!await archivo.exists()) {
        return UploadResult.error(
          'El archivo local no existe: ${archivo.path}',
        );
      }

      final tamano = await archivo.length();
      if (tamano == 0) {
        return UploadResult.error('El archivo está vacío: ${archivo.path}');
      }

      debugPrint('[UploadService] Subiendo ${archivo.path} (${tamano}B)...');

      // ── 2. CONSTRUIR LA PETICIÓN MULTIPART ───────────────────────────────
      final request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));

      final multipartFile = await http.MultipartFile.fromPath(
        'archivo',
        archivo.path,
      );
      request.files.add(multipartFile);

      // ── 3. ADJUNTAR CAMPOS DE TEXTO ──────────────────────────────────────
      request.fields['mensaje_id'] = mensajeId;
      request.fields['chat_id'] = chatId;
      request.fields['tipo'] = tipo;
      request.fields['titulo'] = titulo;
      request.fields['periodo'] = periodo;
      request.fields['formato'] = formato;

      // ── 4. ENVIAR LA PETICIÓN CON TIMEOUT ───────────────────────────────
      // El timeout cubre todo el ciclo: conexión + envío + lectura del body
      final response = await Future(() async {
        final streamedResponse = await request.send();
        return await http.Response.fromStream(streamedResponse);
      }).timeout(_timeout);

      debugPrint('[UploadService] Respuesta HTTP: ${response.statusCode}');
      debugPrint('[UploadService] Body: ${response.body}');

      // ── 5. PROCESAR LA RESPUESTA JSON DEL SERVIDOR ───────────────────────
      if (response.statusCode != 200) {
        return UploadResult.error(
          'Error HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (json['success'] == true) {
        final url = json['url'] as String?;
        final dbId = json['id'] as int?;

        if (url == null || url.isEmpty) {
          return UploadResult.error('El servidor no devolvió una URL válida.');
        }

        debugPrint('[UploadService] ✅ Subido exitosamente: $url');

        return UploadResult(success: true, publicUrl: url, dbId: dbId);
      } else {
        final msg =
            json['message'] as String? ?? 'Error desconocido en el servidor';
        return UploadResult.error(msg);
      }
    } on SocketException catch (e) {
      debugPrint('[UploadService] ❌ Sin conexión: $e');
      return UploadResult.error('Sin conexión a internet: ${e.message}');
    } on TimeoutException catch (_) {
      debugPrint('[UploadService] ❌ Timeout al subir archivo');
      return UploadResult.error(
        'Tiempo de espera agotado al subir el archivo.',
      );
    } catch (e) {
      debugPrint('[UploadService] ❌ Error inesperado: $e');
      return UploadResult.error('Error inesperado al subir el archivo: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerReportesPorChat(
    String chatId,
  ) async {
    try {
      final uri = Uri.parse(
        'https://araragricola.com/backend-geodesica/reporte_query.php'
        '?chat_id=${Uri.encodeComponent(chatId)}',
      );

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }

      debugPrint(
        '[UploadService] Error al consultar reportes: ${response.statusCode}',
      );
      return [];
    } catch (e) {
      debugPrint('[UploadService] Error en obtenerReportesPorChat: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> obtenerReportePorMensaje(
    String mensajeId,
  ) async {
    try {
      final uri = Uri.parse(
        'https://araragricola.com/backend-geodesica/reporte_query.php'
        '?mensaje_id=${Uri.encodeComponent(mensajeId)}',
      );

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.isNotEmpty ? data.first as Map<String, dynamic> : null;
      }

      return null;
    } catch (e) {
      debugPrint('[UploadService] Error en obtenerReportePorMensaje: $e');
      return null;
    }
  }
}
