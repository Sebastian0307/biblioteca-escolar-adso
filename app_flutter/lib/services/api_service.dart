import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // URL base conectada al backend Express en el puerto 3000
  static const String baseUrl = 'http://localhost:3000';

  static Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, dynamic>?> obtenerUsuarioGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('usuario_actual');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> guardarSesion(String token, Map<String, dynamic> usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('usuario_actual', jsonEncode(usuario));
  }

  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('usuario_actual');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await obtenerToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // POST /auth/login
  static Future<Map<String, dynamic>> login(String documento, String contrasena) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'documento': documento.trim(),
        'contrasena': contrasena.trim(),
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await guardarSesion(data['token'], data['usuario']);
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'Error al iniciar sesión');
    }
  }

  // POST /seed
  static Future<Map<String, dynamic>> inicializarSeed() async {
    final response = await http.post(Uri.parse('$baseUrl/seed'));
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'Error en seed');
    }
  }

  // GET /libros
  static Future<List<dynamic>> listarLibros() async {
    final headers = await _headers();
    final response = await http.get(Uri.parse('$baseUrl/libros'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Error al cargar el catálogo de libros');
    }
  }

  // POST /libros
  static Future<Map<String, dynamic>> crearLibro({
    required String codigoLibro,
    required String titulo,
    required String autor,
    required String area,
    required int anioPublicacion,
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/libros'),
      headers: headers,
      body: jsonEncode({
        'codigo_libro': codigoLibro,
        'titulo': titulo,
        'autor': autor,
        'area': area,
        'anio_publicacion': anioPublicacion,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'Error al crear libro');
    }
  }

  // POST /libros/:id/ejemplares
  static Future<Map<String, dynamic>> agregarEjemplar({
    required int idLibro,
    required String codigoInventario,
    String condicion = 'bueno',
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/libros/$idLibro/ejemplares'),
      headers: headers,
      body: jsonEncode({
        'codigo_inventario': codigoInventario,
        'condicion': condicion,
        'disponibilidad': 'disponible',
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'Error al agregar ejemplar');
    }
  }

  // POST /solicitudes
  static Future<Map<String, dynamic>> solicitarPrestamo(int idEjemplar) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/solicitudes'),
      headers: headers,
      body: jsonEncode({'id_ejemplar': idEjemplar}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'No se pudo registrar la solicitud');
    }
  }

  // GET /solicitudes/mis-prestamos
  static Future<List<dynamic>> obtenerMisPrestamos() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/solicitudes/mis-prestamos'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Error al consultar préstamos');
    }
  }

  // GET /solicitudes/mis-solicitudes
  static Future<List<dynamic>> obtenerMisSolicitudes() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/solicitudes/mis-solicitudes'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Error al consultar solicitudes');
    }
  }

  // GET /solicitudes (Admin)
  static Future<List<dynamic>> listarTodasLasSolicitudes() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/solicitudes'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Error al cargar solicitudes');
    }
  }

  // GET /solicitudes/prestamos (Admin)
  static Future<List<dynamic>> listarTodosLosPrestamos() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/solicitudes/prestamos'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Error al cargar préstamos activos');
    }
  }

  // PATCH /solicitudes/:id/approve
  static Future<Map<String, dynamic>> aprobarSolicitud(int idSolicitud) async {
    final headers = await _headers();
    final response = await http.patch(
      Uri.parse('$baseUrl/solicitudes/$idSolicitud/approve'),
      headers: headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'Error al aprobar solicitud');
    }
  }

  // POST /solicitudes/:id/devolver
  static Future<Map<String, dynamic>> registrarDevolucion(
    int idPrestamo, {
    String observaciones = 'Entregado en buen estado',
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/solicitudes/$idPrestamo/devolver'),
      headers: headers,
      body: jsonEncode({'observaciones': observaciones}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'Error al registrar devolución');
    }
  }

  // POST /admin/usuarios/upload-excel
  static Future<Map<String, dynamic>> subirExcelUsuarios(
    Uint8List fileBytes,
    String fileName,
  ) async {
    final token = await obtenerToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/admin/usuarios/upload-excel'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'archivo',
        fileBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['mensaje'] ?? 'Error al subir archivo Excel');
    }
  }
}
