import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Auth auth = Auth();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              // After logout, return to login screen
              Navigator.pushReplacementNamed(context, 'login');
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Panel de administrador'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, 'crear_trabajo'),
        child: const Icon(Icons.add),
      ),
    );
  }
}