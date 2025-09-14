import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostulantesTrabajoScreen extends StatelessWidget {
  final String trabajoId;

  const PostulantesTrabajoScreen({super.key, required this.trabajoId});

  Future<Map<String, dynamic>> _obtenerDatosUsuario(String usuarioId) async {
    final docSnapshot =
        await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get();
    return docSnapshot.data() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postulantes'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('postulaciones')
            .where('trabajoId', isEqualTo: trabajoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Manejar errores de permisos o de carga de la base de datos.
            return Center(child: Text('Error al cargar postulantes: \\${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay postulantes para este trabajo.'));
          }

          final postulaciones = snapshot.data!.docs;

          return ListView.builder(
            itemCount: postulaciones.length,
            itemBuilder: (context, index) {
              final postulacionData =
                  postulaciones[index].data() as Map<String, dynamic>;
              final usuarioId = postulacionData['usuarioId'];

              if (usuarioId == null || usuarioId.isEmpty) {
                return const ListTile(
                  title: Text('Error: ID de usuario no válido.'),
                );
              }

              return FutureBuilder<Map<String, dynamic>>(
                future: _obtenerDatosUsuario(usuarioId),
                builder: (context, usuarioSnapshot) {
                  if (usuarioSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Cargando postulante...'),
                    );
                  }
                  if (usuarioSnapshot.hasError || !usuarioSnapshot.hasData) {
                    return const ListTile(
                      title: Text('Error al cargar datos del usuario.'),
                    );
                  }

                  final usuarioData = usuarioSnapshot.data!;
                  final nombre = usuarioData['nombre'] ?? 'Nombre no disponible';
                  final estado = postulacionData['estado'] ?? 'Pendiente';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(
                        nombre,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
                      ),
                      subtitle: Text(
                        'Estado: $estado',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Acción al seleccionar un postulante, como ver su perfil completo.
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
