import 'package:flutter/material.dart';
import '../controllers/prestamo_controller.dart';

/// Vista exclusiva del rol Administrador para revisar y aprobar préstamos pendientes.
class PrestamosPendientesScreen extends StatefulWidget {
  const PrestamosPendientesScreen({super.key});

  @override
  State<PrestamosPendientesScreen> createState() => _PrestamosPendientesScreenState();
}

class _PrestamosPendientesScreenState extends State<PrestamosPendientesScreen> {
  List<Map<String, dynamic>> _pendientes = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final datos = await PrestamoService.obtenerPendientes();
      if (!mounted) return;
      setState(() {
        _pendientes = datos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _procesar(int idSolicitud, bool aprobar) async {
    setState(() => _procesando.add(idSolicitud));

    try {
      final res = aprobar
          ? await PrestamoService.aprobarPrestamo(idSolicitud)
          : await PrestamoService.rechazarPrestamo(idSolicitud);

      if (!mounted) return;
      final bool ok = res['ok'] == true;

      if (ok && aprobar) {
        // Mostrar alerta de éxito conforme a la guía del SENA
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Préstamo Aprobado'),
              ],
            ),
            content: const Text(
              '¡El préstamo se ha registrado con éxito!\n\nEstado actualizado a "activo" y el ejemplar físico ha sido marcado como "prestado" en la base de datos Supabase.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['mensaje']?.toString() ?? ''),
            backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );
      }

      if (ok) {
        setState(() {
          _pendientes.removeWhere((p) => p['id_solicitud'] == idSolicitud);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _procesando.remove(idSolicitud));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Préstamos Pendientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarPendientes,
          ),
        ],
      ),
      body: SafeArea(child: _construirCuerpo()),
    );
  }

  Widget _construirCuerpo() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargarPendientes,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pendientes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarPendientes,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.inbox_outlined, size: 56, color: Colors.blueGrey),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No hay préstamos pendientes por aprobar.',
                style: TextStyle(fontSize: 15, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarPendientes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendientes.length,
        itemBuilder: (context, index) {
          final item = _pendientes[index];
          final int idSolicitud = item['id_solicitud'] as int;
          final Map usuario = (item['usuario'] as Map?) ?? {};
          final Map ejemplar = (item['ejemplar'] as Map?) ?? {};
          final Map libro = (ejemplar['libro'] as Map?) ?? {};
          final bool enProceso = _procesando.contains(idSolicitud);
          final bool disponible = ejemplar['disponibilidad'] == 'disponible';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(Icons.hourglass_top, color: Colors.orange.shade800),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              libro['titulo']?.toString() ?? 'Libro',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Solicitud #$idSolicitud · Ejemplar ${ejemplar['codigo_inventario'] ?? '-'}',
                              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Solicitante: ${usuario['nombre'] ?? ''} ${usuario['apellido'] ?? ''} '
                    '(${usuario['tipo_usuario'] ?? ''}) · Doc: ${usuario['documento'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (!disponible)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'El ejemplar ya no está disponible (${ejemplar['disponibilidad']}).',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: enProceso ? null : () => _procesar(idSolicitud, true),
                          icon: enProceso
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Aprobar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: enProceso ? null : () => _procesar(idSolicitud, false),
                          icon: const Icon(Icons.close),
                          label: const Text('Rechazar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
