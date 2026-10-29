import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LibroService {
  static const String baseUrl = 'http://localhost:3000/api/libros';

  /// Obtiene el catálogo completo de libros desde GET http://localhost:3000/api/libros
  static Future<List<Map<String, dynamic>>> obtenerLibros() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        throw Exception('Error al obtener libros (Código ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error al conectar con el catálogo de libros: $e');
    }
  }

  /// Crea un nuevo libro junto con sus ejemplares (HTTP POST a http://localhost:3000/api/libros)
  static Future<Map<String, dynamic>> crearLibro({
    required String titulo,
    required String autor,
    required String area,
    required int stock,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('jwt_token');

      final url = Uri.parse(baseUrl);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'titulo': titulo,
          'autor': autor,
          'area': area,
          'stock': stock,
          'cantidad': stock,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'ok': true,
          'mensaje': data['mensaje'] ?? 'Libro creado exitosamente',
          'libro': data['libro'],
        };
      } else {
        return {
          'ok': false,
          'mensaje': data['mensaje'] ?? 'Error al registrar el libro',
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  /// Elimina un libro por ID (HTTP DELETE a http://localhost:3000/api/libros/:id)
  static Future<Map<String, dynamic>> eliminarLibro(dynamic idLibro) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('jwt_token');

      final url = Uri.parse('$baseUrl/$idLibro');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'ok': true,
          'mensaje': data['mensaje'] ?? 'Libro eliminado exitosamente',
        };
      } else {
        return {
          'ok': false,
          'mensaje': data['mensaje'] ?? 'Error al eliminar el libro',
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }

  /// Aumenta el stock de un libro existente insertando nuevos ejemplares (HTTP POST)
  static Future<Map<String, dynamic>> aumentarStock({
    required dynamic idLibro,
    required int cantidad,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('jwt_token');

      final url = Uri.parse('$baseUrl/$idLibro/aumentar-stock');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id_libro': idLibro,
          'cantidad': cantidad,
          'stock': cantidad,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'ok': true,
          'mensaje': data['mensaje'] ?? 'Stock aumentado exitosamente',
          'total_ejemplares': data['total_ejemplares'],
          'ejemplares_disponibles': data['ejemplares_disponibles'],
        };
      } else {
        return {
          'ok': false,
          'mensaje': data['mensaje'] ?? 'Error al aumentar el stock',
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'mensaje': 'Error de conexión: $e',
      };
    }
  }
}
