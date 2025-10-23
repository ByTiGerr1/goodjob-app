import 'package:cloud_firestore/cloud_firestore.dart';

class PostulanteService {
  // Instancia de Firestore para interactuar con la base de datos
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colección de usuarios donde se guarda la información del postulante
  static const String _collectionName = 'usuarios';

  /// Obtiene los datos del perfil de un postulante por su ID.
  /// Retorna un Map<String, dynamic> si el usuario existe, o null en caso de error o no encontrado.
  ///
  Future<Map<String, dynamic>?> obtenerDatosUsuario(String usuarioId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_collectionName).doc(usuarioId).get();

      if (docSnapshot.exists) {
        // Retorna los datos del documento.
        // Aquí se incluye implícitamente la 'fotoUrl' si existe en la base de datos.
        final data = docSnapshot.data();
        if (data != null) {
          // Opcional: añadir el ID del documento a los datos, si es necesario.
          data['id'] = docSnapshot.id;
        }
        return data;
      }
      
      // Documento no encontrado
      return null;
      
    } catch (e) {
      // Manejo de errores de Firestore/red
      print('Error al obtener datos del postulante $usuarioId: $e');
      return null;
    }
  }
}