import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';

// Importa las pantallas necesarias
import 'package:goodjob_app/src/screens/admin/crear_trabajo_screen.dart';
// ⚠️ IMPORTACIÓN CORREGIDA: Pantalla de detalle del postulante
import 'package:goodjob_app/src/screens/admin/postulante_detalle_screen.dart';

// Importa los widgets de admin
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_gestion_pago.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_info_postulante.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_lista_postulantes.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_mensaje_informativo.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_revision_evidencias.dart';

class DetalleTrabajoAdminScreen extends StatelessWidget {
  final Trabajo trabajo;

  // Servicios
  final PostulacionService postulacionService;
  final PostulanteService postulanteService;
  final TrabajoService trabajoService;
  final StorageService storageService;
  final String adminId;

  DetalleTrabajoAdminScreen({
    super.key,
    required this.trabajo,
    required this.adminId,
    PostulacionService? postulacionService,
    PostulanteService? postulanteService,
    TrabajoService? trabajoService,
    StorageService? storageService,
  }) : postulacionService = postulacionService ?? PostulacionService(),
       postulanteService = postulanteService ?? PostulanteService(),
       trabajoService = trabajoService ?? TrabajoService(),
       storageService = storageService ?? StorageService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trabajo?>(
      stream: trabajoService.escucharTrabajo(trabajo.id),
      initialData: trabajo,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del Trabajo')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Ocurrió un error al cargar el trabajo. Intenta nuevamente.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final trabajoActual = snapshot.data;

        if (trabajoActual == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del Trabajo')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Este trabajo ya no está disponible.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final Color primaryColor = Theme.of(context).primaryColor;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle del Trabajo'),
            actions: [
              if (trabajoActual.estado == EstadoTrabajo.activo)
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: 'Editar Trabajo',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CrearTrabajoScreen(
                          trabajoParaEditar: trabajoActual,
                        ),
                      ),
                    ).then((resultadoEdicion) {
                      if (resultadoEdicion == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trabajo actualizado'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    });
                  },
                ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                trabajoActual.titulo,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Chip(
                              label: Text(
                                trabajoActual.estado.texto,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      trabajoActual.estado.colorTextoChip,
                                  fontSize: 13,
                                ),
                              ),
                              backgroundColor: trabajoActual.estado.colorChip
                                  .withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _CollapsibleInfoContainer(trabajo: trabajoActual),
                        const SizedBox(height: 24),
                        const SizedBox(height: 16),
                        ..._buildDynamicContent(context, trabajoActual),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  /// ⚠️ FUNCIÓN CORREGIDA: Usa trabajo.trabajadorAsignadoId directamente
  Widget _buildInfoPostulanteCondicional(
    BuildContext context,
    Trabajo trabajoActual, {
    String? mensaje,
  }) {
    final String? postulanteId = trabajoActual.trabajadorAsignadoId;

    if (postulanteId == null) {
      return const SizedBox.shrink(); // No mostrar nada si no hay ID
    }

    return InkWell(
      // ⚠️ REDIRECCIÓN AL PERFIL DEL POSTULANTE
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostulanteDetalleScreen(
              usuarioId: postulanteId, // Usamos la variable local correcta
              trabajoId: trabajoActual.id, // ID del trabajo actual
            ),
          ),
        );
      },
      // Usamos el widget existente para mostrar la tarjeta de información
      child: WidgetInfoPostulante(
        trabajo: trabajoActual,
        postulanteService: postulanteService,
        mensaje: mensaje ?? 'Postulante asignado a este trabajo.',
      ),
    );
  }

  /// Decide qué widgets mostrar según el estado
  List<Widget> _buildDynamicContent(
      BuildContext context, Trabajo trabajoActual) {
    const spacer = SizedBox(height: 24);

    switch (trabajoActual.estado) {
      case EstadoTrabajo.activo:
        return [
          WidgetListaPostulantes(
            trabajo: trabajoActual,
            postulacionService: postulacionService,
            postulanteService: postulanteService,
          ),
        ];
      case EstadoTrabajo.porRevisar:
        return [
          WidgetRevisionEvidencias(
            trabajo: trabajoActual,
            trabajoService: trabajoService,
            storageService: storageService,
          ),
          spacer,
          _buildInfoPostulanteCondicional(
            context,
            trabajoActual,
            mensaje: 'Postulante esperando revisión...',
          ),
        ];
      case EstadoTrabajo.porPagar:
        return [
          WidgetGestionPago(
            trabajo: trabajoActual,
            postulanteService: postulanteService,
            postulacionService: postulacionService,
            trabajoService: trabajoService,
            storageService: storageService,
            adminId: adminId,
          ),
          spacer,
          _buildInfoPostulanteCondicional(
            context,
            trabajoActual,
            mensaje: 'Postulante esperando pago.',
          ),
        ];
      case EstadoTrabajo.porConfirmar:
        return [
          WidgetMensajeInformativo(
            icono: Icons.hourglass_top_rounded,
            mensaje: 'Esperando confirmación...',
            color: trabajoActual.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context, trabajoActual),
        ];
      case EstadoTrabajo.pendiente:
        return [
          WidgetMensajeInformativo(
            icono: Icons.calendar_today_outlined,
            mensaje: 'Trabajo agendado.',
            color: trabajoActual.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(
            context,
            trabajoActual,
            mensaje: 'Postulante agendado.',
          ),
        ];
      case EstadoTrabajo.enCurso:
        return [
          WidgetMensajeInformativo(
            icono: Icons.directions_run_rounded,
            mensaje: 'Trabajo en curso.',
            color: trabajoActual.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(
            context,
            trabajoActual,
            mensaje: 'Postulante en trabajo.',
          ),
        ];
      case EstadoTrabajo.finalizado:
        return [
          WidgetMensajeInformativo(
            icono: Icons.check_circle_rounded,
            mensaje: 'Trabajo completado.',
            color: trabajoActual.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(
            context,
            trabajoActual,
            mensaje: 'Trabajo completado por este postulante.',
          ),
        ];
      case EstadoTrabajo.cancelado:
        return [
          WidgetMensajeInformativo(
            icono: Icons.cancel_rounded,
            mensaje: 'Trabajo cancelado.',
            color: trabajoActual.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context, trabajoActual),
        ];
      case EstadoTrabajo.rechazado:
        return [
          WidgetMensajeInformativo(
            icono: Icons.thumb_down_rounded,
            mensaje:
                'Evidencias rechazadas: ${trabajoActual.motivoRechazo ?? "Sin motivo."}',
            color: trabajoActual.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(
            context,
            trabajoActual,
            mensaje: 'Evidencias rechazadas.',
          ),
        ];
      default:
        return [
          Center(
              child: Text('Estado no manejado: ${trabajoActual.estado.name}')),
        ];
    }
  }
}

// --- WIDGET DESPLEGABLE (_CollapsibleInfoContainer) ---
class _CollapsibleInfoContainer extends StatefulWidget {
  final Trabajo trabajo;
  const _CollapsibleInfoContainer({required this.trabajo});

  @override
  State<_CollapsibleInfoContainer> createState() =>
      _CollapsibleInfoContainerState();
}

class _CollapsibleInfoContainerState extends State<_CollapsibleInfoContainer>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _iconAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded)
        _animationController.forward();
      else
        _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final containerColor = colorScheme.surfaceVariant.withOpacity(0.5);

    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_isExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Detalles del Trabajo',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconAnimation,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? _buildExpandedContent(context)
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoSection(
            context: context,
            icon: Icons.description_outlined,
            title: 'Descripción del Servicio',
            child: Text(
              widget.trabajo.descripcion,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 24),
          _InfoSection(
            context: context,
            icon: Icons.list_alt_outlined,
            title: 'Detalles de Ejecución',
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: widget.trabajo.ubicacion['direccion'] ?? 'N/A',
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text:
                      'Inicia: ${FormatUtils.formatDate(widget.trabajo.fechaInicioTrabajo)}',
                ),
                _InfoRow(
                  icon: Icons.flag_outlined,
                  text:
                      'Finaliza: ${FormatUtils.formatDate(widget.trabajo.fechaFinTrabajo)}',
                ),
                if (widget.trabajo.estado != EstadoTrabajo.cancelado &&
                    widget.trabajo.estado != EstadoTrabajo.rechazado) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.attach_money_outlined,
                    text: FormatUtils.formatCurrency(widget.trabajo.precio),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// --- FIN WIDGET DESPLEGABLE ---

// --- HELPERS _InfoSection y _InfoRow ---
Widget _InfoSection({
  required BuildContext context,
  required IconData icon,
  required String title,
  required Widget child,
}) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(title, style: textTheme.titleLarge?.copyWith(fontSize: 18)),
        ],
      ),
      const SizedBox(height: 12),
      Padding(padding: const EdgeInsets.only(left: 4.0), child: child),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
// --- FIN HELPERS ---