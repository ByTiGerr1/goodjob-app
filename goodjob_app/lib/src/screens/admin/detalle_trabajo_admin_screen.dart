import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/utils/format_utils.dart'; // Asegúrate que esta ruta sea correcta
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
  })  : postulacionService = postulacionService ?? PostulacionService(),
        postulanteService = postulanteService ?? PostulanteService(),
        trabajoService = trabajoService ?? TrabajoService(),
        storageService = storageService ?? StorageService();

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Trabajo')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Título y Estado (Sección de Encabezado) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      trabajo.titulo,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(
                      trabajo.estado.texto,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: trabajo.estado.colorTextoChip,
                        fontSize: 13,
                      ),
                    ),
                    backgroundColor: trabajo.estado.colorChip.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 24), // Espacio en blanco

              // --- 2. Contenedor Desplegable (Versión AnimatedSize) ---
              _CollapsibleInfoContainer(trabajo: trabajo),

              const SizedBox(height: 24),

              // --- 3. Contenido Dinámico (Acciones) ---
              Text(
                'Acciones Administrativas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              
              ..._buildDynamicContent(context, trabajo),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper que construye la tarjeta de info del postulante
  Widget _buildInfoPostulanteCondicional(BuildContext context, {String? mensaje}) {
    if (trabajo.trabajadorAsignadoId == null) {
      return const SizedBox.shrink();
    }
    return WidgetInfoPostulante(
      trabajo: trabajo,
      postulanteService: postulanteService,
      mensaje: mensaje ?? 'Postulante asignado a este trabajo.',
    );
  }

  /// Decide qué widgets específicos mostrar según el estado del trabajo
  List<Widget> _buildDynamicContent(BuildContext context, Trabajo trabajo) {
    
    const spacer = SizedBox(height: 24); 

    switch (trabajo.estado) {
      case EstadoTrabajo.activo:
        return [
          WidgetListaPostulantes(
            trabajo: trabajo,
            postulacionService: postulacionService,
            postulanteService: postulanteService,
          )
        ];
      case EstadoTrabajo.porRevisar:
        return [
          WidgetRevisionEvidencias(
            trabajo: trabajo,
            trabajoService: trabajoService,
            storageService: storageService,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context,
            mensaje: 'Postulante esperando revisión de evidencias.')
        ];
      case EstadoTrabajo.porPagar:
        return [
          WidgetGestionPago(
            trabajo: trabajo,
            postulanteService: postulanteService,
            trabajoService: trabajoService,
            storageService: storageService,
            adminId: adminId, 
          ),
          spacer,
          _buildInfoPostulanteCondicional(context,
            mensaje: 'Postulante esperando pago.')
        ];
      case EstadoTrabajo.porConfirmar:
        return [
          WidgetMensajeInformativo(
            icono: Icons.hourglass_top_rounded,
            mensaje: 'Esperando que el postulante acepte la oferta.',
            color: trabajo.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context)
        ];

      // ⚠️ CAMBIO DE ICONO REALIZADO AQUÍ 
      case EstadoTrabajo.pendiente:
        return [
          WidgetMensajeInformativo(
            icono: Icons.calendar_today_outlined, // <-- ICONO CAMBIADO
            mensaje: 'El trabajo está agendado y listo para comenzar.',
            color: trabajo.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context,
            mensaje: 'Postulante agendado.')
        ];
        
      case EstadoTrabajo.enCurso:
        return [
          WidgetMensajeInformativo(
            icono: Icons.directions_run_rounded,
            mensaje: 'El trabajo está actualmente en curso.',
            color: trabajo.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context,
            mensaje: 'Postulante en faena.')
        ];
      case EstadoTrabajo.finalizado:
        return [
          WidgetMensajeInformativo(
            icono: Icons.check_circle_rounded,
            mensaje: 'Este trabajo fue completado y pagado exitosamente.',
            color: trabajo.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context,
            mensaje: 'Trabajo completado por este postulante.')
        ];
      case EstadoTrabajo.cancelado:
        return [
          WidgetMensajeInformativo(
            icono: Icons.cancel_rounded,
            mensaje: 'Este trabajo fue cancelado.',
            color: trabajo.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context)
        ];
      case EstadoTrabajo.rechazado:
        return [
          WidgetMensajeInformativo(
            icono: Icons.thumb_down_rounded,
            mensaje: 'Evidencias rechazadas: ${trabajo.motivoRechazo ?? "Sin motivo."}',
            color: trabajo.estado.colorTextoChip,
          ),
          spacer,
          _buildInfoPostulanteCondicional(context,
            mensaje: 'Evidencias rechazadas a este postulante.')
        ];
    }
  }
}

// -------------------------------------------------------------------
// WIDGET DESPLEGABLE MEJORADO (con AnimatedSize)
// -------------------------------------------------------------------
class _CollapsibleInfoContainer extends StatefulWidget {
  final Trabajo trabajo;
  const _CollapsibleInfoContainer({required this.trabajo});

  @override
  State<_CollapsibleInfoContainer> createState() => _CollapsibleInfoContainerState();
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
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
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
          // --- 1. El Encabezado Cliqueable ---
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Detalles del Trabajo',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconAnimation,
                    child: Icon(Icons.expand_more_rounded, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // --- 2. El Contenido Animado (con AnimatedSize) ---
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded 
              ? _buildExpandedContent(context) // Muestra el contenido
              : const SizedBox(width: double.infinity), // Ocupa espacio 0
          ),
        ],
      ),
    );
  }

  /// Contenido interno del desplegable
  Widget _buildExpandedContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          const Divider(height: 32),
          _InfoSection(
            context: context,
            icon: Icons.list_alt_outlined,
            title: 'Detalles de Ejecución',
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: widget.trabajo.ubicacion['direccion'] ?? 'Ubicación no especificada',
                ),
                
                // Usando formatDate como solicitaste
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text: 'Inicia: ${FormatUtils.formatDate(widget.trabajo.fechaInicioTrabajo)}',
                ),
                _InfoRow(
                  icon: Icons.flag_outlined,
                  text: 'Finaliza: ${FormatUtils.formatDate(widget.trabajo.fechaFinTrabajo)}',
                ),

                if (widget.trabajo.estado != EstadoTrabajo.cancelado && 
                    widget.trabajo.estado != EstadoTrabajo.rechazado) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.attach_money_outlined,
                    text: FormatUtils.formatCurrency(widget.trabajo.precio),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// -------------------------------------------------------------------
// (Fin del widget desplegable)
// -------------------------------------------------------------------


/// Helper para títulos de sección con icono
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
          Text(
            title,
            style: textTheme.titleLarge,
          ),
        ],
      ),
      const SizedBox(height: 12),
      child,
    ],
  );
}

/// Widget helper interno (Diseño de Lista Plana)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _InfoRow({required this.icon, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}