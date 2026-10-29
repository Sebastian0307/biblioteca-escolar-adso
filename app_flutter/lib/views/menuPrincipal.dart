import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/libros_controller.dart';
import '../controllers/usuario_controller.dart';
import '../services/libro_service.dart';
import 'detalleLibro.dart';
import 'historialScreen.dart';
import 'inventario_screen.dart';
import 'loginScreen.dart';
import 'prestamos_pendientes_screen.dart';

class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _libros = [];
  bool _cargandoLibros = true;
  String? _errorMensaje;
  int _bottomNavIndex = 0;

  // Datos decodificados desde el JWT almacenado en SharedPreferences
  bool _tokenDecodificado = false;
  String _rolUsuario = '';
  String _nombreUsuario = 'Usuario';
  String _documentoUsuario = '';

  bool get _esAdmin {
    final rol = _rolUsuario.toLowerCase();
    return rol == 'admin' || rol == 'administrador' || rol == 'administrativo';
  }

  bool get _puedeSolicitar {
    if (!_tokenDecodificado) return false;
    final rol = _rolUsuario.toLowerCase();
    return (rol == 'estudiante' || rol == 'profesor') && !_esAdmin;
  }

  @override
  void initState() {
    super.initState();
    _decodificarTokenYRol();
    _cargarLibros();
  }

  /// Decodifica el token JWT guardado en SharedPreferences para extraer el rol (Admin, Estudiante, Profesor)
  Future<void> _decodificarTokenYRol() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token') ?? prefs.getString('jwt_token');

      if (token != null && token.isNotEmpty) {
        final partes = token.split('.');
        if (partes.length == 3) {
          final payloadNormalizado = base64Url.normalize(partes[1]);
          final String jsonPayload =
              utf8.decode(base64Url.decode(payloadNormalizado));
          final Map<String, dynamic> payload =
              Map<String, dynamic>.from(jsonDecode(jsonPayload) as Map);

          final String tipo =
              (payload['rol'] ?? payload['tipo_usuario'] ?? '').toString();
          String rolNormalizado = 'Estudiante';
          if (tipo.toLowerCase() == 'admin' ||
              tipo.toLowerCase() == 'administrador' ||
              tipo.toLowerCase() == 'administrativo') {
            rolNormalizado = 'Admin';
          } else if (tipo.toLowerCase() == 'profesor') {
            rolNormalizado = 'Profesor';
          } else {
            rolNormalizado = 'Estudiante';
          }

          if (mounted) {
            setState(() {
              _tokenDecodificado = true;
              _rolUsuario = rolNormalizado;
              _nombreUsuario =
                  '${payload['nombre'] ?? ''} ${payload['apellido'] ?? ''}'
                      .trim();
              _documentoUsuario = payload['documento']?.toString() ?? '';
            });
          }
        }
      }

      if (!_tokenDecodificado && mounted) {
        final String? rawUser = prefs.getString('usuario') ?? prefs.getString('usuario_actual');
        if (rawUser != null) {
          final userMap = jsonDecode(rawUser);
          final tipo = (userMap['rol'] ?? userMap['tipo_usuario'] ?? '').toString().toLowerCase();
          setState(() {
            _tokenDecodificado = true;
            _rolUsuario = (tipo == 'admin' || tipo == 'administrador' || tipo == 'administrativo')
                ? 'Admin'
                : (tipo == 'profesor' ? 'Profesor' : 'Estudiante');
            _nombreUsuario = '${userMap['nombre'] ?? ''} ${userMap['apellido'] ?? ''}'.trim();
            _documentoUsuario = userMap['documento']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error al decodificar JWT: $e');
    }
  }

  Future<void> _cargarLibros() async {
    setState(() {
      _cargandoLibros = true;
      _errorMensaje = null;
    });

    try {
      final lista = await LibrosService.obtenerLibros();
      if (mounted) {
        setState(() {
          _libros = lista;
          _cargandoLibros = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = e.toString().replaceAll('Exception: ', '');
          _cargandoLibros = false;
        });
      }
    }
  }

  Future<void> _solicitarPrestamoDirecto(Map<String, dynamic> libro) async {
    final List<dynamic> ejemplares = (libro['ejemplares'] as List<dynamic>?) ?? [];
    final disponibles = ejemplares.where((e) => e['disponibilidad'] == 'disponible').toList();

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ejemplares disponibles de este libro en este momento.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final idEjemplar = disponibles.first['id_ejemplar'] as int;

    // Diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar Solicitud'),
        content: Text('¿Deseas solicitar en préstamo el libro "${libro['titulo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Solicitar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final respuesta = await PrestamoService.solicitarPrestamo(idEjemplar);
      if (!mounted) return;

      if (respuesta['ok'] == true) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Solicitud Exitosa'),
              ],
            ),
            content: Text(
              '¡Solicitud registrada con éxito para "${libro['titulo']}"!\n\n'
              'El préstamo ha quedado guardado con estado "pendiente" en la base de datos Supabase a la espera de que el administrador lo apruebe.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
        _cargarLibros();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(respuesta['mensaje'] ?? 'Error al solicitar el préstamo'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  /// Diálogo modal para la creación de un nuevo libro conectado al servicio HTTP POST
  void _mostrarModalCrearLibro() {
    final TextEditingController tituloController = TextEditingController();
    final TextEditingController autorController = TextEditingController();
    final TextEditingController areaController = TextEditingController();
    final TextEditingController stockController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool enviando = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_box_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Crear Nuevo Libro'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ingresa el título del libro',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: autorController,
                      decoration: const InputDecoration(
                        labelText: 'Autor',
                        hintText: 'Ingresa el autor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: areaController,
                      decoration: const InputDecoration(
                        labelText: 'Área',
                        hintText: 'Ej. Matemáticas, Literatura',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock',
                        hintText: 'Cantidad de ejemplares',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: enviando
                      ? null
                      : () async {
                          final titulo = tituloController.text.trim();
                          final autor = autorController.text.trim();
                          final area = areaController.text.trim();
                          final stock = int.tryParse(stockController.text.trim()) ?? 1;

                          if (titulo.isEmpty || autor.isEmpty || area.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Por favor completa título, autor y área.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => enviando = true);

                          final res = await LibroService.crearLibro(
                            titulo: titulo,
                            autor: autor,
                            area: area,
                            stock: stock,
                          );

                          if (!mounted) return;
                          Navigator.of(dialogContext).pop();

                          if (res['ok'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['mensaje'] ?? '¡Libro creado con éxito!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            setState(() {
                              _cargandoLibros = true;
                            });
                            await _cargarLibros();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['mensaje'] ?? 'Error al registrar libro'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Eliminar libro conectado al servicio HTTP DELETE con confirmación, SnackBar y setState
  Future<void> _eliminarLibro(Map<String, dynamic> libro) async {
    final idLibro = libro['id_libro'];
    final titulo = libro['titulo'] ?? 'este libro';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirmar Eliminación'),
          ],
        ),
        content: Text('¿Estás seguro de que deseas eliminar el libro "$titulo" y todos sus ejemplares?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final res = await LibroService.eliminarLibro(idLibro);
    if (!mounted) return;

    if (res['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje'] ?? 'Libro eliminado con éxito'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _cargandoLibros = true;
      });
      await _cargarLibros();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje'] ?? 'Error al eliminar libro'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Cuadro de diálogo para aumentar el stock de un libro existente
  void _mostrarModalAumentarStock(Map<String, dynamic> libro) {
    final TextEditingController cantidadController = TextEditingController(text: '1');
    final titulo = libro['titulo'] ?? 'este libro';
    final idLibro = libro['id_libro'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool enviando = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.library_add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Aumentar Stock'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Libro: $titulo',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: cantidadController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad de nuevos ejemplares',
                      hintText: 'Ej. 3',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_shopping_cart),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: enviando
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: enviando
                      ? null
                      : () async {
                          final cantidad = int.tryParse(cantidadController.text.trim()) ?? 0;
                          if (cantidad <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ingresa una cantidad válida mayor a 0.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => enviando = true);

                          final res = await LibroService.aumentarStock(
                            idLibro: idLibro,
                            cantidad: cantidad,
                          );

                          if (!mounted) return;
                          Navigator.of(dialogContext).pop();

                          if (res['ok'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['mensaje'] ?? '¡Stock aumentado con éxito!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            setState(() {
                              _cargandoLibros = true;
                            });
                            await _cargarLibros();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['mensaje'] ?? 'Error al aumentar stock'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: enviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add, size: 18),
                  label: const Text('Aumentar Stock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navegarAHistorial() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistorialScreen()),
    );
  }

  void _mostrarModuloAdmin(String modulo) {
    if (modulo == 'Pendientes') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrestamosPendientesScreen()),
      ).then((_) => _cargarLibros());
      return;
    }
    if (modulo == 'Inventario') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InventarioScreen()),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Módulo $modulo habilitado para rol: $_rolUsuario'),
        backgroundColor: Colors.indigo.shade700,
      ),
    );
  }

  Widget _construirDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                border: Border(
                  bottom: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'CV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'BIBLIOTECA PÚBLICA',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_nombreUsuario ($_rolUsuario)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Opciones visibles para TODOS los roles (Admin, Estudiante, Profesor)
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.blue),
              title: const Text('Catálogo de Libros'),
              onTap: () {
                Navigator.pop(context);
                _cargarLibros();
              },
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.blue),
              title: const Text('Mis Préstamos y Multas'),
              onTap: () {
                Navigator.pop(context);
                _navegarAHistorial();
              },
            ),

            // Condicional (if): "Inventario" y "Usuarios" SOLO se renderizan si el rol es "Admin"
            if (_esAdmin) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'ADMINISTRACIÓN (SOLO ADMIN)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions, color: Colors.indigo),
                title: const Text(
                  'Préstamos Pendientes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Aprobar o rechazar solicitudes'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarModuloAdmin('Pendientes');
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2, color: Colors.indigo),
                title: const Text(
                  'Inventario',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Gestión de libros y ejemplares'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarModuloAdmin('Inventario');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_alt, color: Colors.indigo),
                title: const Text(
                  'Usuarios',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Gestión de roles y carga Excel'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarModuloAdmin('Usuarios');
                },
              ),
              const Divider(),
            ],

            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.blue),
              title: const Text('Reserva de Salas'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Módulo Reserva de Salas disponible en sede')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.blue),
              title: const Text('Eventos y Actividades'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximo club de lectura: Viernes 4:00 PM')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.blue),
              title: const Text('Búsqueda Avanzada'),
              onTap: () {
                Navigator.pop(context);
                _cargarLibros();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blue),
              title: const Text('Ayuda y Contacto'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Línea de atención Biblioteca Escolar SENA')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar Sesión'),
              onTap: () async {
                await UsuarioService.cerrarSesion();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Construcción condicional de los items del BottomNavigationBar según el rol en el JWT
    final List<BottomNavigationBarItem> bottomItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Catálogo',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bookmark),
        label: 'Mis Préstamos',
      ),
      if (_esAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.pending_actions),
          label: 'Pendientes',
        ),
      if (_esAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: 'Inventario',
        ),
      if (_esAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_alt),
          label: 'Usuarios',
        ),
    ];

    final int safeIndex =
        _bottomNavIndex >= bottomItems.length ? 0 : _bottomNavIndex;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _esAdmin
          ? FloatingActionButton(
              onPressed: _mostrarModalCrearLibro,
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              tooltip: 'Crear Libro',
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calidad a su servicio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Rol activo: $_rolUsuario · $_nombreUsuario',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Abrir menú',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      drawer: _construirDrawer(),
      endDrawer: _construirDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Parte superior: Logo circular grande "CV" centrado
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'CV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Centro: ListTiles adaptados a la biblioteca + accesos condicionales si es Admin
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.location_on, color: Colors.blue),
                      ),
                      title: const Text(
                        'Ubicación de sede',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Sesión: $_nombreUsuario ($_rolUsuario)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Usuario autenticado con documento $_documentoUsuario ($_rolUsuario)'),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.library_books, color: Colors.blue),
                      ),
                      title: const Text(
                        'Préstamos activos',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Consulta tus ejemplares prestados y devoluciones'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _navegarAHistorial,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.manage_search, color: Colors.blue),
                      ),
                      title: const Text(
                        'Búsqueda de material',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${_libros.length} títulos disponibles en el catálogo'),
                      trailing: const Icon(Icons.refresh),
                      onTap: _cargarLibros,
                    ),
                    if (_esAdmin) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EAF6),
                          child: Icon(Icons.inventory_2, color: Colors.indigo),
                        ),
                        title: const Text(
                          'Gestión de Inventario (Solo Admin)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        subtitle: const Text('Control de ejemplares físicos y estado'),
                        trailing: const Icon(Icons.admin_panel_settings, color: Colors.indigo),
                        onTap: () => _mostrarModuloAdmin('Inventario'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EAF6),
                          child: Icon(Icons.people_alt, color: Colors.indigo),
                        ),
                        title: const Text(
                          'Gestión de Usuarios (Solo Admin)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        subtitle: const Text('Administración de Estudiantes, Profesores y Excel'),
                        trailing: const Icon(Icons.admin_panel_settings, color: Colors.indigo),
                        onTap: () => _mostrarModuloAdmin('Usuarios'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Parte inferior: Card grande con bordes redondeados e imagen de internet + botón redondeado
              Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        SizedBox(
                          height: 190,
                          width: double.infinity,
                          child: Image.network(
                            'https://picsum.photos/400/200',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.blue.shade100,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 64,
                                  color: Colors.blue,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _cargarLibros,
                            icon: const Icon(Icons.home),
                            label: const Text(
                              'Ver Catálogo',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Título de la lista de base de datos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Catálogo de Libros (En Vivo)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.blue),
                    onPressed: _cargarLibros,
                    tooltip: 'Recargar libros',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 4. Debajo del Card: ListView.builder con NeverScrollableScrollPhysics y shrinkWrap: true
              if (_cargandoLibros)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMensaje != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _errorMensaje!,
                          style: TextStyle(color: Colors.red.shade800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _cargarLibros,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_libros.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No hay libros registrados en la base de datos.'),
                    ),
                  ),
                )
              else
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _libros.length,
                  itemBuilder: (context, index) {
                    final libro = _libros[index];
                    final List<dynamic> ejemplares =
                        (libro['ejemplares'] as List<dynamic>?) ?? [];
                    final int disponibles = ejemplares
                        .where((e) => e['disponibilidad'] == 'disponible')
                        .length;

                    final bool tieneStock = disponibles > 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  child: const Icon(Icons.book, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        libro['titulo']?.toString() ?? 'Sin título',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Autor: ${libro['autor'] ?? 'Desconocido'}',
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              libro['area']?.toString() ?? 'General',
                                              style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: tieneStock ? Colors.green.shade50 : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              tieneStock ? 'Stock: $disponibles disp.' : 'Agotado (0 disp.)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: tieneStock ? Colors.green.shade800 : Colors.red.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_esAdmin) ...[
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue.shade700,
                                    ),
                                    icon: const Icon(Icons.library_add, size: 18),
                                    label: const Text('Aumentar Stock'),
                                    onPressed: () => _mostrarModalAumentarStock(libro),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Eliminar libro',
                                    onPressed: () => _eliminarLibro(libro),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                TextButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetalleLibro(
                                          libro: libro,
                                          puedeSolicitar: _puedeSolicitar,
                                        ),
                                      ),
                                    );
                                    _cargarLibros();
                                  },
                                  icon: const Icon(Icons.info_outline, size: 18),
                                  label: const Text('Ver Detalle'),
                                ),
                                if (_puedeSolicitar) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: tieneStock ? Colors.blue.shade700 : Colors.grey.shade400,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    onPressed: tieneStock
                                        ? () => _solicitarPrestamoDirecto(libro)
                                        : null,
                                    icon: Icon(tieneStock ? Icons.bookmark_add : Icons.block, size: 18),
                                    label: const Text('Solicitar'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: safeIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey.shade600,
        onTap: (index) {
          setState(() => _bottomNavIndex = index);
          if (index == 0) {
            _cargarLibros();
          } else if (index == 1) {
            _navegarAHistorial();
          } else if (_esAdmin && index == 2) {
            _mostrarModuloAdmin('Pendientes');
          } else if (_esAdmin && index == 3) {
            _mostrarModuloAdmin('Inventario');
          } else if (_esAdmin && index == 4) {
            _mostrarModuloAdmin('Usuarios');
          }
        },
        items: bottomItems,
      ),
    );
  }
}
