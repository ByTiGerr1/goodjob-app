import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/postulacion_service.dart';

class PostulacionesScreen extends StatelessWidget {
  const PostulacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = PostulacionService();
    return StreamBuilder<QuerySnapshot>(
      stream: servicio.obtenerPostulacionesPendientes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is FirebaseException &&
              error.code == 'failed-precondition') {
            return const Center(
                child: Text('Preparando índices, intenta más tarde'));
          }
          return const Center(
              child: Text('Error al cargar las postulaciones'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay postulaciones'));
        }
        final postulaciones = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['creadoEn'] as Timestamp?;
            final bTime = bData['creadoEn'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
        return ListView.builder(
          itemCount: postulaciones.length,
          itemBuilder: (context, index) {
            final doc = postulaciones[index];
            final data = doc.data() as Map<String, dynamic>;
            final titulo = data['trabajoTitulo'] ?? '';
            final usuario = data['usuarioId'] ?? '';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(titulo),
                subtitle: Text('Usuario: $usuario'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () =>
                          servicio.actualizarEstado(doc.id, 'aceptado'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          servicio.actualizarEstado(doc.id, 'rechazado'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
