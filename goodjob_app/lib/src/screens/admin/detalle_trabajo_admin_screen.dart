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

              // --- 2. ⚠️ MEJORA UI: Contenedor de Información Estática ---
              _buildInfoContainer(context, trabajo),

              const SizedBox(height: 32), // Separador visual generoso

              // --- 3. Contenido Dinámico (Acciones) ---
              Text(
                'Acciones Administrativas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              
              _buildDynamicContent(context, trabajo),
              
              const SizedBox(height: 20), // Espacio al final
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️ NUEVO WIDGET: Agrupa la info estática en un contenedor
  Widget _buildInfoContainer(BuildContext context, Trabajo trabajo) {
    final textTheme = Theme.of(context).textTheme;
    // Color sutil que se adapta a light/dark mode
    final containerColor = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Descripción ---
          Text(
            'Descripción del Servicio',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            trabajo.descripcion,
            style: textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
          ),
          
          const Divider(height: 32), // Separador interno

          // --- Detalles ---
          Text(
            'Detalles de Ejecución',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: trabajo.ubicacion['direccion'] ?? 'Ubicación no especificada',
          ),
          
          // ⚠️ BUG FIX: Corregido el formato de fecha y hora
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text: 'Inicia: ${FormatUtils.formatDate(trabajo.fechaInicioTrabajo)} '
                  'a las ${FormatUtils.formatDate(trabajo.fechaInicioTrabajo)}',
          ),
          _InfoRow(
            icon: Icons.flag_outlined,
            text: 'Finaliza: ${FormatUtils.formatDate(trabajo.fechaFinTrabajo)} '
                  'a las ${FormatUtils.formatDate(trabajo.fechaFinTrabajo)}',
          ),

          // --- Precio (Contextual) ---
          // ⚠️ MEJORA UX: El precio es solo un detalle más,
          // a menos que el estado sea cancelado/rechazado.
          if (trabajo.estado != EstadoTrabajo.cancelado && 
              trabajo.estado != EstadoTrabajo.rechazado) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.attach_money_outlined, // Icono más sutil
              text: FormatUtils.formatCurrency(trabajo.precio),
            ),
          ]
        ],
      ),
    );
  }

  /// Decide qué widgets específicos mostrar según el estado del trabajo
  Widget _buildDynamicContent(BuildContext context, Trabajo trabajo) {
    // ... (Esta función no cambia, su lógica es interna a los widgets hijos)
    switch (trabajo.estado) {
      case EstadoTrabajo.activo:
        return WidgetListaPostulantes(
          trabajo: trabajo,
          postulacionService: postulacionService,
          postulanteService: postulanteService,
        );

      case EstadoTrabajo.porRevisar:
        return WidgetRevisionEvidencias(
          trabajo: trabajo,
          trabajoService: trabajoService,
          storageService: storageService,
        );

      case EstadoTrabajo.porPagar:
        return WidgetGestionPago(
          trabajo: trabajo,
          postulanteService: postulanteService,
          trabajoService: trabajoService,
          storageService: storageService,
          adminId: adminId, 
        );

      case EstadoTrabajo.porConfirmar:
        return WidgetMensajeInformativo(
          icono: Icons.hourglass_top_rounded,
          mensaje: 'Esperando que el postulante acepte la oferta.',
          color: trabajo.estado.colorTextoChip,
        );

      case EstadoTrabajo.pendiente:
        if (trabajo.trabajadorAsignadoId == null) {
          return const WidgetMensajeInformativo(
            icono: Icons.error,
            mensaje: 'Error: Estado pendiente sin postulante asignado.',
          );
        }
        return WidgetInfoPostulante(
          trabajo: trabajo,
          postulanteService: postulanteService,
          mensaje: 'El trabajo está agendado y listo para comenzar.',
        );

      case EstadoTrabajo.enCurso:
        return WidgetMensajeInformativo(
          icono: Icons.directions_run_rounded,
          mensaje: 'El trabajo está actualmente en curso.',
          color: trabajo.estado.colorTextoChip,
        );

      case EstadoTrabajo.finalizado:
        return WidgetMensajeInformativo(
          icono: Icons.check_circle_rounded,
          mensaje: 'Este trabajo fue completado y pagado exitosamente.',
          color: trabajo.estado.colorTextoChip,
        );

      case EstadoTrabajo.cancelado:
        return WidgetMensajeInformativo(
          icono: Icons.cancel_rounded,
          mensaje: 'Este trabajo fue cancelado.',
          color: trabajo.estado.colorTextoChip,
        );

      case EstadoTrabajo.rechazado:
        return WidgetMensajeInformativo(
          icono: Icons.thumb_down_rounded,
          mensaje:
              'Evidencias rechazadas: ${trabajo.motivoRechazo ?? "Sin motivo."}',
          color: trabajo.estado.colorTextoChip,
        );
    }
  }
}

/// Widget helper interno (Diseño de Lista Plana)
/// No necesita cambios
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _InfoRow({required this.icon, required this.text});

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