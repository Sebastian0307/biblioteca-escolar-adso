import 'package:flutter/material.dart';
import '../services/libro_service.dart';

/// Pantalla de administración de libros (CRUD) para el rol de Administrador.
class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  void _mostrarModalCrearLibro(BuildContext context) {
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

                          Navigator.of(dialogContext).pop();

                          if (res['ok'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['mensaje'] ?? '¡Libro creado con éxito!'),
                                backgroundColor: Colors.green,
                              ),
                            );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Administración de Libros'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarModalCrearLibro(context),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        tooltip: 'Crear Libro',
        child: const Icon(Icons.add),
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Módulo de Administración de Libros\nPresiona el botón (+) flotante para agregar un libro.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.blueGrey),
            ),
          ),
        ),
      ),
    );
  }
}
