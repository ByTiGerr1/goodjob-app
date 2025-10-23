import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/screens/admin/admin_trabajo_router.dart';
import 'package:goodjob_app/src/screens/trabajo_en_curso_screen.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/theme/app_colors.dart';
// Asumiendo que esta es la pantalla de redireccionamiento para edición o gestión


class TrabajoEnCursoScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const TrabajoEnCursoScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<TrabajoEnCursoScreen> createState() => _TrabajoEnCursoScreenState();
}

class _TrabajoEnCursoScreenState extends State<TrabajoEnCursoScreen> {
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
    // CAMBIO: Ahora manejamos el estado 'enCurso'
    _estadoTrabajo = EstadoTrabajo.enCurso; 
    _estadoBackgroundColor = _estadoTrabajo.colorChip;
    _estadoTextColor = _estadoTrabajo.colorTextoChip;
    _cargarUsuarioConfirmado();
  }

  // --- LÓGICA DE CARGA DE DATOS ---

  Future<void> _cargarUsuarioConfirmado() async {
    setState(() => _isLoading = true);
    try {
      // Buscar la postulación con estado "confirmado"
      final postulacionesSnapshot = await _firestore
          .collection('trabajos')
          .doc(widget.trabajoId)
          .collection('postulaciones')
          .where('estado', isEqualTo: 'confirmado') 
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

  String _formatDate(DateTime? fecha) => fecha != null ? FormatUtils.formatDate(fecha) : 'N/A';
  String _formatCurrency(double? precio) => precio != null ? FormatUtils.formatCurrency(precio) : 'N/A';
  
  // FUNCIÓN LOCAL PARA FORMATO DE HORA (reutilizando la lógica de la pantalla anterior)
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

  // --- WIDGETS DE SECCIONES ---

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

  Widget _buildSeccionTrabajo() {
    final fechaInicio = (widget.trabajo['fechaInicioTrabajo'] as Timestamp?)?.toDate();
    final fechaFin = (widget.trabajo['fechaFinTrabajo'] as Timestamp?)?.toDate();
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
              Icons.date_range,
              'Fecha de Inicio',
              _formatDate(fechaInicio),
            ),
            _buildDetalleItem(
              Icons.date_range,
              'Fecha de Fin',
              _formatDate(fechaFin),
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
      )
    );
  }

  Widget _buildSeccionUsuario() {
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
                  const Icon(Icons.person, color: primaryColor, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Datos del Usuario',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'N/A - Usuario no encontrado',
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

    final nombre = _usuarioData!['nombre'] as String? ?? 'N/A';
    final apellido = _usuarioData!['apellido'] as String? ?? '';
    final nombreCompleto = '$nombre $apellido'.trim();
    final email = _usuarioData!['email'] as String? ?? 'N/A';
    final telefono = _usuarioData!['telefono'] as String? ?? 'N/A';
    final rut = _usuarioData!['rut'] as String? ?? 'N/A';
    final region = _usuarioData!['region'] as String? ?? 'N/A';
    final calle = _usuarioData!['calle'] as String? ?? '';
    final numero = _usuarioData!['numero'] as String? ?? '';
    final direccion = '$calle $numero'.trim().isEmpty ? 'N/A' : '$calle $numero';

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
                const Icon(Icons.person, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Datos del Trabajador',
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
              Icons.badge,
              'Nombre',
              nombreCompleto.isEmpty ? 'N/A' : nombreCompleto,
            ),
            _buildDetalleItem(
              Icons.fingerprint,
              'RUT',
              rut,
            ),
            _buildDetalleItem(
              Icons.email,
              'Email',
              email,
            ),
            _buildDetalleItem(
              Icons.phone,
              'Teléfono',
              telefono,
            ),
            _buildDetalleItem(
              Icons.location_city,
              'Región',
              region,
            ),
            _buildDetalleItem(
              Icons.home,
              'Dirección',
              direccion,
            ),
          ],
        ),
      ),
    );
  }
  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    // Título del trabajo para el FlexibleSpaceBar
    final trabajoTitulo = widget.trabajo['titulo'] as String? ?? 'Trabajo En Curso';

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: primaryColor, // Usamos primaryColor como fondo principal
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Text(
                    trabajoTitulo,
                    style: const TextStyle(
                      color: Colors.white, // Texto blanco sobre primaryColor
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      // Borde sutil del color de estado como señal
                      border: Border(bottom: BorderSide(color: _estadoTextColor, width: 3)), 
                    ),
                    child: Center(
                      child: Icon(
                        Icons.access_time_filled, // Ícono de proceso activo
                        size: 80,
                        color: _estadoTextColor, // Usamos el color de estado (Azul) para el ícono principal
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
                      // Banner informativo de EN CURSO (Único lugar donde domina el color de estado)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _estadoBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _estadoTextColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.directions_run, color: _estadoTextColor), // Ícono de actividad
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Trabajo en progreso. El trabajador está actualmente realizando la tarea asignada.',
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
                      _buildSeccionUsuario(),

                      const SizedBox(height: 24), // Espacio final
                      
                      // Opción de gestión o reasignación (Botón de acción secundaria)
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            // Asumimos que getAdminTrabajoView permite la edición
                             Navigator.push(context, MaterialPageRoute(builder: (_) => getAdminTrabajoView(trabajoId: widget.trabajoId, trabajoData: widget.trabajo)));
                          },
                          icon: const Icon(Icons.edit_calendar, size: 20, color: primaryColor),
                          label: const Text('Gestionar/Editar Trabajo', style: TextStyle(fontWeight: FontWeight.bold)),
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
              color: Colors.black54,
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
