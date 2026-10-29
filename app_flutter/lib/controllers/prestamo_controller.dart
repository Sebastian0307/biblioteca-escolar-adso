import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PrestamoService {
  static const String baseUrl = 'http://localhost:3000/api';

  /// Construye los headers HTTP extrayendo el JWT almacenado en SharedPreferences
  static Future<Map<String, String>> _headersConToken() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Decodifica de forma segura el cuerpo de la respuesta
  static dynamic _decodificar(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {'mensaje': 'Respuesta inválida del servidor (${response.statusCode})'};
    }
  }

  /// Estudiante/Profesor: solicita un préstamo (POST /api/prestamos).
  /// El préstamo queda en estado 'pendiente' hasta que un administrador lo apruebe.
  static Future<Map<String, dynamic>> solicitarPrestamo(int idEjemplar) async {
    try {
      final headers = await _headersConToken();
      final response = await http.post(
        Uri.parse('$baseUrl/prestamos'),
        headers: headers,
        body: jsonEncode({'id_ejemplar': idEjemplar}),
      );

      final data = _decodificar(response);
      final bool ok = response.statusCode >= 200 && response.statusCode < 300;

      return {
        'ok': ok,
        'mensaje': data['mensaje'] ??
            (ok ? 'Solicitud enviada. Pendiente de aprobación.' : 'No se pudo procesar la solicitud.'),
        'solicitud': data['solicitud'],
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error de red al solicitar préstamo: $e'};
    }
  }

  /// Historial del usuario autenticado (GET /api/prestamos/mis-prestamos)
  static Future<List<Map<String, dynamic>>> obtenerHistorial() async {
    try {
      final headers = await _headersConToken();
      final response = await http.get(
        Uri.parse('$baseUrl/prestamos/mis-prestamos'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      throw Exception('No se pudo cargar el historial (Código ${response.statusCode})');
    } catch (e) {
      throw Exception('Error al consultar el historial de préstamos: $e');
    }
  }

  /// Administrador: lista los préstamos pendientes (GET /api/prestamos/pendientes)
  static Future<List<Map<String, dynamic>>> obtenerPendientes() async {
    try {
      final headers = await _headersConToken();
      final response = await http.get(
        Uri.parse('$baseUrl/prestamos/pendientes'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }

      final data = _decodificar(response);
      throw Exception(data['mensaje'] ?? 'Error al cargar pendientes (Código ${response.statusCode})');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Administrador: aprueba un préstamo pendiente (PUT /api/prestamos/:id/aprobar)
  static Future<Map<String, dynamic>> aprobarPrestamo(int idSolicitud) async {
    return _cambiarEstado(idSolicitud, 'aprobar');
  }

  /// Administrador: rechaza un préstamo pendiente (PUT /api/prestamos/:id/rechazar)
  static Future<Map<String, dynamic>> rechazarPrestamo(int idSolicitud) async {
    return _cambiarEstado(idSolicitud, 'rechazar');
  }

  static Future<Map<String, dynamic>> _cambiarEstado(int idSolicitud, String accion) async {
    try {
      final headers = await _headersConToken();
      final response = await http.put(
        Uri.parse('$baseUrl/prestamos/$idSolicitud/$accion'),
        headers: headers,
      );

      final data = _decodificar(response);
      final bool ok = response.statusCode >= 200 && response.statusCode < 300;
      return {
        'ok': ok,
        'mensaje': data['mensaje'] ?? (ok ? 'Operación exitosa' : 'No se pudo completar la operación'),
      };
    } catch (e) {
      return {'ok': false, 'mensaje': 'Error de red: $e'};
    }
  }
}
