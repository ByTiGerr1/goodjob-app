import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Auth();
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await auth.logout();
              // Remove all routes and go to login
              Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}