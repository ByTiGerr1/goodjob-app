import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/screens/postulante_detalle_screen.dart';


class PostulantesTrabajoScreen extends StatelessWidget {
  final String trabajoId;

  const PostulantesTrabajoScreen({super.key, required this.trabajoId});

  Future<Map<String, dynamic>> _obtenerDatosUsuario(String usuarioId) async {
    final docSnapshot = await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get();
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
            .collection('trabajos')
            .doc(trabajoId)
            .collection('postulaciones')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar postulantes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay postulantes para este trabajo.'));
          }

          final postulaciones = snapshot.data!.docs;

          return ListView.builder(
            itemCount: postulaciones.length,
            itemBuilder: (context, index) {
              // Obtén el ID del documento de postulación
              final postulacionData = postulaciones[index].data() as Map<String, dynamic>;
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
                  final carrera = usuarioData['carrera'] ?? 'Carrera no disponible';
                  final descripcion = usuarioData['descripcion'] ?? 'Sin descripción';
                  final estado = postulacionData['estado'] ?? 'Pendiente';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PostulanteDetalleScreen(
                              usuarioId: usuarioId,
                              trabajoId: trabajoId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Text(
                                nombre.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    carrera,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    descripcion,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
