import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceActual = 0;
  bool _cargando = false;

  List<dynamic> _libros = [];
  List<dynamic> _misPrestamos = [];
  List<dynamic> _misSolicitudes = [];
  List<dynamic> _solicitudesAdmin = [];
  List<dynamic> _prestamosAdmin = [];

  bool get _esAdmin => widget.usuario['tipo_usuario'] == 'administrador';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    try {
      final libros = await ApiService.listarLibros();
      final misPres = await ApiService.obtenerMisPrestamos();
      final misSol = await ApiService.obtenerMisSolicitudes();

      List<dynamic> solAdmin = [];
      List<dynamic> presAdmin = [];
      if (_esAdmin) {
        solAdmin = await ApiService.listarTodasLasSolicitudes();
        presAdmin = await ApiService.listarTodosLosPrestamos();
      }

      if (mounted) {
        setState(() {
          _libros = libros;
          _misPrestamos = misPres;
          _misSolicitudes = misSol;
          _solicitudesAdmin = solAdmin;
          _prestamosAdmin = presAdmin;
        });
      }
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: esError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _solicitarEjemplar(int idEjemplar) async {
    try {
      final res = await ApiService.solicitarPrestamo(idEjemplar);
      _mostrarMensaje(res['mensaje'] ?? 'Solicitud enviada');
      _cargarTodo();
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
    }
  }

  Future<void> _aprobarSolicitud(int idSolicitud) async {
    try {
      final res = await ApiService.aprobarSolicitud(idSolicitud);
      _mostrarMensaje(res['mensaje'] ?? 'Solicitud aprobada');
      _cargarTodo();
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
    }
  }

  Future<void> _devolverPrestamo(int idPrestamo) async {
    try {
      final res = await ApiService.registrarDevolucion(idPrestamo);
      _mostrarMensaje(res['mensaje'] ?? 'Devolución registrada');
      _cargarTodo();
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
    }
  }

  Future<void> _subirExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        _mostrarMensaje('No se pudo leer el contenido del archivo', esError: true);
        return;
      }

      final res = await ApiService.subirExcelUsuarios(file.bytes!, file.name);
      _mostrarMensaje(res['mensaje'] ?? 'Usuarios cargados con éxito');
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
    }
  }

  Future<void> _mostrarDialogoNuevoLibro() async {
    final codigoCtrl = TextEditingController();
    final tituloCtrl = TextEditingController();
    final autorCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final anioCtrl = TextEditingController(text: '2024');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Nuevo Libro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codigoCtrl, decoration: const InputDecoration(labelText: 'Código (ej. LIB-025)')),
              TextField(controller: tituloCtrl, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: autorCtrl, decoration: const InputDecoration(labelText: 'Autor')),
              TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: 'Área')),
              TextField(controller: anioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Año de publicación')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              try {
                await ApiService.crearLibro(
                  codigoLibro: codigoCtrl.text.trim(),
                  titulo: tituloCtrl.text.trim(),
                  autor: autorCtrl.text.trim(),
                  area: areaCtrl.text.trim(),
                  anioPublicacion: int.tryParse(anioCtrl.text.trim()) ?? 2024,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _mostrarMensaje('Libro creado exitosamente');
                _cargarTodo();
              } catch (e) {
                _mostrarMensaje(e.toString().replaceAll('Exception: ', ''), esError: true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      _buildCatalogoTab(),
      _buildMisPrestamosTab(),
      if (_esAdmin) _buildAdminTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ${widget.usuario['nombre']} ${widget.usuario['apellido']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Rol: ${widget.usuario['tipo_usuario'].toString().toUpperCase()} · Doc: ${widget.usuario['documento']}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarTodo,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ApiService.cerrarSesion();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : paginas[_indiceActual],
      floatingActionButton: (_esAdmin && _indiceActual == 0)
          ? FloatingActionButton.extended(
              onPressed: _mostrarDialogoNuevoLibro,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Libro'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (i) => setState(() => _indiceActual = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Catálogo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Mis Préstamos',
          ),
          if (_esAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Panel Admin',
            ),
        ],
      ),
    );
  }

  Widget _buildCatalogoTab() {
    if (_libros.isEmpty) {
      return const Center(child: Text('No hay libros en el catálogo.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _libros.length,
      itemBuilder: (ctx, i) {
        final libro = _libros[i];
        final ejemplares = (libro['ejemplares'] as List<dynamic>? ?? []);
        final disponibles = ejemplares.where((e) => e['disponibilidad'] == 'disponible').toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text('${libro['area']} · ${libro['anio_publicacion']}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      '${disponibles.length}/${ejemplares.length} disponibles',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: disponibles.isNotEmpty ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  libro['titulo'] ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Autor: ${libro['autor']} (${libro['codigo_libro']})',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: disponibles.isNotEmpty
                        ? () => _solicitarEjemplar(disponibles.first['id_ejemplar'])
                        : null,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      disponibles.isNotEmpty
                          ? 'Solicitar Ejemplar (${disponibles.first['codigo_inventario']})'
                          : 'Sin ejemplares disponibles',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMisPrestamosTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Mis Préstamos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_misPrestamos.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tienes préstamos registrados.'),
            ),
          ),
        ..._misPrestamos.map((p) {
          final libro = p['libro'] ?? {};
          final ejemplar = p['ejemplar'] ?? {};
          final activo = p['estado'] == 'activo';
          return Card(
            child: ListTile(
              leading: Icon(
                activo ? Icons.schedule : Icons.check_circle,
                color: activo ? Colors.orange : Colors.green,
              ),
              title: Text(libro['titulo'] ?? 'Libro'),
              subtitle: Text('Inv: ${ejemplar['codigo_inventario']} · Fecha: ${p['fecha_prestamo']}'),
              trailing: Chip(label: Text(p['estado'] ?? '')),
            ),
          );
        }),
        const SizedBox(height: 20),
        const Text(
          'Mis Solicitudes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_misSolicitudes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tienes solicitudes enviadas.'),
            ),
          ),
        ..._misSolicitudes.map((s) {
          final ejemplar = s['ejemplar'] ?? {};
          final libro = ejemplar['libro'] ?? {};
          return Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: Text(libro['titulo'] ?? 'Solicitud #${s['id_solicitud']}'),
              subtitle: Text('Ejemplar: ${ejemplar['codigo_inventario']}'),
              trailing: Chip(label: Text(s['estado'] ?? '')),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdminTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFEEF2FF),
          child: ListTile(
            leading: const Icon(Icons.upload_file, color: Color(0xFF4F46E5)),
            title: const Text(
              'Carga Masiva de Usuarios desde Excel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Sube un archivo .xlsx y encripta el documento con bcrypt'),
            trailing: FilledButton(
              onPressed: _subirExcel,
              child: const Text('Subir Excel'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Solicitudes de Préstamo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._solicitudesAdmin.map((s) {
          final usuario = s['usuario'] ?? {};
          final ejemplar = s['ejemplar'] ?? {};
          final libro = ejemplar['libro'] ?? {};
          final pendiente = s['estado'] == 'pendiente';
          return Card(
            child: ListTile(
              title: Text('${libro['titulo'] ?? 'Libro'} (${ejemplar['codigo_inventario']})'),
              subtitle: Text('Solicitante: ${usuario['nombre']} ${usuario['apellido']} · Estado: ${s['estado']}'),
              trailing: pendiente
                  ? FilledButton(
                      onPressed: () => _aprobarSolicitud(s['id_solicitud']),
                      child: const Text('Aprobar'),
                    )
                  : Chip(label: Text(s['estado'] ?? '')),
            ),
          );
        }),
        const SizedBox(height: 20),
        const Text(
          'Préstamos Activos y Devoluciones',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._prestamosAdmin.map((p) {
          final usuario = p['usuario'] ?? {};
          final libro = p['libro'] ?? {};
          final ejemplar = p['ejemplar'] ?? {};
          final activo = p['estado'] == 'activo';
          return Card(
            child: ListTile(
              title: Text('${libro['titulo'] ?? 'Libro'} (${ejemplar['codigo_inventario']})'),
              subtitle: Text('Usuario: ${usuario['nombre']} ${usuario['apellido']} · Fecha: ${p['fecha_prestamo']}'),
              trailing: activo
                  ? FilledButton.tonal(
                      onPressed: () => _devolverPrestamo(p['id_prestamo']),
                      child: const Text('Recibir Devolución'),
                    )
                  : const Chip(label: Text('Devuelto')),
            ),
          );
        }),
      ],
    );
  }
}
