import 'package:cloud_firestore/cloud_firestore.dart';

class PostulacionService {
  final CollectionReference _postulaciones =
      FirebaseFirestore.instance.collection('postulaciones');

  Future<void> crearPostulacion({
    required String trabajoId,
    required String trabajoTitulo,
    required String usuarioId,
  }) {
    return _postulaciones.add({
      'trabajoId': trabajoId,
      'trabajoTitulo': trabajoTitulo,
      'usuarioId': usuarioId,
      'estado': 'pendiente',
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> existePostulacion({
    required String trabajoId,
    required String usuarioId,
  }) async {
    final query = await _postulaciones
        .where('trabajoId', isEqualTo: trabajoId)
        .where('usuarioId', isEqualTo: usuarioId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Stream<QuerySnapshot> obtenerPostulacionesPendientes() {
    return _postulaciones
        .where('estado', isEqualTo: 'pendiente')
        .snapshots();
  }

  Future<void> actualizarEstado(String id, String estado) {
    return _postulaciones.doc(id).update({'estado': estado});
  }

  Stream<QuerySnapshot> obtenerPostulacionesDeUsuario(String uid) {
    return _postulaciones.where('usuarioId', isEqualTo: uid).snapshots();
  }
}