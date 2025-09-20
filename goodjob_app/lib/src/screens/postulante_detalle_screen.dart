import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pantalla que muestra el perfil detallado de un postulante
class PostulanteDetalleScreen extends StatelessWidget {
  final String usuarioId;
  final String trabajoId;
  final String postId;

  const PostulanteDetalleScreen({
    super.key,
    required this.usuarioId,
    required this.trabajoId,
    required this.postId,
  });

  // Método para obtener los datos completos del usuario de Firestore
  Future<Map<String, dynamic>?> _obtenerDatosUsuario() async {
    try {
      final docSnapshot =
          await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get();
      return docSnapshot.data();
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
      return null;
    }
  }

  // Método para actualizar el estado de la postulación en Firestore
  Future<void> _actualizarEstadoPostulacion(String estado, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('trabajos')
          .doc(trabajoId)
          .collection('postulaciones')
          .doc(postId)
          .update({'estado': estado});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Postulación $estado con éxito')),
      );
      // Opcional: Volver a la pantalla anterior
      Navigator.of(context).pop();
    } catch (e) {
      print('Error al actualizar el estado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el estado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Postulante'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _obtenerDatosUsuario(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Error al cargar los datos del postulante.'));
          }

          final usuarioData = snapshot.data!;
          final nombre = usuarioData['nombre'] ?? 'Sin nombre';
          final apellido = usuarioData['apellido'] ?? '';
          final rut = usuarioData['rut'] ?? 'No disponible';
          final carrera = usuarioData['carrera'] ?? 'No disponible';
          final email = usuarioData['email'] ?? 'No disponible';
          final telefono = usuarioData['telefono'] ?? 'No disponible';
          final descripcion = usuarioData['descripcion'] ?? 'Sin descripción.';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '$nombre $apellido',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    carrera,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Acerca de mí',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(descripcion),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información de contacto',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: Text(email),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.phone),
                          title: Text(telefono),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Contactando a $nombre...')),
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Contactar Postulante'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _actualizarEstadoPostulacion('Aceptado', context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Aceptar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _actualizarEstadoPostulacion('Rechazado', context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
