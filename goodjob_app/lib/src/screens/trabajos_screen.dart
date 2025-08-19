import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/trabajo_service.dart';

class TrabajosScreen extends StatelessWidget {
  const TrabajosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = TrabajoService();
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: servicio.obtenerTrabajos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay trabajos disponibles'));
          }
          final trabajos = snapshot.data!.docs;
          return ListView.builder(
            itemCount: trabajos.length,
            itemBuilder: (context, index) {
              final data = trabajos[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['titulo'] ?? ''),
                subtitle: Text(data['descripcion'] ?? ''),
                trailing: data['precio'] != null
                    ? Text('${data['precio']}')
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}