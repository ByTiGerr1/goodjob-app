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

class TrabajoPorPagarScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const TrabajoPorPagarScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<TrabajoPorPagarScreen> createState() => _TrabajoPorPagarScreenState();
}

class _TrabajoPorPagarScreenState extends State<TrabajoPorPagarScreen> {
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
  static const Color securityColor = Color(0xFF00796B); // Color para datos sensibles/bancarios
  static const Color neutralColor = Colors.black54;

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

  // --- ACCIONES (Manteniendo la lógica sin cambios) ---

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

  // --- WIDGETS DE VISTA MEJORADOS (Compactación visual) ---

  // UX: Widget de datos compacto para usarse con Wrap
  Widget _buildCompactData(IconData icon, String label, String value, {Color iconColor = primaryColor, bool isSecret = false}) {
    // Se elimina el ancho fijo (width: 150) para permitir que el texto fluya y se ajuste al Wrap
    return Container( 
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      // Usamos ConstrainedBox para asegurar que el elemento tome al menos el 45% del ancho de la pantalla
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: isSecret ? 1.5 : 0, // Énfasis en datos sensibles
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis, // Elipsis si el texto es excesivamente largo
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionUsuario() {
    if (_usuarioData == null) {
      // Usar el patrón de Card para consistencia visual
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
                      fontSize: 16,
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
            
            // UX: Compact Data Chips
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

  Widget _buildSeccionDatosBancarios() {
    final precio = (widget.trabajo['precio'] as num?)?.toDouble() ?? 0.0;
    
    // UX: Usar Card y Color de Seguridad para esta sección crítica
    return Card(
      elevation: 4, // Mayor elevación para distinguirla
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, color: securityColor, size: 28), // Ícono de seguridad
                const SizedBox(width: 8),
                const Text(
                  'Datos Bancarios para Pago',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: securityColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.black12),
            
            // ELIMINADO: Contenedor de Monto a Pagar con énfasis
            
            if (_banco != null && _numeroCuenta != null && _tipoCuenta != null) ...[
              Wrap(
                spacing: 8.0, 
                runSpacing: 12.0, 
                children: [
                  // Monto a Pagar integrado como un CompactData para coherencia
                  _buildCompactData(
                    Icons.attach_money,
                    'Monto Total a Pagar',
                    FormatUtils.formatCurrency(precio),
                    iconColor: securityColor,
                  ),
                  _buildCompactData(
                    Icons.business,
                    'Banco',
                    _banco ?? 'N/A',
                    iconColor: securityColor,
                  ),
                  _buildCompactData(
                    Icons.credit_card,
                    'Número de Cuenta',
                    _numeroCuenta ?? 'N/A',
                    isSecret: true,
                    iconColor: securityColor,
                  ),
                  _buildCompactData(
                    Icons.account_balance_wallet,
                    'Tipo de Cuenta',
                    _tipoCuenta ?? 'N/A',
                    iconColor: securityColor,
                  ),
                ],
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'Datos bancarios no disponibles o incompletos',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: neutralColor,
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
          crossAxisAlignment: CrossAxisAlignment.center, // Centrar acciones
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.receipt_long, color: primaryColor, size: 24),
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
                  return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
                }

                if (snapshot.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Error al cargar comprobante: ${snapshot.error}', style: const TextStyle(color: alertColor))));
                }

                final evidencias = snapshot.data ?? [];
                final tieneEvidencia = evidencias.isNotEmpty;

                if (!tieneEvidencia) {
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
                              color: neutralColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
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
                              : const Icon(Icons.cloud_upload_rounded),
                          label: Text(_isUploading ? 'Subiendo...' : 'Subir Comprobante'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            border: Border.all(color: successColor, width: 3), // Borde de éxito
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
                    // UX: Botón de reemplazar más discreto (TextButton)
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
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false, // Ignorar el safe area superior para mejor diseño
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!tieneEvidencia)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded, color: alertColor, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'DEBE SUBIR una evidencia de pago antes de marcar como finalizado.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: alertColor,
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
                    icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isLoading ? 'Procesando...' : 'CONFIRMAR PAGO Y FINALIZAR',
                      style: const TextStyle(
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
    // Monto a Pagar para el encabezado
    final precio = (widget.trabajo['precio'] as num?)?.toDouble() ?? 0.0;
    
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
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16.0),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PAGO PENDIENTE',
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
                      color: primaryColor,
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 60.0),
                        child: Icon(
                          Icons.account_balance_wallet,
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
                      // Banner informativo mejorado
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber[200]!, width: 1),
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
                      const SizedBox(height: 30),
                      
                      // Secciones
                      _buildSeccionUsuario(),
                      const SizedBox(height: 30),
                      _buildSeccionDatosBancarios(),
                      const SizedBox(height: 30),
                      _buildSeccionComprobante(),
                      
                      // Espacio para el botón fijo
                      const SizedBox(height: 120),
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
