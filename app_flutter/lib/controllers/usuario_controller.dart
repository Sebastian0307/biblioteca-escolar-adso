import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UsuarioService {
  static const String baseUrl = 'http://localhost:3000/api';

  /// Inicia sesión enviando documento y contraseña a POST /api/auth/login
  /// y guarda el token JWT usando SharedPreferences.
  static Future<Map<String, dynamic>> loginUsuario(
    String documento,
    String contrasena,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'documento': documento.trim(),
          'contrasena': contrasena.trim(),
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String token = data['token'] ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        if (data['usuario'] != null) {
          await prefs.setString('usuario', jsonEncode(data['usuario']));
        }

        return {
          'ok': true,
          'mensaje': data['mensaje'] ?? 'Inicio de sesión exitoso',
          'token': token,
          'usuario': data['usuario'],
        };
      } else {
        return {
          'ok': false,
          'mensaje': data['mensaje'] ?? 'Credenciales incorrectas',
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'mensaje': 'Error de conexión con el servidor: $e',
      };
    }
  }

  /// Registra un nuevo usuario enviando documento, nombre, contraseña y rol a POST /api/auth/register
  static Future<Map<String, dynamic>> registrarUsuario({
    required String documento,
    required String nombre,
    required String contrasena,
    required String rol,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'documento': documento.trim(),
          'nombre': nombre.trim(),
          'contrasena': contrasena.trim(),
          'rol': rol.trim(),
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          if (data['usuario'] != null) {
            await prefs.setString('usuario', jsonEncode(data['usuario']));
          }
        }
        return {
          'ok': true,
          'mensaje': data['mensaje'] ?? 'Usuario registrado exitosamente.',
          'token': data['token'],
          'usuario': data['usuario'],
        };
      } else {
        return {
          'ok': false,
          'mensaje': data['mensaje'] ?? 'No se pudo registrar el usuario.',
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'mensaje': 'Error de conexión al registrar usuario: $e',
      };
    }
  }

  /// Decodifica el payload del token JWT almacenado en SharedPreferences
  static Future<Map<String, dynamic>?> decodificarTokenDesdePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      if (token == null || token.isEmpty) return null;

      final partes = token.split('.');
      if (partes.length != 3) return null;

      final String payloadNormalizado = base64Url.normalize(partes[1]);
      final String payloadJson =
          utf8.decode(base64Url.decode(payloadNormalizado));
      final Map<String, dynamic> payload =
          Map<String, dynamic>.from(jsonDecode(payloadJson) as Map);

      return payload;
    } catch (e) {
      return null;
    }
  }

  /// Cierra la sesión eliminando el token guardado
  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('usuario');
  }
}
