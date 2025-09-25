import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Permite subir una imagen a Firebase Storage en base al ID del trabajo, la ruta y
  /// el ID del usuario que sube la imagen.
  /// Retorna la URL de descarga de la imagen o null si hubo un error.
  Future<String?> subirEvidencia({
    required String trabajoId,
    required File imagen,
    required String usuarioId,
  }) async {
    try {
      final String fileName = 'evidencias/$trabajoId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('trabajos/$trabajoId/evidencias/$fileName');

      // Subimos la imagen
      final uploadTask = await ref.putFile(imagen);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      // Guardamos la referencia en Firestore
      await _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('evidencias')
          .add({
        'url': imageUrl,
        'uploadedBy': usuarioId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return imageUrl;
    } catch (e) {
      Exception('Error subiendo la evidencia: $e');
      return null;
    }
  }
  /// Mostrar evidencias de un trabajo
  /// Retorna un Stream de listas de mapas con los datos de las evidencias
  /// cada mapa contiene el ID del documento y sus datos
  Stream<List<Map<String, dynamic>>> mostrarEvidencias(String trabajoId) {
    return _firestore
        .collection('trabajos/$trabajoId/evidencias')
        .doc(trabajoId)
        .collection('evidencias')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Elimina una evidencia tanto de Firestore como de Firebase Storage
  Future<void> eliminarEvidencia({
    required String trabajoId,
    required String evidenciaId,
    required String imageUrl,
  }) async {
    try {
      // Eliminar de Firestore
      await _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('evidencias')
          .doc(evidenciaId)
          .delete();

      // Eliminar de Firebase Storage
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      Exception('Error eliminando la evidencia: $e');
    }
  }
}