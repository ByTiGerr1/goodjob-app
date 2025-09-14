import 'package:cloud_firestore/cloud_firestore.dart';

class PostulacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Realiza una consulta de grupo para obtener todas las postulaciones.
  // Se usa para la pantalla general de postulaciones.
  Stream<QuerySnapshot> obtenerTodasLasPostulaciones() {
    return _firestore
        .collectionGroup('postulaciones')
        .orderBy('fechaPostulacion', descending: true)
        .snapshots();
  }

  // Obtiene las postulaciones para un trabajo específico desde la colección raíz.
  // Esta es la consulta que te permitirá ver los postulantes en la pantalla
  // 'PostulantesTrabajoScreen'.
  Stream<QuerySnapshot> obtenerPostulacionesDeTrabajo(String trabajoId) {
  return _firestore
    .collection('trabajos')
    .doc(trabajoId)
    .collection('postulaciones')
    .orderBy('fechaPostulacion', descending: true)
    .snapshots();
  }

  Stream<QuerySnapshot> obtenerPostulacionesPendientes(String trabajoId) {
    return _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .where('estado', isEqualTo: 'Pendiente')
        .orderBy('fechaPostulacion', descending: true)
        .snapshots();
  }

  // Crea una nueva postulación en la subcolección del trabajo.
  Future<void> crearPostulacion({
    required String trabajoId,
    required String trabajoTitulo,
    required String usuarioId,
  }) {
    return _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(usuarioId)
        .set({
      'trabajoId': trabajoId,
      'trabajoTitulo': trabajoTitulo,
      'usuarioId': usuarioId,
      'estado': 'Pendiente',
      'fechaPostulacion': FieldValue.serverTimestamp(),
    });
  }

  // Verifica si un usuario ya se postuló a un trabajo específico.
  Future<bool> existePostulacion({
    required String trabajoId,
    required String usuarioId,
  }) async {
    final doc = await _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(usuarioId)
        .get();
    return doc.exists;
  }

  // Actualiza el estado de una postulación específica dentro de su subcolección.
  // Se ha cambiado a parámetros con nombre para mayor claridad.
  Future<void> actualizarEstado({
    required String trabajoId,
    required String postulacionId,
    required String nuevoEstado,
  }) {
    return _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(postulacionId)
        .update({'estado': nuevoEstado});
  }

  // Obtiene las postulaciones de un usuario específico.
  Stream<QuerySnapshot> obtenerPostulacionesDeUsuario(String uid) {
    return _firestore
        .collectionGroup('postulaciones')
        .where('usuarioId', isEqualTo: uid)
        .orderBy('fechaPostulacion', descending: true)
        .snapshots();
  }
}
