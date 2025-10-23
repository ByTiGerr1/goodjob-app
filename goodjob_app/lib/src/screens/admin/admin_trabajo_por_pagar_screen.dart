import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/services/encryption_service.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:image_picker/image_picker.dart';

class AdminTrabajoPorPagarScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const AdminTrabajoPorPagarScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<AdminTrabajoPorPagarScreen> createState() => _AdminTrabajoPorPagarScreenState();
}

class _AdminTrabajoPorPagarScreenState extends State<AdminTrabajoPorPagarScreen> {
  final StorageService _storageService = StorageService();
  final TrabajoService _trabajoService = TrabajoService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isUploading = false;
  Map<String, dynamic>? _usuarioData;
  String? _banco;
  String? _numeroCuenta;
  String? _tipoCuenta;

  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = Color(0xFF7B0997);
  static const Color secondaryColor = Color(0xFFE91E63);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color alertColor = Color(0xFFD32F2F);
  static const Color disabledColor = Color(0xFF9E9E9E);

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
            final userData = usuarioDoc.data();
            
            // Desencriptar datos bancarios
            String? banco;
            String? numeroCuenta;
            String? tipoCuenta;

            try {
              final bancoEncriptado = userData?['banco'] as String?;
              final numeroCuentaEncriptado = userData?['numeroCuenta'] as String?;
              final tipoCuentaEncriptado = userData?['tipoCuenta'] as String?;

              if (bancoEncriptado != null && bancoEncriptado.isNotEmpty) {
                banco = await _encryptionService.decrypt(bancoEncriptado);
              }
              if (numeroCuentaEncriptado != null && numeroCuentaEncriptado.isNotEmpty) {
                numeroCuenta = await _encryptionService.decrypt(numeroCuentaEncriptado);
              }
              if (tipoCuentaEncriptado != null && tipoCuentaEncriptado.isNotEmpty) {
                tipoCuenta = await _encryptionService.decrypt(tipoCuentaEncriptado);
              }
            } catch (e) {
              debugPrint('Error al desencriptar datos bancarios: $e');
            }

            setState(() {
              _usuarioData = userData;
              _banco = banco;
              _numeroCuenta = numeroCuenta;
              _tipoCuenta = tipoCuenta;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar usuario confirmado: $e');
    }
  }

  // --- ACCIONES ---

  Future<void> _seleccionarYSubirComprobante() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final imageFile = File(image.path);
      final url = await _storageService.subirEvidenciaPago(
        trabajoId: widget.trabajoId,
        imagen: imageFile,
        usuarioId: currentUser.uid,
      );

      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comprobante de pago subido exitosamente'),
            backgroundColor: successColor,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al subir el comprobante'),
            backgroundColor: alertColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: alertColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _confirmarPago() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pago'),
        content: const Text(
          '¿Desea finalizar este trabajo?\n\n'
          'Se enviará la evidencia del pago al trabajador y el trabajo será marcado como finalizado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: successColor),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await _trabajoService.actualizarEstado(
          widget.trabajoId,
          EstadoTrabajo.finalizado,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago confirmado. Trabajo finalizado exitosamente.'),
              backgroundColor: successColor,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al confirmar pago: $e'),
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

  Widget _buildDetalleItem(IconData icon, String title, String value, {bool isSecret = false}) {
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
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: isSecret ? 1.2 : 0,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      minLeadingWidth: 20,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionDatosBancarios() {
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
                const Icon(Icons.account_balance, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Datos Bancarios',
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
              Icons.attach_money,
              'Monto a Pagar',
              FormatUtils.formatCurrency(precio),
            ),
            const SizedBox(height: 8),
            if (_banco != null && _numeroCuenta != null && _tipoCuenta != null) ...[
              _buildDetalleItem(
                Icons.business,
                'Banco',
                _banco ?? 'N/A',
              ),
              _buildDetalleItem(
                Icons.credit_card,
                'Número de Cuenta',
                _numeroCuenta ?? 'N/A',
                isSecret: true,
              ),
              _buildDetalleItem(
                Icons.account_balance_wallet,
                'Tipo de Cuenta',
                _tipoCuenta ?? 'N/A',
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'Datos bancarios no disponibles',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Comprobante de Pago',
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
              stream: _storageService.mostrarEvidenciasPagos(widget.trabajoId),
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
                        'Error al cargar comprobante: ${snapshot.error}',
                        style: const TextStyle(color: alertColor),
                      ),
                    ),
                  );
                }

                final evidencias = snapshot.data ?? [];

                if (evidencias.isEmpty) {
                  return Column(
                    children: [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No se ha subido ningún comprobante de pago',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _seleccionarYSubirComprobante,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_isUploading ? 'Subiendo...' : 'Subir Comprobante'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final evidencia = evidencias.first;
                final url = evidencia['url'] as String?;

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
                        child: ClipRRect(
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
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: successColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Comprobante subido',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isUploading ? null : _seleccionarYSubirComprobante,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isUploading ? 'Subiendo...' : 'Reemplazar Comprobante'),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                      ),
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

  Widget _buildBotonConfirmarPago() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _storageService.mostrarEvidenciasPagos(widget.trabajoId),
      builder: (context, snapshot) {
        final tieneEvidencia = snapshot.hasData && (snapshot.data?.isNotEmpty ?? false);

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!tieneEvidencia)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Se debe subir una evidencia de pago antes de confirmar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: tieneEvidencia && !_isLoading ? _confirmarPago : null,
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'CONFIRMAR PAGO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tieneEvidencia ? successColor : disabledColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: disabledColor,
                      disabledForegroundColor: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                    'Trabajo por Pagar',
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
                        Icons.payment,
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
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber[900]),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Revise los datos bancarios y suba el comprobante de pago antes de confirmar.',
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
                      _buildSeccionUsuario(),
                      _buildSeccionDatosBancarios(),
                      _buildSeccionComprobante(),
                      
                      // Espacio para el botón fijo
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Botón de confirmación fijo en la parte inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBotonConfirmarPago(),
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