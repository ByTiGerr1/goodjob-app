import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final auth = Auth();
  User? _user;
  Map<String, dynamic> _perfilData = {};
  final _firestore = FirebaseFirestore.instance;
  bool _isEmailVerified = false;
  bool _isSendingVerification = false;
  bool _isCheckingVerification = false;
  bool _verificationEmailSent = false;

  @override
  void initState() {
    super.initState();
    _user = auth.currentUser;
    _isEmailVerified = _user?.emailVerified ?? false;
    _obtenerDatosPerfil();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUser();
    });
  }

  Future<void> _obtenerDatosPerfil() async {
    if (_user == null) return;
    try {
      final docSnapshot =
          await _firestore.collection('usuarios').doc(_user!.uid).get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _perfilData =
              data != null ? Map<String, dynamic>.from(data) : {};
        });
      } else {
        setState(() {
          _perfilData = {};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron datos del perfil del usuario.'),
          ),
        );
      }
    } catch (e) {
      print('Error al obtener datos del perfil: $e');
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
        if (_isEmailVerified) {
          _verificationEmailSent = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el estado de verificación: $e')),
      );
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_user == null) return;
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
          content: Text('Correo de verificación enviado. Revisa tu bandeja de entrada.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el correo de verificación: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_user == null) return;
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
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no se ha verificado el correo. Revisa tu bandeja o intenta nuevamente.'),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: const Icon(
                      Icons.account_circle,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _perfilData['nombre'] ?? 'Usuario',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _user?.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isEmailVerified ? Icons.verified : Icons.mark_email_unread_outlined,
                          color: _isEmailVerified ? Colors.green : Colors.orange,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verificación de perfil',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isEmailVerified
                                    ? 'Tu correo ha sido verificado correctamente. ¡Gracias por mantener tu perfil seguro!'
                                    : 'Aún no has verificado tu correo electrónico. Verifica tu correo para completar la configuración de tu perfil.',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              if (_verificationEmailSent && !_isEmailVerified)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Hemos enviado un nuevo correo de verificación. Revisa la bandeja de entrada o la carpeta de spam.',
                                    style: TextStyle(color: Colors.blueGrey[700], fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!_isEmailVerified) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSendingVerification ? null : _sendVerificationEmail,
                        icon: _isSendingVerification
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.email_outlined),
                        label: Text(
                          _isSendingVerification
                              ? 'Enviando...'
                              : 'Enviar correo de verificación',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _isCheckingVerification ? null : _checkVerificationStatus,
                        child: _isCheckingVerification
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Ya verifiqué mi correo'),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E4F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_outlined, color: Colors.black54),
                    title: const Text('Mi perfil'),
                    subtitle: const Text('Edita tus datos personales y preferencias.'),
                    onTap: () {
                      // Implementar navegación a la pantalla de edición de perfil
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.black54),
                    title: const Text('Mi cuenta'),
                    subtitle: const Text('Gestiona tu información de pago y suscripciones.'),
                    onTap: () {
                      // Implementar navegación a la pantalla de cuenta
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Colors.black54),
                    title: const Text('Ayuda y soporte'),
                    subtitle: const Text('Encuentra respuestas a tus preguntas o contacta con nosotros.'),
                    onTap: () {
                      // Implementar navegación a la pantalla de ayuda
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.black54),
                    title: const Text('Cerrar sesión'),
                    subtitle: const Text('Sal de tu cuenta de forma segura.'),
                    onTap: () async {
                      await auth.logout();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          'login',
                          (route) => false,
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                    title: const Text('Eliminar cuenta', style: TextStyle(color: Colors.red)),
                    subtitle: const Text('Elimina tu cuenta y todos tus datos de forma permanente.'),
                    onTap: () {
                      // La lógica para cerrar una cuenta (eliminar datos)
                      // es compleja y requiere confirmación del usuario.
                      // Se implementaría una función aquí para este propósito.
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
