import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';

class WidgetRevisionEvidencias extends StatefulWidget {
  final Trabajo trabajo;
  final TrabajoService trabajoService;
  final StorageService storageService;
  final PostulanteService postulanteService;

  WidgetRevisionEvidencias({
    Key? key,
    required this.trabajo,
    required this.trabajoService,
    required this.storageService,
    PostulanteService? postulanteService,
  }) : postulanteService = postulanteService ?? PostulanteService(),
       super(key: key);

  @override
  State<WidgetRevisionEvidencias> createState() => _WidgetRevisionEvidenciasState();
}

class _WidgetRevisionEvidenciasState extends State<WidgetRevisionEvidencias> {
  bool _isLoading = false;
  Future<Map<String, dynamic>?>? _postulanteFuture;

  @override
  void initState() {
    super.initState();
    final assignedWorkerId = widget.trabajo.trabajadorAsignadoId;
    if (assignedWorkerId != null && assignedWorkerId.isNotEmpty) {
      _postulanteFuture =
          widget.postulanteService.obtenerDatosUsuario(assignedWorkerId);
    }
  }

  void _aprobar() async {
    final confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar Evidencias'),
        content: const Text('¿Estás seguro de que deseas aprobar estas evidencias y pasar al pago?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Aprobar')),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      // CONECTADO A TU MÉTODO
      await widget.trabajoService.actualizarEstado(
        widget.trabajo.id,
        EstadoTrabajo.porPagar, // Pasa al siguiente estado
      );
      // La UI se recargará sola si la pantalla principal escucha al stream del trabajo
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al aprobar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _rechazar() async {
    // 1. Pedir motivo de rechazo
    String? motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogoRechazo(), // Usa el widget helper de abajo
    );

    if (motivo == null || motivo.isEmpty) return; // Canceló

    setState(() => _isLoading = true);
    try {
      // CONECTADO AL MÉTODO ACTUALIZADO
      // Usamos este porque necesitamos guardar MÁS DE UN CAMPO
      await widget.trabajoService.actualizarCamposTrabajo(widget.trabajo.id, {
        'estado': EstadoTrabajo.rechazado.name, // El estado
        'motivoRechazo': motivo,                // Y el motivo
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al rechazar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revisión de Evidencias',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('El postulante ha marcado el trabajo como finalizado y subió las siguientes evidencias:'),
        const SizedBox(height: 16),

        if (_postulanteFuture != null) ...[
          Text(
            'Trabajador asignado',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>?>(
            future: _postulanteFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Text(
                    'No se pudieron cargar los datos del trabajador asignado.');
              }

              final postulanteData = snapshot.data;
              if (postulanteData == null) {
                return const Text(
                    'No encontramos información del trabajador asignado.');
              }

              final nombre = postulanteData['nombre'] as String? ?? 'Sin nombre';
              final telefono =
                  postulanteData['telefono'] as String? ?? 'No disponible';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                    ),
                  ),
                  title: Text(nombre),
                  subtitle: Text('Contacto: $telefono'),
                ),
              );
            },
          ),
        ],
        // --- AQUÍ ESTÁ EL CAMBIO ---
        // Usamos un StreamBuilder para mostrar las evidencias en tiempo real
        StreamBuilder<List<Map<String, dynamic>>>(
          // ¡CONECTADO A TU SERVICIO!
          stream: widget.storageService.mostrarEvidencias(widget.trabajo.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error al cargar evidencias: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('El postulante no subió evidencias.')),
              );
            }

            final evidencias = snapshot.data!; // Lista de Mapas

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: evidencias.length, // Dato real
              itemBuilder: (context, index) {
                final evidencia = evidencias[index];
                final String url = evidencia['url'] as String;
                final String etapa = evidencia['etapa'] as String? ?? 'Evidencia';

                return InkWell(
                  onTap: () {
                    // TODO: Navegar a un visor de imagen en pantalla completa
                    print('Ver imagen: $url');
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          url, // Dato real
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) => progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.black.withOpacity(0.6),
                            child: Text(
                              // Capitaliza la etapa (ej: "Inicio")
                              etapa.isNotEmpty ? '${etapa[0].toUpperCase()}${etapa.substring(1)}' : '',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rechazar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _rechazar, // Conectado
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aprobar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _aprobar, // Conectado
              ),
            ),
          ],
        )
      ],
    );
  }
}

/// Widget helper para el diálogo de rechazo
class _DialogoRechazo extends StatefulWidget {
  @override
  _DialogoRechazoState createState() => _DialogoRechazoState();
}

class _DialogoRechazoState extends State<_DialogoRechazo> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar Evidencias'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo',
            hintText: 'Escribe por qué se rechazan las evidencias...',
            border: OutlineInputBorder(),
          ),
          validator: (value) => (value == null || value.isEmpty) ? 'Debe ingresar un motivo' : null,
          maxLines: 3,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}