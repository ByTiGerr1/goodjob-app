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

  // --- (Lógica _aprobar y _rechazar se mantiene idéntica) ---
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
      await widget.trabajoService.actualizarEstado(
        widget.trabajo.id,
        EstadoTrabajo.porPagar,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al aprobar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _rechazar() async {
    String? motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogoRechazo(),
    );

    if (motivo == null || motivo.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await widget.trabajoService.actualizarCamposTrabajo(widget.trabajo.id, {
        'estado': EstadoTrabajo.rechazado.name,
        'motivoRechazo': motivo,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al rechazar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // --- (Fin de la lógica) ---

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
        // ⚠️ MEJORA UI: Más espacio
        const SizedBox(height: 12),
        const Text('El postulante ha marcado el trabajo como finalizado y subió las siguientes evidencias:'),
        // ⚠️ MEJORA UI: Más espacio
        const SizedBox(height: 20),
        
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.storageService.mostrarEvidencias(widget.trabajo.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildEstadoVacio(
                context: context,
                icono: Icons.error_outline_rounded,
                titulo: 'Error',
                mensaje: 'No se pudieron cargar las evidencias.',
                color: Colors.red.shade700,
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEstadoVacio(
                context: context,
                icono: Icons.image_not_supported_outlined,
                titulo: 'Sin Evidencias',
                mensaje: 'El postulante no ha subido evidencias.',
                color: Colors.grey.shade600,
              );
            }

            final evidencias = snapshot.data!;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                // ⚠️ MEJORA UI: Más espacio entre imágenes
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: evidencias.length,
              itemBuilder: (context, index) {
                final evidencia = evidencias[index];
                final String url = evidencia['url'] as String;
                final String etapa = evidencia['etapa'] as String? ?? 'Evidencia';
                final String etapaCapitalizada = etapa.isNotEmpty ? '${etapa[0].toUpperCase()}${etapa.substring(1)}' : '';

                return InkWell(
                  onTap: () {
                    _mostrarImagenFullScreen(context, url);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) => progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey.shade200,
                                child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade500, size: 40),
                              ),
                        ),
                        
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 36),
                          ),
                        ),

                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.black.withOpacity(0.6),
                            child: Text(
                              etapaCapitalizada,
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
        
        // ⚠️ MEJORA UI: Más espacio antes de los botones
        const SizedBox(height: 32),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close_rounded),
                label: const Text('Rechazar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _rechazar,
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
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _aprobar,
              ),
            ),
          ],
        )
      ],
    );
  }

  // --- (Helper _mostrarImagenFullScreen se mantiene igual) ---
  void _mostrarImagenFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.3)),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: 'Cerrar',
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // --- (Helper _buildEstadoVacio modificado) ---
  Widget _buildEstadoVacio({
    required BuildContext context,
    required IconData icono,
    required String titulo,
    required String mensaje,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, size: 48, color: color),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
          // ⚠️ MEJORA UI: Más espacio
          const SizedBox(height: 8),
          Text(
            mensaje,
            style: textTheme.bodyMedium?.copyWith(color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --- (Helper _DialogoRechazo se mantiene igual) ---
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
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