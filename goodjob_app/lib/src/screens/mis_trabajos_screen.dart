import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import '../services/postulacion_service.dart';

class MisTrabajosScreen extends StatelessWidget {
  const MisTrabajosScreen({super.key});

  void _mostrarNotificacion(
      BuildContext context, String titulo, String estado) {
    final mensaje = estado == 'aceptado'
        ? 'Tu postulación a "$titulo" fue aceptada'
        : 'Tu postulación a "$titulo" fue rechazada';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

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
      appBar: AppBar(title: const Text('Mis postulaciones')),
      body: StreamBuilder<QuerySnapshot>(
        stream: PostulacionService().obtenerPostulacionesDeUsuario(uid),
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

          if (snapshot.data != null) {
            for (final cambio in snapshot.data!.docChanges) {
              if (cambio.type == DocumentChangeType.modified) {
                final data =
                    cambio.doc.data() as Map<String, dynamic>? ?? {};
                final estado = data['estado'];
                if (estado == 'aceptado' || estado == 'rechazado') {
                  final titulo = data['trabajoTitulo'] ?? '';
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _mostrarNotificacion(context, titulo, estado);
                  });
                }
              }
            }
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
