import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/theme/app_colors.dart';
// Asumiendo que esta es la pantalla de redireccionamiento para edición o gestión
import '../admin_trabajo_router.dart';

class TrabajoPorConfirmarScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const TrabajoPorConfirmarScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<TrabajoPorConfirmarScreen> createState() =>
      _TrabajoPorConfirmarScreenState();
}

class _TrabajoPorConfirmarScreenState extends State<TrabajoPorConfirmarScreen> {
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
    _estadoTrabajo = EstadoTrabajo.porConfirmar;
    _estadoBackgroundColor = _estadoTrabajo.colorChip;
    _estadoTextColor = _estadoTrabajo.colorTextoChip;
    _cargarUsuarioConfirmado();
  }

  // --- LÓGICA DE CARGA DE DATOS (CORREGIDA) ---

  Future<void> _cargarUsuarioConfirmado() async {
    setState(() => _isLoading = true);
    try {
      // CORRECCIÓN: Buscamos la postulación 'aceptada' (la que está pendiente de confirmar)
      // en lugar de 'confirmada'.
      final postulacionesSnapshot = await _firestore
          .collection('trabajos')
          .doc(widget.trabajoId)
          .collection('postulaciones')
          .where(
            'estado',
            isEqualTo: 'aceptado', // <-- ESTA ES LA CORRECCIÓN CLAVE
          )
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
         debugPrint('No se encontró ninguna postulación con estado "aceptado".');
      }
    } catch (e) {
      debugPrint('Error al cargar usuario aceptado: $e');
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

  Widget _buildDataChip({
    required IconData icon,
    required String title,
    required String value,
    Color iconColor = Colors.black54,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.work,
                  color: primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Datos del Trabajo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(
              height: 24,
              color: primaryColor,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildDataChip(
                  icon: Icons.calendar_month,
                  title: 'Fecha Inicio',
                  value: _formatDate(fechaInicio),
                ),
                _buildDataChip(
                  icon: Icons.schedule,
                  title: 'Horario',
                  value: fechaInicio != null && fechaFin != null
                      ? '${_formatTimeOfDay(fechaInicio)} - ${_formatTimeOfDay(fechaFin)} hrs'
                      : 'N/A',
                ),
                _buildDataChip(
                  icon: Icons.attach_money,
                  title: 'Monto Total',
                  value: _formatCurrency(precio),
                  iconColor: _estadoTextColor,
                ),
                _buildDataChip(
                  icon: Icons.location_on,
                  title: 'Ubicación',
                  value: _formatearUbicacion(ubicacion),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET SECCIÓN USUARIO (CORREGIDO Y UNIFICADO) ---
  Widget _buildSeccionUsuario() {
    // --- 1. Caso de Carga/No Asignado ---
    if (_usuarioData == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_search,
                    color: primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Trabajador Asignado',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const Divider(
                height: 24,
                color: primaryColor,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _isLoading
                      ? CircularProgressIndicator(color: primaryColor)
                      : const Text(
                          'Buscando trabajador aceptado... Si este mensaje persiste, es posible que no haya un trabajador en estado "aceptado" para este trabajo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54,
                          ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_pin_circle,
                  color: primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Trabajador Asignado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _estadoBackgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    // CORRECCIÓN: Usamos .texto en lugar de .nombre
                    _estadoTrabajo.texto, 
                    style: TextStyle(
                      color: _estadoTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              ],
            ),
            const Divider(
              height: 24,
              color: primaryColor,
            ),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, size: 40, color: primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nombreCompleto.isEmpty ? 'Trabajador Anónimo' : nombreCompleto,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Esperando confirmación',
                    style: TextStyle(
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildDataChip(
                  icon: Icons.fingerprint,
                  title: 'RUT',
                  value: rut,
                  iconColor: primaryColor,
                ),
                _buildDataChip(
                  icon: Icons.phone,
                  title: 'Teléfono',
                  value: telefono,
                  iconColor: primaryColor,
                ),
                _buildDataChip(
                  icon: Icons.email,
                  title: 'Email',
                  value: email,
                ),
              ],
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
        widget.trabajo['titulo'] as String? ?? 'Trabajo Por Confirmar';

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
                        bottom: BorderSide(color: _estadoTextColor, width: 3),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.hourglass_empty,
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _estadoBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _estadoTextColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: _estadoTextColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Confirmación de asistencia pendiente. El trabajador debe aceptar o rechazar el trabajo asignado.',
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
                      
                      _buildSeccionTrabajo(),
                      _buildSeccionUsuario(), // Widget unificado
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