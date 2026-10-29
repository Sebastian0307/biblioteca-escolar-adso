import 'package:flutter/material.dart';
import '../controllers/prestamo_controller.dart';
import '../services/libro_service.dart';

class DetalleLibro extends StatefulWidget {
  final Map<String, dynamic> libro;
  final bool puedeSolicitar;

  const DetalleLibro({
    super.key,
    required this.libro,
    this.puedeSolicitar = true,
  });

  @override
  State<DetalleLibro> createState() => _DetalleLibroState();
}

class _DetalleLibroState extends State<DetalleLibro> {
  bool isLoading = false;
  int? _idEjemplarSeleccionado;

  List<Map<String, dynamic>> get _ejemplares {
    final raw = (widget.libro['ejemplares'] as List<dynamic>?) ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> get _ejemplaresDisponibles {
    return _ejemplares
        .where((e) => e['disponibilidad'] == 'disponible')
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (_ejemplaresDisponibles.isNotEmpty) {
      _idEjemplarSeleccionado =
          _ejemplaresDisponibles.first['id_ejemplar'] as int?;
    }
  }

  Future<void> _solicitarPrestamo() async {
    if (_idEjemplarSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No hay ejemplares disponibles para este libro.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final respuesta = await PrestamoService.solicitarPrestamo(
        _idEjemplarSeleccionado!,
      );

      if (!mounted) return;

      final bool exito = respuesta['ok'] == true;

      if (exito) {
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
              '¡Solicitud registrada con éxito para "${widget.libro['titulo']}"!\n\n'
              'El préstamo ha quedado guardado con estado "pendiente" en la base de datos Supabase.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              respuesta['mensaje'] ?? 'Error al solicitar el préstamo',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar solicitud: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _abrirDialogoAumentarStock() async {
    final TextEditingController cantidadController = TextEditingController(text: '1');
    final titulo = widget.libro['titulo'] ?? 'este libro';
    final idLibro = widget.libro['id_libro'];

    final confirmar = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            Text('Libro: $titulo', style: const TextStyle(fontWeight: FontWeight.w600)),
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
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final cant = int.tryParse(cantidadController.text.trim()) ?? 0;
              Navigator.pop(ctx, cant);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aumentar'),
          ),
        ],
      ),
    );

    if (confirmar == null || confirmar <= 0) return;

    setState(() => isLoading = true);
    final res = await LibroService.aumentarStock(idLibro: idLibro, cantidad: confirmar);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (res['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje'] ?? '¡Stock aumentado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['mensaje'] ?? 'Error al aumentar stock'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.libro['titulo']?.toString() ?? 'Libro';
    final autor = widget.libro['autor']?.toString() ?? 'Autor desconocido';
    final area = widget.libro['area']?.toString() ?? 'General';
    final anio = widget.libro['anio_publicacion']?.toString() ?? '';
    final codigo = widget.libro['codigo_libro']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Detalle del Libro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Imagen del libro en Card redondeado
              Card(
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SizedBox(
                  height: 210,
                  child: Image.network(
                    'https://picsum.photos/seed/${widget.libro['id_libro'] ?? 1}/500/300',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.blue.shade100,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.menu_book,
                          size: 72,
                          color: Colors.blue,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Datos principales del libro
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text('Área: $area'),
                            backgroundColor: Colors.blue.shade50,
                          ),
                          if (anio.isNotEmpty)
                            Chip(
                              label: Text('Año: $anio'),
                              backgroundColor: Colors.grey.shade200,
                            ),
                          if (codigo.isNotEmpty)
                            Chip(
                              label: Text('Código: $codigo'),
                              backgroundColor: Colors.grey.shade200,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Autor: $autor',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Ejemplares Físicos (${_ejemplaresDisponibles.length}/${_ejemplares.length} disponibles):',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_ejemplares.isEmpty)
                        const Text(
                          'No hay ejemplares registrados para este libro.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ..._ejemplares.map((ej) {
                          final bool disponible =
                              ej['disponibilidad'] == 'disponible';
                          final int idEj = ej['id_ejemplar'] as int;
                          return RadioListTile<int>(
                            value: idEj,
                            groupValue: _idEjemplarSeleccionado,
                            onChanged: disponible
                                ? (val) {
                                    setState(() {
                                      _idEjemplarSeleccionado = val;
                                    });
                                  }
                                : null,
                            title: Text(
                              'Inventario: ${ej['codigo_inventario']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Condición: ${ej['condicion']} · Estado: ${ej['disponibilidad']}',
                            ),
                            secondary: Icon(
                              disponible
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              color: disponible ? Colors.green : Colors.red,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Botón Solicitar Préstamo (solo visible para Estudiantes y Profesores)
              if (widget.puedeSolicitar)
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: (isLoading || _ejemplaresDisponibles.isEmpty)
                        ? null
                        : _solicitarPrestamo,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.bookmark_add),
                    label: Text(
                      isLoading
                          ? 'Enviando solicitud...'
                          : (_ejemplaresDisponibles.isNotEmpty
                              ? 'Solicitar Préstamo'
                              : 'Sin Ejemplares Disponibles'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _abrirDialogoAumentarStock,
                        icon: const Icon(Icons.library_add),
                        label: const Text(
                          'Aumentar Stock',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.amber.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Vista en modo Administrador. Puedes agregar más ejemplares usando el botón superior.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
