import 'package:cloud_firestore/cloud_firestore.dart';

class PostulacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Realiza una consulta de grupo para obtener todas las postulaciones.
  Stream<QuerySnapshot> obtenerTodasLasPostulaciones() {
    return _firestore
        .collectionGroup('postulaciones')
        .orderBy('fechaPostulacion', descending: true)
        .snapshots();
  }

  // Obtiene las postulaciones para un trabajo específico
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
        .where('estado', whereIn: ['pendiente', 'Pendiente'])
        .snapshots();
  }

  // Crea una nueva postulación
  Future<void> crearPostulacion({
    required String trabajoId,
    required String trabajoTitulo,
    required String usuarioId,
  }) async {
    final postulacionRef = _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(usuarioId);
    final postulacionesUsuarioRef = _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('postulaciones')
        .doc(trabajoId);

    final data = <String, dynamic>{
      'trabajoId': trabajoId,
      'trabajoTitulo': trabajoTitulo,
      'usuarioId': usuarioId,
      'estado': 'pendiente',
      'fechaPostulacion': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(postulacionRef, data);
    batch.set(postulacionesUsuarioRef, data);
    await batch.commit();
  }

  // Verifica si un usuario ya se postuló a un trabajo
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

  // Actualiza el estado de una postulación
  Future<void> actualizarEstado({
    required String trabajoId,
    required String postulanteId,
    required String nuevoEstado,
    String? trabajoTitulo,
  }) async {
    final estadoNormalizado = nuevoEstado.toLowerCase();
    final postulacionRef = _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(postulanteId);
    final postulacionesUsuarioRef = _firestore
        .collection('usuarios')
        .doc(postulanteId)
        .collection('postulaciones')
        .doc(trabajoId);

    Map<String, dynamic> data = {
      'estado': estadoNormalizado,
    };

    // Registrar fecha de aceptación si es aceptado o confirmado
    if (estadoNormalizado == 'aceptado' || estadoNormalizado == 'confirmado') {
      data['fechaAceptacion'] = FieldValue.serverTimestamp();
    }

    final batch = _firestore.batch();
    batch.update(postulacionRef, data);

    batch.set(
      postulacionesUsuarioRef,
      {
        ...data,
        'trabajoId': trabajoId,
        'usuarioId': postulanteId,
        if (trabajoTitulo != null) 'trabajoTitulo': trabajoTitulo,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // Obtiene las postulaciones de un usuario específico
  Stream<QuerySnapshot> obtenerPostulacionesDeUsuario(String uid) {
    return _firestore
        .collection('usuarios')
        .doc(uid)
        .collection('postulaciones')
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> observarPostulacionDeUsuario({
    required String trabajoId,
    required String usuarioId,
  }) {
    return _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('postulaciones')
        .doc(trabajoId)
        .snapshots();
  }

  // Confirma la asignación de un trabajo
  Future<void> confirmarAsignacion({
    required String trabajoId,
    required String postulanteId,
    required String trabajoTitulo,
  }) async {
    final postulacionRef = _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(postulanteId);
    final postulacionesUsuarioRef = _firestore
        .collection('usuarios')
        .doc(postulanteId)
        .collection('postulaciones')
        .doc(trabajoId);
    final trabajoRef = _firestore.collection('trabajos').doc(trabajoId);
    final notificacionesRef =
        _firestore.collection('notificaciones_admin').doc();

    final timestamp = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(
      postulacionRef,
      {
        'estado': 'confirmado',
        'fechaAceptacion': timestamp,
        'confirmadoEn': timestamp,
      },
      SetOptions(merge: true),
    );
    batch.set(
      postulacionesUsuarioRef,
      {
        'estado': 'confirmado',
        'trabajoId': trabajoId,
        'usuarioId': postulanteId,
        'trabajoTitulo': trabajoTitulo,
        'fechaAceptacion': timestamp,
        'confirmadoEn': timestamp,
      },
      SetOptions(merge: true),
    );
    batch.set(
      trabajoRef,
      {
        'trabajadorAsignadoId': postulanteId,
        'estadoAsignacion': 'confirmado',
        'confirmadoEn': timestamp,
      },
      SetOptions(merge: true),
    );
    batch.set(
      notificacionesRef,
      {
        'tipo': 'confirmacion_trabajo',
        'trabajoId': trabajoId,
        'postulanteId': postulanteId,
        'trabajoTitulo': trabajoTitulo,
        'creadoEn': timestamp,
        'leido': false,
      },
    );

    await batch.commit();
  }

  // Libera la asignación de un trabajo por expiración
  Future<void> liberarAsignacionPorExpiracion({
    required String trabajoId,
    required String postulanteId,
    required String trabajoTitulo,
  }) async {
    final postulacionRef = _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(postulanteId);
    final postulacionesUsuarioRef = _firestore
        .collection('usuarios')
        .doc(postulanteId)
        .collection('postulaciones')
        .doc(trabajoId);
    final trabajoRef = _firestore.collection('trabajos').doc(trabajoId);
    final notificacionesRef =
        _firestore.collection('notificaciones_admin').doc();

    final batch = _firestore.batch();
    batch.set(
      postulacionRef,
      {
        'estado': 'pendiente',
        'confirmadoEn': FieldValue.delete(),
        'fechaAceptacion': FieldValue.delete(),
        'confirmarAntesDe': FieldValue.delete(),
        'liberadoPorExpiracionEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      postulacionesUsuarioRef,
      {
        'estado': 'pendiente',
        'confirmadoEn': FieldValue.delete(),
        'fechaAceptacion': FieldValue.delete(),
        'confirmarAntesDe': FieldValue.delete(),
        'liberadoPorExpiracionEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      trabajoRef,
      {
        'trabajadorAsignadoId': FieldValue.delete(),
        'estadoAsignacion': FieldValue.delete(),
        'confirmadoEn': FieldValue.delete(),
        'confirmacionExpiradaEn': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      notificacionesRef,
      {
        'tipo': 'confirmacion_expirada',
        'trabajoId': trabajoId,
        'postulanteId': postulanteId,
        'trabajoTitulo': trabajoTitulo,
        'creadoEn': FieldValue.serverTimestamp(),
        'leido': false,
      },
    );

    await batch.commit();
  }
}
