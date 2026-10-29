import 'package:flutter/material.dart';
import '../controllers/prestamo_controller.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<Map<String, dynamic>> _historial = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final datos = await PrestamoService.obtenerHistorial();
      if (mounted) {
        setState(() {
          _historial = datos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Mis Préstamos y Multas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar historial',
            onPressed: _cargarHistorial,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _cargarHistorial,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _historial.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Aún no tienes préstamos registrados en tu historial.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _historial.length,
                        itemBuilder: (context, index) {
                          final item = _historial[index];
                          final Map<String, dynamic> libro =
                              (item['libro'] as Map<String, dynamic>?) ?? {};
                          final Map<String, dynamic> ejemplar =
                              (item['ejemplar'] as Map<String, dynamic>?) ?? {};
                          final String estado =
                              item['estado']?.toString() ?? 'activo';
                          final bool esActivo = estado == 'activo';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: esActivo
                                    ? Colors.orange.shade100
                                    : Colors.green.shade100,
                                child: Icon(
                                  esActivo
                                      ? Icons.schedule
                                      : Icons.check_circle,
                                  color: esActivo
                                      ? Colors.orange.shade800
                                      : Colors.green.shade800,
                                ),
                              ),
                              title: Text(
                                libro['titulo']?.toString() ??
                                    'Préstamo #${item['id_prestamo']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ejemplar: ${ejemplar['codigo_inventario'] ?? item['id_ejemplar']}',
                                  ),
                                  Text(
                                    'Fecha préstamo: ${item['fecha_prestamo'] ?? '---'}',
                                  ),
                                  if (item['fecha_devolucion'] != null)
                                    Text(
                                      'Fecha devolución: ${item['fecha_devolucion']}',
                                    ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  estado.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: esActivo
                                        ? Colors.orange.shade900
                                        : Colors.green.shade900,
                                  ),
                                ),
                                backgroundColor: esActivo
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
