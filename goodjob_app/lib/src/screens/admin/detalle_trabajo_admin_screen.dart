import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';

// Importa las pantallas necesarias
import 'package:goodjob_app/src/screens/admin/crear_trabajo_screen.dart';
import 'package:goodjob_app/src/screens/admin/postulante_detalle_screen.dart';

// Importa los widgets de admin
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_detalle_trabajo_colapsable.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_gestion_pago.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_info_postulante.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_lista_postulantes.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_mensaje_informativo.dart';
import 'package:goodjob_app/src/widgets/admin_trabajo/widget_revision_evidencias.dart';

// --- 1. CONVERTIDO A STATEFULWIDGET ---
class DetalleTrabajoAdminScreen extends StatefulWidget {
  final Trabajo trabajo;
  final String adminId;

  // Servicios (opcionales, para inyección de dependencias)
  final PostulacionService? postulacionService;
  final PostulanteService? postulanteService;
  final TrabajoService? trabajoService;
  final StorageService? storageService;

  const DetalleTrabajoAdminScreen({
    super.key,
    required this.trabajo,
    required this.adminId,
    this.postulacionService,
    this.postulanteService,
    this.trabajoService,
    this.storageService,
  });

  @override
  State<DetalleTrabajoAdminScreen> createState() =>
      _DetalleTrabajoAdminScreenState();
}

// --- 2. CREADA LA CLASE STATE ---
class _DetalleTrabajoAdminScreenState extends State<DetalleTrabajoAdminScreen> {
  // Servicios
  late final PostulacionService postulacionService;
  late final PostulanteService postulanteService;
  late final TrabajoService trabajoService;
  late final StorageService storageService;

  // Stream que se inicializará UNA SOLA VEZ
  late final Stream<Trabajo?> _trabajoStream;

  // --- 3. INICIALIZACIÓN EN INITSTATE ---
  @override
  void initState() {
    super.initState();

    // Inicializa los servicios usando los del widget (si se pasaron) o creando nuevos
    postulacionService = widget.postulacionService ?? PostulacionService();
    postulanteService = widget.postulanteService ?? PostulanteService();
    trabajoService = widget.trabajoService ?? TrabajoService();
    storageService = widget.storageService ?? StorageService();

    // ¡Aquí está la magia!
    // El stream se crea UNA VEZ y se reutiliza en todos los StreamBuilders.
    // Usamos widget.trabajo.id para obtener el ID.
    _trabajoStream = trabajoService.escucharTrabajo(widget.trabajo.id);
  }

  // --- 4. MÉTODO BUILD (AHORA DENTRO DEL STATE) ---
  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Trabajo'),
        actions: [
          // BUILDER #1: Solo para el botón de editar
          StreamBuilder<Trabajo?>(
            stream: _trabajoStream,
            initialData: widget.trabajo, // Usa el trabajo inicial del WIDGET
            builder: (context, snapshot) {
              final estadoActual =
                  snapshot.data?.estado ?? widget.trabajo.estado;

              if (estadoActual == EstadoTrabajo.activo) {
                return IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: 'Editar Trabajo',
                  onPressed: () {
                    // Pasamos la versión MÁS reciente del trabajo
                    final trabajoParaEditar = snapshot.data ?? widget.trabajo;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CrearTrabajoScreen(
                          trabajoParaEditar: trabajoParaEditar,
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    // El título no cambia, usamos el dato inicial del WIDGET
                    child: Text(
                      widget.trabajo.titulo,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // BUILDER #2: Solo para el Chip de estado
                  StreamBuilder<Trabajo?>(
                    stream: _trabajoStream,
                    initialData: widget.trabajo,
                    builder: (context, snapshot) {
                      final trabajoVivo = snapshot.data ?? widget.trabajo;
                      return Chip(
                        label: Text(
                          trabajoVivo.estado.texto,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: trabajoVivo.estado.colorTextoChip,
                            fontSize: 13,
                          ),
                        ),
                        backgroundColor:
                            trabajoVivo.estado.colorChip.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tu widget refactorizado. Usa los datos iniciales del WIDGET
              DetalleTrabajoColapsable(trabajo: widget.trabajo),

              const SizedBox(height: 24),
              const SizedBox(height: 16),

              // BUILDER #3: Solo para el contenido dinámico
              StreamBuilder<Trabajo?>(
                stream: _trabajoStream,
                initialData: widget.trabajo,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error al cargar esta sección.'));
                  }

                  final trabajoActual = snapshot.data;

                  if (trabajoActual == null) {
                    return const Center(
                        child: Text('Este trabajo ya no está disponible.'));
                  }

                  // Llama a la función de construcción
                  return Column(
                    children: _buildDynamicContent(context, trabajoActual),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. MÉTODOS HELPER (AHORA DENTRO DEL STATE) ---


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
        ];
      case EstadoTrabajo.porPagar:
        return [
          WidgetGestionPago(
            trabajo: trabajoActual,
            postulanteService: postulanteService,
            postulacionService: postulacionService,
            trabajoService: trabajoService,
            storageService: storageService,
            adminId: widget.adminId, 
          ),
          spacer,
          WidgetRevisionEvidencias(
            trabajo: trabajoActual,
            trabajoService: trabajoService,
            storageService: storageService,
          ),
        ];
      case EstadoTrabajo.porConfirmar:
        return [
          WidgetInfoPostulante(trabajo: trabajoActual, postulanteService: postulanteService),
          spacer,
          WidgetMensajeInformativo(
            icono: Icons.hourglass_top_rounded,
            mensaje: 'Esperando confirmación...',
            color: trabajoActual.estado.colorTextoChip,
          ),
        ];
      case EstadoTrabajo.pendiente:
        return [
          WidgetInfoPostulante(trabajo: trabajoActual, postulanteService: postulanteService),
          spacer,
          WidgetMensajeInformativo(
            icono: Icons.calendar_today_outlined,
            mensaje: 'Trabajo agendado.',
            color: trabajoActual.estado.colorTextoChip,
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
          WidgetInfoPostulante(trabajo: trabajoActual, postulanteService: postulanteService),
        ];
      case EstadoTrabajo.finalizado:
        return [
          WidgetGestionPago(
            trabajo: trabajoActual,
            postulanteService: postulanteService,
            trabajoService: trabajoService,
            storageService: storageService,
            adminId: widget.adminId, // <-- USA EL ID DEL WIDGET
          ),
          spacer,
          WidgetRevisionEvidencias(
            trabajo: trabajoActual,
            trabajoService: trabajoService,
            storageService: storageService,
          ),
        ];
      case EstadoTrabajo.cancelado:
        return [
          WidgetGestionPago(
            trabajo: trabajoActual,
            postulanteService: postulanteService,
            trabajoService: trabajoService,
            storageService: storageService,
            adminId: widget.adminId, // <-- USA EL ID DEL WIDGET
          ),
          spacer,
          WidgetRevisionEvidencias(
            trabajo: trabajoActual,
            trabajoService: trabajoService,
            storageService: storageService,
          ),
          spacer,
          WidgetInfoPostulante(trabajo: trabajoActual, postulanteService: postulanteService),
          spacer,
          WidgetMensajeInformativo(
            icono: Icons.cancel_rounded,
            mensaje: 'Trabajo cancelado.',
            color: trabajoActual.estado.colorTextoChip,
          ),
        ];
      case EstadoTrabajo.rechazado:
        return [
          WidgetRevisionEvidencias(
            trabajo: trabajoActual,
            trabajoService: trabajoService,
            storageService: storageService,
          ),
          spacer,
          WidgetMensajeInformativo(
            icono: Icons.thumb_down_rounded,
            mensaje:
                'Evidencias rechazadas: ${trabajoActual.motivoRechazo ?? "Sin motivo."}',
            color: trabajoActual.estado.colorTextoChip,
          ),
        ];
    }
  }
}