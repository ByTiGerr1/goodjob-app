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

  @override
  void initState() {
    super.initState();
    _user = auth.currentUser;
    _obtenerDatosPerfil();
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
