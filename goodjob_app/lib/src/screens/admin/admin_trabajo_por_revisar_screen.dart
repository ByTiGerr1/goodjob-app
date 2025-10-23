import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/models/trabajo.dart';

class AdminTrabajoPorRevisarScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;
  
  const AdminTrabajoPorRevisarScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<AdminTrabajoPorRevisarScreen> createState() => _AdminTrabajoPorRevisarScreenState();
}

class _AdminTrabajoPorRevisarScreenState extends State<AdminTrabajoPorRevisarScreen> {
  final StorageService _storageService = StorageService();
  final TrabajoService _trabajoService = TrabajoService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  Map<String, dynamic>? _usuarioData;

  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = Color(0xFF7B0997);
  static const Color secondaryColor = Color(0xFFE91E63);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color alertColor = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _cargarUsuarioConfirmado();
  }

  // --- LÓGICA DE CARGA DE DATOS ---

  Future<void> _cargarUsuarioConfirmado() async {
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
          // Obtener datos del usuario
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
    }
  }

  // --- UTILIDADES ---

  Map<String, dynamic>? _safeMapCast(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  DateTime? _getTrabajoStartDateTime() {
    final newStartTs = widget.trabajo['fechaInicioTrabajo'] as Timestamp?;
    if (newStartTs != null) return newStartTs.toDate();
    return DateTime.now();
  }

  DateTime? _getTrabajoEndDateTime() {
    final newEndTs = widget.trabajo['fechaFinTrabajo'] as Timestamp?;
    if (newEndTs != null) return newEndTs.toDate();
    return DateTime.now();
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'N/A';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
      ubicacion['pais'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes.isEmpty ? 'N/A' : partes;
  }

  String _formatHora(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/A';
    return FormatUtils.formatDate(fecha);
  }

  // --- ACCIONES ---

  Future<void> _aceptarTrabajo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aceptar Evidencias'),
        content: const Text(
          '¿Está seguro de que desea aceptar las evidencias de este trabajo?\n'
          'Se procederá a mostrar los datos de pago si lo hace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: successColor),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await _trabajoService.actualizarEstado(
          widget.trabajoId,
          EstadoTrabajo.porPagar,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El trabajo ha sido aceptado, se puede proceder al pago.'),
              backgroundColor: successColor,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al aceptar trabajo: $e'),
              backgroundColor: alertColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _rechazarTrabajo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Evidencias'),
        content: const Text(
          '¿Está seguro de que desea rechazar las evidencias de este trabajo?\n'
          'Esta acción rechazará el trabajo completo, esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: alertColor),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await _trabajoService.actualizarEstado(
          widget.trabajoId,
          EstadoTrabajo.rechazado,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ha rechazado este trabajo.'),
              backgroundColor: alertColor,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al rechazar trabajo: $e'),
              backgroundColor: alertColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- WIDGETS DE VISTA ---

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
    final fechaInicio = _getTrabajoStartDateTime();
    final fechaFin = _getTrabajoEndDateTime();
    final ubicacion = _safeMapCast(widget.trabajo['ubicacion']);
    final precio = (widget.trabajo['precio'] as num?)?.toDouble() ?? 0.0;
    final requiereUniforme = widget.trabajo['requiereUniforme'] as bool? ?? false;
    final implementosUniforme = (widget.trabajo['implementosUniforme'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final instrucciones = widget.trabajo['instrucciones'] as String? ?? 'N/A';

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
              Icons.title,
              'Título',
              widget.trabajo['titulo'] as String? ?? 'N/A',
            ),
            _buildDetalleItem(
              Icons.business,
              'Empresa',
              widget.trabajo['empresa'] as String? ?? 'N/A',
            ),
            _buildDetalleItem(
              Icons.description,
              'Descripción',
              widget.trabajo['descripcion'] as String? ?? 'N/A',
            ),
            _buildDetalleItem(
              Icons.location_on,
              'Ubicación',
              _formatearUbicacion(ubicacion),
            ),
            _buildDetalleItem(
              Icons.calendar_today,
              'Fecha de Inicio',
              _formatFecha(fechaInicio),
            ),
            _buildDetalleItem(
              Icons.calendar_today,
              'Fecha de Fin',
              _formatFecha(fechaFin),
            ),
            _buildDetalleItem(
              Icons.access_time,
              'Horario',
              '${_formatHora(fechaInicio)} - ${_formatHora(fechaFin)} hrs',
            ),
            _buildDetalleItem(
              Icons.attach_money,
              'Precio',
              FormatUtils.formatCurrency(precio),
            ),
            const SizedBox(height: 12),
            const Text(
              'Requisitos e Instrucciones:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            if (requiereUniforme) ...[
              Row(
                children: [
                  const Icon(Icons.checkroom, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Requiere uniforme:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (implementosUniforme.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    implementosUniforme.join(', '),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.info_outline, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Instrucciones adicionales:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                instrucciones,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildSeccionEvidencias() {
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
                const Icon(Icons.photo_library, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Evidencias Fotográficas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _storageService.mostrarEvidencias(widget.trabajoId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Error al cargar evidencias: ${snapshot.error}',
                        style: const TextStyle(color: alertColor),
                      ),
                    ),
                  );
                }

                final evidencias = snapshot.data ?? [];

                if (evidencias.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'No se encontraron evidencias fotográficas',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: evidencias.map((evidencia) {
                    final etapa = evidencia['etapa'] as String? ?? 'N/A';
                    final url = evidencia['url'] as String?;
                    final gps = _safeMapCast(evidencia['gps']);
                    final lat = gps?['lat']?.toString() ?? 'N/A';
                    final lng = gps?['lng']?.toString() ?? 'N/A';
                    final capturadaEn = evidencia['capturadaEn'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Etapa: ${etapa.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (url != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(
                                          Icons.error_outline,
                                          size: 50,
                                          color: alertColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.black54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'GPS: $lat, $lng',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                            if (capturadaEn != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Capturada: ${_formatFecha(capturadaEn.toDate())} ${_formatHora(capturadaEn.toDate())}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _rechazarTrabajo,
                icon: const Icon(Icons.close),
                label: const Text(
                  'RECHAZAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: alertColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _aceptarTrabajo,
                icon: const Icon(Icons.check),
                label: const Text(
                  'ACEPTAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: primaryColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    'Trabajo por Revisar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor,
                          secondaryColor,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.rate_review,
                        size: 80,
                        color: Colors.white54,
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
                      // Banner informativo
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Revise cuidadosamente las evidencias y datos del usuario antes de tomar una decisión.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Secciones
                      _buildSeccionTrabajo(),
                      _buildSeccionUsuario(),
                      _buildSeccionEvidencias(),
                      
                      // Espacio para los botones fijos
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Botones de acción fijos en la parte inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBotonesAccion(),
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