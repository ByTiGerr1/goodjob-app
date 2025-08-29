import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import '../services/postulacion_service.dart';

class MisTrabajosScreen extends StatelessWidget {
  const MisTrabajosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Auth();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mis trabajos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: PostulacionService().obtenerPostulacionesDeUsuario(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay postulaciones'));
          }
          final postulaciones = snapshot.data!.docs;
          return ListView.builder(
            itemCount: postulaciones.length,
            itemBuilder: (context, index) {
              final data = postulaciones[index].data() as Map<String, dynamic>;
              final titulo = data['trabajoTitulo'] ?? '';
              final estado = data['estado'] ?? '';
              return ListTile(
                title: Text(titulo),
                subtitle: Text('Estado: $estado'),
              );
            },
          );
        },
      ),
    );
  }
}