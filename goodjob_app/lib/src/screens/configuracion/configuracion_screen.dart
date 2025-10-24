import 'dart:async';
import 'dart:io'; 

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:goodjob_app/src/screens/configuracion/editar_datos_bancarios_screen.dart';
import 'package:goodjob_app/src/screens/configuracion/editar_perfil.dart';
import 'package:goodjob_app/src/screens/auth/login_screen.dart';

// Importar el servicio de Storage (Ajustar la ruta según tu proyecto)
import '../../services/storage_service.dart';
import '../../services/firebase_service.dart'; // Asumiendo que Auth está aquí
import '../../widgets/delete_account_confirmation_dialog.dart';
import '../../widgets/logout_confirmation_dialog.dart';

// Constantes de color para mantener la estética
const Color _PRIMARY_COLOR = AppColors.primary;
const Color _ACCENT_COLOR = AppColors.accent;
const Color _verifiedColor = AppColors.success; // Verde
const Color _pendingColor = AppColors.pendingColor; // Naranja/Ámbar
const Color _dangerColor = AppColors.alertColor; // Rojo

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final auth = Auth();
  // 1. INSTANCIAR STORAGE SERVICE
  final StorageService _storageService = StorageService();

  User? _user;
  Map<String, dynamic> _perfilData = {};
  final _firestore = FirebaseFirestore.instance;
  // Eliminamos la instancia directa de FirebaseStorage ya que usamos el servicio
  // final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isEmailVerified = false;
  bool _isSendingVerification = false;
  bool _isCheckingVerification = false;
  bool _verificationEmailSent = false;
  bool _isUploadingPicture = false; // Estado para subir foto

  @override
  void initState() {
    super.initState();
    _user = auth.currentUser;
    _isEmailVerified = _user?.emailVerified ?? false;
    _obtenerDatosPerfil();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isEmailVerified && _user != null) {
        Timer.periodic(const Duration(seconds: 3), (timer) {
          if (!mounted || _isEmailVerified) {
            timer.cancel();
          } else {
            _refreshUser();
          }
        });
      }
    });
  }

  // --- LÓGICA DE DATOS Y VERIFICACIÓN ---

  Future<void> _obtenerDatosPerfil() async {
    if (_user == null) return;
    try {
      final docSnapshot = await _firestore
          .collection('usuarios')
          .doc(_user!.uid)
          .get();
      if (!mounted) return;
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _perfilData = data != null ? Map<String, dynamic>.from(data) : {};
        });
      }
    } catch (e) {
      debugPrint('Error al obtener datos del perfil: $e');
    }
  }

  Future<void> _refreshUser() async {
    if (_user == null) return;
    try {
      await _user!.reload();
      final refreshedUser = auth.currentUser;
      if (!mounted) return;
      setState(() {
        _user = refreshedUser;
        _isEmailVerified = refreshedUser?.emailVerified ?? false;
      });
      if (_isEmailVerified && _verificationEmailSent) {
        _verificationEmailSent = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Tu correo ya está verificado! 🎉'),
              backgroundColor: _verifiedColor,
            ),
          );
        }
      }
    } catch (e) {
      // Manejo de errores
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_user == null || _isSendingVerification) return;
    setState(() {
      _isSendingVerification = true;
      _verificationEmailSent = false;
    });
    try {
      await _user!.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _verificationEmailSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correo de verificación enviado. Revisa tu bandeja de entrada.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar el correo de verificación: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_user == null || _isCheckingVerification) return;
    setState(() {
      _isCheckingVerification = true;
    });

    await _refreshUser();

    if (!mounted) return;
    setState(() {
      _isCheckingVerification = false;
    });

    if (_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Tu correo ya está verificado!'),
          backgroundColor: _verifiedColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aún no se ha verificado el correo. Por favor, haz clic en el enlace del email.',
          ),
        ),
      );
    }
  }

  // --- LÓGICA DE SUBIDA DE FOTO USANDO StorageService ---
  Future<void> _changeProfilePicture() async {
    if (_user == null || _isUploadingPicture) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Calidad reducida para mejor rendimiento
    );

    if (image == null) return;

    setState(() {
      _isUploadingPicture = true;
    });

    final File file = File(image.path);
    final String userId = _user!.uid;

    try {
      // Paso 1: RECARGA DE SEGURIDAD Y REFRESH DEL TOKEN (Buena práctica)
      await _user!.reload();
      await _user!.getIdToken(true); // Fuerza el refresh del token
      _user = FirebaseAuth.instance.currentUser;

      if (_user == null) {
        throw Exception("User not authenticated after reload.");
      }
      
      // Paso 2 y 3: LLAMAR AL SERVICIO PARA SUBIR LA IMAGEN
      // El StorageService maneja la referencia, el putFile y el getDownloadURL.
      final String? downloadUrl = await _storageService.subirFotoPerfil(
        userId: userId,
        imagen: file,
      );

      if (downloadUrl == null) {
        throw Exception("El servicio de almacenamiento no pudo obtener la URL de descarga.");
      }

      // 4. Actualizar el campo 'fotoUrl' en Firestore
      await _firestore.collection('usuarios').doc(_user!.uid).set({
        'fotoUrl': downloadUrl,
      }, SetOptions(merge: true));

      // 5. Actualizar la UI localmente (Firebase Auth y perfil local)
      await _user!.updatePhotoURL(downloadUrl);
      await _obtenerDatosPerfil();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil actualizada con éxito! 🎉'),
            backgroundColor: _verifiedColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al subir la foto o timeout: $e');
      String message;

      if (e.toString().contains("No pudo obtener la URL de descarga")) {
        // Mensaje específico cuando StorageService devuelve null (posiblemente por red, permisos o tamaño).
        message = 'La subida falló. Intenta de nuevo, o asegúrate de tener buena conexión y que el archivo no sea demasiado grande.';
      } else {
        // Mensaje genérico para otros errores inesperados.
        message = 'Ocurrió un error inesperado al actualizar la foto. Por favor, inténtalo más tarde.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: _dangerColor),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPicture = false;
        });
      }
    }
  }
  // --- FIN LÓGICA DE SUBIDA DE FOTO ---


  // --- WIDGETS DE COMPONENTES DE VISTA ---

  Widget _buildUserProfileSection() {
    final nombreCompleto = _perfilData['nombre'] ?? 'Usuario';
    // Prioriza 'fotoUrl' de Firestore, si no existe, usa photoURL de Auth
    final fotoUrl = _perfilData['fotoUrl'] as String? ?? _user?.photoURL;
    final inicial = nombreCompleto.isNotEmpty
        ? nombreCompleto[0].toUpperCase()
        : 'U';

    return Padding(
      padding: const EdgeInsets.only(
        top: 40.0,
      ), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment
            .center, 
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              // Avatar Principal (Círculo)
              CircleAvatar(
                radius: 60,
                backgroundColor: _PRIMARY_COLOR.withOpacity(0.8),
                backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                    ? NetworkImage(fotoUrl)
                    : null,
                child: fotoUrl == null || fotoUrl.isEmpty
                    ? Text(
                        inicial,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              // Botón de Cámara (Cambiador)
              Positioned(
                bottom: 0,
                right: 0,
                child: FloatingActionButton.small(
                  onPressed: _isUploadingPicture ? null : _changeProfilePicture, 
                  backgroundColor: _ACCENT_COLOR,
                  child: _isUploadingPicture
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          color: Colors.black, 
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            nombreCompleto,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?.email ?? 'No hay correo registrado',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVerificationCard() {
    final icon = _isEmailVerified
        ? Icons.verified_user
        : Icons.warning_amber_rounded;
    final color = _isEmailVerified ? _verifiedColor : _pendingColor;
    final title = _isEmailVerified
        ? '¡Cuenta Verificada!'
        : 'Verificación Pendiente';
    final subtitle = _isEmailVerified
        ? 'Tu correo ha sido verificado. Esto asegura que puedes recuperar tu cuenta sin problemas.'
        : 'Tu correo aún no está verificado. Haz clic en "Enviar correo" y luego en el enlace que recibirás.';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[700], fontSize: 14.5),
            ),

            if (!_isEmailVerified) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSendingVerification
                          ? null
                          : _sendVerificationEmail,
                      icon: _isSendingVerification
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors
                                    .black, // Color para contraste con amarillo/naranja
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              size: 18,
                              color: Colors.black,
                            ),
                      label: Text(
                        _isSendingVerification
                            ? 'Enviando...'
                            : 'Enviar correo',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _ACCENT_COLOR, // Amarillo para hacerlo prominente
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isCheckingVerification
                          ? null
                          : _checkVerificationStatus,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: _isCheckingVerification
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Ya verifiqué'),
                    ),
                  ),
                ],
              ),
              if (_verificationEmailSent)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Si no lo ves, revisa la carpeta de spam o promociones.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget de cabecera de sección más estilizado
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 2),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900, // Fuente más pesada
            color: Colors.grey[800],
          ),
        ),
      ),
    );
  }

  // Lista de opciones con Cards y separadores sutiles
  Widget _buildSettingsListCard(List<Widget> items) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              item,
              if (index < items.length - 1)
                const Divider(
                  height: 0,
                  indent: 20,
                  endIndent: 20,
                  color: Colors.black12,
                ), // Separador sutil
            ],
          );
        }),
      ),
    );
  }

  // ListTile con jerarquía de texto mejorada
  ListTile _buildHierarchicalListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = _PRIMARY_COLOR,
    Color titleColor = Colors.black,
    Color subtitleColor = Colors.grey,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold, // Título en negrita
          fontSize: 16,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: subtitleColor, // Subtítulo en color apagado
        ),
      ),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Colors.black54),
      onTap: onTap,
    );
  }

  ListTile _buildLogoutTile() {
    return _buildHierarchicalListTile(
      icon: Icons.logout,
      title: 'Cerrar Sesión',
      subtitle: 'Cierra tu sesión actual de forma segura.',
      onTap: () async {
        final shouldLogout = await showLogoutConfirmationDialog(context);
        if (!shouldLogout) return;

        await auth.logout();
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
      trailing: const Icon(Icons.chevron_right, color: Colors.black54),
    );
  }

  ListTile _buildDeleteAccountTile() {
    return _buildHierarchicalListTile(
      icon: Icons.delete_forever_outlined,
      title: 'Eliminar Cuenta',
      subtitle: 'Elimina tu cuenta y todos tus datos de forma permanente.',
      onTap: () async {
        final shouldDelete =
            await showDeleteAccountConfirmationDialog(context);
        if (!shouldDelete || !mounted) return;

        final navigator = Navigator.of(context, rootNavigator: true);

        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        try {
          await auth.deleteAccount();
          navigator.pop();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        } catch (error) {
          navigator.pop();
          if (!mounted) return;
          final message =
              error.toString().replaceFirst('Exception: ', '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.isEmpty
                  ? 'No se pudo eliminar la cuenta. Intenta nuevamente.'
                  : message),
              backgroundColor: _dangerColor,
            ),
          );
        }
      },
      iconColor: _dangerColor,
      titleColor: _dangerColor,
      subtitleColor: Colors.grey.shade600,
      trailing: const Icon(Icons.chevron_right, color: Colors.black54),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            floating: false,
            pinned: true,
            backgroundColor: _PRIMARY_COLOR,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_PRIMARY_COLOR, _ACCENT_COLOR],
                  ),
                ),
                child: _buildUserProfileSection(),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // 1. Tarjeta de Seguridad y Verificación
              _buildVerificationCard(),

              const SizedBox(height: 24),

              // 2. SECCIÓN: Configuración de Cuenta (Solo opciones originales)
              _buildSectionHeader('Configuración de Cuenta'),
              _buildSettingsListCard([
                _buildHierarchicalListTile(
                  icon: Icons.account_circle_outlined,
                  title: 'Editar Perfil',
                  subtitle: 'Información personal, habilidades, etc.',
                  onTap: () async {
                    // Esperamos a que la pantalla de edición se cierre
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditarPerfilScreen(),
                      ),
                    );
                    // Recargamos los datos del perfil si regresamos
                    _obtenerDatosPerfil();
                  },
                ),
                _buildHierarchicalListTile(
                  icon: Icons.credit_card,
                  title: 'Métodos de Pago',
                  subtitle: 'Gestiona tus datos bancarios para recibir pagos.',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const EditarDatosBancariosScreen(),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // SECCIÓN: Acciones de Sesión (Mantenida)
              _buildSectionHeader('Acciones'),
              _buildSettingsListCard([
                _buildLogoutTile(),
                _buildDeleteAccountTile(),
              ]),

              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }
}
