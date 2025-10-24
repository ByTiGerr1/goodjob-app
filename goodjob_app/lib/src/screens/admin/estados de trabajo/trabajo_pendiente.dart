import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/theme/app_colors.dart';
// Asumiendo que esta es la pantalla de redireccionamiento para edición o gestión
import '../admin_trabajo_router.dart';

class TrabajoPendiente extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const TrabajoPendiente({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<TrabajoPendiente> createState() => _TrabajoPendienteState();
}

class _TrabajoPendienteState extends State<TrabajoPendiente> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  Map<String, dynamic>? _usuarioData;
  late EstadoTrabajo _estadoTrabajo;

  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = AppColors.primary;
  static const Color alertColor = AppColors.alertColor;

  // Obtenemos los colores semánticos del modelo
  late Color _estadoBackgroundColor;
  late Color _estadoTextColor;

  @override
  void initState() {
    super.initState();
    // Este estado es 'pendiente' (el trabajador ya confirmó, espera la fecha de inicio)
    _estadoTrabajo = EstadoTrabajo.pendiente;
    _estadoBackgroundColor = _estadoTrabajo.colorChip;
    _estadoTextColor = _estadoTrabajo.colorTextoChip;
    _cargarUsuarioConfirmado();
  }

  // --- LÓGICA DE CARGA DE DATOS ---

  Future<void> _cargarUsuarioConfirmado() async {
    setState(() => _isLoading = true);
    try {
      // LÓGICA CORRECTA PARA ESTA PANTALLA:
      // Si el trabajo está 'pendiente', el postulante ya está 'confirmado'.
      final postulacionesSnapshot = await _firestore
          .collection('trabajos')
          .doc(widget.trabajoId)
          .collection('postulaciones')
          .where('estado', isEqualTo: 'confirmado') // <-- ESTO ES CORRECTO
          .limit(1)
          .get();

      if (postulacionesSnapshot.docs.isNotEmpty) {
        final postulacionData = postulacionesSnapshot.docs.first.data();
        final usuarioId = postulacionData['usuarioId'] as String?;

        if (usuarioId != null) {
          final usuarioDoc = await _firestore
              .collection('usuarios')
              .doc(usuarioId)
              .get();

          if (usuarioDoc.exists) {
            setState(() {
              _usuarioData = usuarioDoc.data();
            });
          }
        }
      } else {
         debugPrint('No se encontró ninguna postulación con estado "confirmado".');
      }
    } catch (e) {
      debugPrint('Error al cargar usuario confirmado: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UTILIDADES DE FORMATO ---

  String _formatDate(DateTime? fecha) =>
      fecha != null ? FormatUtils.formatDate(fecha) : 'N/A';
  String _formatCurrency(double? precio) =>
      precio != null ? FormatUtils.formatCurrency(precio) : 'N/A';

  // FUNCIÓN LOCAL DE HORA (Añadida)
  String _formatTimeOfDay(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'N/A';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes.isEmpty ? 'N/A' : partes;
  }

  // --- WIDGETS DE DATOS COMPACTOS (REUTILIZADOS) ---

  Widget _buildDetalleItem(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: primaryColor, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black54,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      minLeadingWidth: 20,
    );
  }

  // --- WIDGETS DE SECCIONES ---

  Widget _buildSeccionTrabajo() {
    final fechaInicio = (widget.trabajo['fechaInicioTrabajo'] as Timestamp?)
        ?.toDate();
    final fechaFin = (widget.trabajo['fechaFinTrabajo'] as Timestamp?)
        ?.toDate();
    final ubicacion = widget.trabajo['ubicacion'] as Map<String, dynamic>?;
    final precio = (widget.trabajo['precio'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.work, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Detalles del Trabajo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetalleItem(
              Icons.calendar_today,
              'Fecha de Inicio',
              fechaInicio != null
                  ? '${_formatDate(fechaInicio)} a las ${_formatTimeOfDay(fechaInicio)}'
                  : 'N/A',
            ),
            _buildDetalleItem(
              Icons.event,
              'Fecha de Fin',
              fechaFin != null
                  ? '${_formatDate(fechaFin)} a las ${_formatTimeOfDay(fechaFin)}'
                  : 'N/A',
            ),
            _buildDetalleItem(
              Icons.location_on,
              'Ubicación',
              _formatearUbicacion(ubicacion),
            ),
            _buildDetalleItem(
              Icons.attach_money,
              'Precio',
              _formatCurrency(precio),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET SECCIÓN USUARIO (REFACTORIZADO AL NUEVO ESTILO) ---
  Widget _buildSeccionUsuario() {
    // --- 1. Caso de Carga/No Asignado ---
    if (_usuarioData == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_search, color: primaryColor, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Trabajador Confirmado',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor),
                  ),
                ],
              ),
              const Divider(height: 20),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _isLoading
                      ? CircularProgressIndicator(color: primaryColor)
                      : const Text(
                          'Cargando datos del trabajador confirmado...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.black54),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- 2. Caso de Trabajador Cargado (_usuarioData != null) ---
    final nombreCompleto =
        '${_usuarioData!['nombre'] ?? ''} ${_usuarioData!['apellido'] ?? ''}'
            .trim();
    final email = _usuarioData!['email'] as String? ?? 'N/A';
    final telefono = _usuarioData!['telefono'] as String? ?? 'N/A';
    final rut = _usuarioData!['rut'] as String? ?? 'N/A';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_pin_circle, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Trabajador Confirmado',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _estadoBackgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _estadoTrabajo.texto, // Usamos .texto
                    style: TextStyle(
                      color: _estadoTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              ],
            ),
            const Divider(height: 20),
            _buildDetalleItem(
              Icons.badge,
              'Nombre Completo',
              nombreCompleto.isEmpty ? 'N/A' : nombreCompleto,
            ),
            _buildDetalleItem(
              Icons.fingerprint,
              'RUT',
              rut,
            ),
            _buildDetalleItem(
              Icons.phone,
              'Teléfono',
              telefono,
            ),
            _buildDetalleItem(
              Icons.email,
              'Email',
              email,
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final trabajoTitulo =
        widget.trabajo['titulo'] as String? ?? 'Trabajo Pendiente';

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Text(
                    trabajoTitulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      border: Border(
                          bottom: BorderSide(color: _estadoTextColor, width: 3)),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.schedule, // Ícono de reloj para 'Pendiente'
                        size: 80,
                        color: _estadoTextColor,
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner informativo (TEXTO CORREGIDO)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _estadoBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _estadoTextColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline, color: _estadoTextColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '¡Trabajador confirmado! Este trabajo está programado y listo para comenzar en la fecha indicada.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _estadoTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Secciones
                      _buildSeccionTrabajo(),
                      _buildSeccionUsuario(), // Widget unificado

                      const SizedBox(height: 24),

                      // Botón de gestión
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => getAdminTrabajoView(
                                        trabajoId: widget.trabajoId,
                                        trabajoData: widget.trabajo)));
                          },
                          icon: const Icon(Icons.edit_calendar,
                              size: 20, color: primaryColor),
                          label: const Text('Gestionar/Editar Trabajo',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

