import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/trabajo_service.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Auth auth = Auth();
    final servicio = TrabajoService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              Navigator.pushReplacementNamed(context, 'login');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: servicio.obtenerTrabajos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay trabajos'));
          }
          final trabajos = snapshot.data!.docs;
          return ListView.builder(
            itemCount: trabajos.length,
            itemBuilder: (context, index) {
              final data = trabajos[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['titulo'] ?? ''),
                subtitle: Text(data['descripcion'] ?? ''),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, 'crear_trabajo'),
        child: const Icon(Icons.add),
      ),
    );
  }
}