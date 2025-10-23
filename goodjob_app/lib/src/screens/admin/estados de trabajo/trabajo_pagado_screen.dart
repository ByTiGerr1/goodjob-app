import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/theme/app_colors.dart';

class AdminTrabajoPagadoScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const AdminTrabajoPagadoScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<AdminTrabajoPagadoScreen> createState() => _AdminTrabajoPagadoScreenState();
}

class _AdminTrabajoPagadoScreenState extends State<AdminTrabajoPagadoScreen> {
  final StorageService _storageService = StorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  Map<String, dynamic>? _usuarioData;

  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = AppColors.primary;
  static const Color successColor = AppColors.success;
  static const Color alertColor  = AppColors.alertColor;
  static const Color neutralColor = AppColors.neutralColor;

  @override
  void initState() {
    super.initState();
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
          // Obtener datos del usuario
          final usuarioDoc = await _firestore
              .collection('usuarios')
              .doc(usuarioId)
              .get();

          if (usuarioDoc.exists) {
            final userData = usuarioDoc.data();
            
            setState(() {
              _usuarioData = userData;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar usuario confirmado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del trabajador: $e'),
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

  // --- WIDGETS DE VISTA ---

  Widget _buildCompactData(IconData icon, String label, String value, {Color iconColor = primaryColor}) {
    return Container( 
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18), 
                const SizedBox(width: 4), 
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: neutralColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2), 
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTrabajo() {
    final titulo = widget.trabajo['titulo'] as String? ?? 'N/A';
    final descripcion = widget.trabajo['descripcion'] as String? ?? 'N/A';
    final empresa = widget.trabajo['empresa'] as String? ?? 'N/A';
    final precio = (widget.trabajo['precio'] as num?)?.toDouble() ?? 0.0;
    
    // Fechas del trabajo
    final fechaInicioTrabajo = (widget.trabajo['fechaInicioTrabajo'] as Timestamp?)?.toDate();
    final fechaFinTrabajo = (widget.trabajo['fechaFinTrabajo'] as Timestamp?)?.toDate();

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
                const Icon(Icons.work, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Información del Trabajo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // Título
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // Descripción
            Text(
              descripcion,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 8.0, 
              runSpacing: 12.0, 
              children: [
                _buildCompactData(Icons.business, 'Empresa', empresa, iconColor: primaryColor),
                _buildCompactData(Icons.attach_money, 'Precio Pagado', FormatUtils.formatCurrency(precio), iconColor: successColor),
                if (fechaInicioTrabajo != null)
                  _buildCompactData(Icons.calendar_today, 'Fecha Inicio', FormatUtils.formatDate(fechaInicioTrabajo), iconColor: primaryColor),
                if (fechaFinTrabajo != null)
                  _buildCompactData(Icons.event, 'Fecha Fin', FormatUtils.formatDate(fechaFinTrabajo), iconColor: primaryColor),
              ],
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
                  const Icon(Icons.person, color: primaryColor, size: 24),
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'N/A - Usuario no encontrado',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: neutralColor,
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
                const Icon(Icons.person, color: primaryColor, size: 24),
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
            
            Wrap(
              spacing: 8.0, 
              runSpacing: 12.0, 
              children: [
                _buildCompactData(Icons.badge, 'Nombre', nombreCompleto.isEmpty ? 'N/A' : nombreCompleto, iconColor: primaryColor),
                _buildCompactData(Icons.fingerprint, 'RUT', rut, iconColor: primaryColor),
                _buildCompactData(Icons.email, 'Email', email, iconColor: primaryColor),
                _buildCompactData(Icons.phone, 'Teléfono', telefono, iconColor: primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionComprobante() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.receipt_long, color: successColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Comprobante de Pago',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: successColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _storageService.mostrarEvidenciasPagos(widget.trabajoId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
                }

                if (snapshot.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Error al cargar comprobante: ${snapshot.error}', style: const TextStyle(color: alertColor))));
                }

                final evidencias = snapshot.data ?? [];
                final tieneEvidencia = evidencias.isNotEmpty;

                if (!tieneEvidencia) {
                  return const Column(
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No se encontró comprobante de pago',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: neutralColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final url = evidencias.first['url'] as String?;

                return Column(
                  children: [
                    if (url != null)
                      GestureDetector(
                        onTap: () {
                          // Mostrar imagen en tamaño completo
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppBar(
                                    title: const Text('Comprobante de Pago'),
                                    leading: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  Expanded(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(
                                              Icons.error_outline,
                                              size: 50,
                                              color: alertColor,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: successColor, width: 3),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
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
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: successColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Pago realizado exitosamente',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: successColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final precio = (widget.trabajo['precio'] as num?)?.toDouble() ?? 0.0;
    
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: successColor,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16.0),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'TRABAJO PAGADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        FormatUtils.formatCurrency(precio),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      color: successColor,
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 60.0),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Colors.white38,
                        ),
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
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green[200]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[900]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Este trabajo fue completado y el pago fue realizado exitosamente.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Secciones
                      _buildSeccionTrabajo(),
                      _buildSeccionUsuario(),
                      _buildSeccionComprobante(),
                      
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
