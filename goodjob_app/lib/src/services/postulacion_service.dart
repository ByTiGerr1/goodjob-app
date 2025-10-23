import 'package:cloud_firestore/cloud_firestore.dart';

class PostulacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _parseEntero(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime? _combinarFechaYHora(DateTime fechaBase, dynamic horaData) {
    if (horaData is Map) {
      final horas = _parseEntero(horaData['h']);
      final minutos = _parseEntero(horaData['m']);
      return DateTime(fechaBase.year, fechaBase.month, fechaBase.day, horas, minutos);
    }

    if (horaData is String && horaData.contains(':')) {
      final partes = horaData.split(':');
      if (partes.length >= 2) {
        final horas = int.tryParse(partes[0]) ?? 0;
        final minutos = int.tryParse(partes[1]) ?? 0;
        return DateTime(fechaBase.year, fechaBase.month, fechaBase.day, horas, minutos);
      }
    }

    return DateTime(fechaBase.year, fechaBase.month, fechaBase.day);
  }

  DateTime? _obtenerFechaInicioTrabajo(Map<String, dynamic>? trabajoData) {
    if (trabajoData == null) return null;

    final fechaInicio = _parseDateTime(trabajoData['fechaInicioTrabajo']);
    if (fechaInicio != null) return fechaInicio;

    final fechaTrabajo = _parseDateTime(trabajoData['fechaTrabajo']);
    if (fechaTrabajo != null) {
      return _combinarFechaYHora(fechaTrabajo, trabajoData['horaInicio']);
    }

    final fechaFin = _parseDateTime(trabajoData['fechaFinTrabajo']);
    return fechaFin;
  }

  Timestamp _calcularConfirmarAntesDe(Map<String, dynamic>? trabajoData) {
    final ahora = DateTime.now();
    final fechaInicioTrabajo = _obtenerFechaInicioTrabajo(trabajoData);

    DateTime limite = ahora.add(const Duration(hours: 24));

    if (fechaInicioTrabajo != null) {
      final candidato = fechaInicioTrabajo.subtract(const Duration(hours: 1));
      if (candidato.isBefore(limite)) {
        limite = candidato;
      }

      if (limite.isAfter(fechaInicioTrabajo)) {
        limite = fechaInicioTrabajo;
      }
    }

    final minimoPermitido = ahora.add(const Duration(minutes: 30));
    if (!limite.isAfter(minimoPermitido)) {
      if (fechaInicioTrabajo != null &&
          fechaInicioTrabajo.isAfter(ahora) &&
          fechaInicioTrabajo.isBefore(minimoPermitido)) {
        limite = fechaInicioTrabajo;
      } else {
        limite = minimoPermitido;
      }
    }

    return Timestamp.fromDate(limite);
  }

  /// Cuenta el número de postulaciones para un trabajo específico.
  Future<int> contarPostulaciones(String trabajoId) async {
    try {
      // Usamos el método count() para una operación eficiente en la subcolección.
      final aggregateQuery = await _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('postulaciones')
          .count()
          .get();
      
      // CORRECCIÓN: Usamos ?? 0 para garantizar que se retorne un int no nulo.
      return aggregateQuery.count ?? 0;
    } catch (e) {
      // Si hay un error de conexión o lectura, retornamos 0.
      return 0;
    }
  }
  // ************************

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

  // Cancela la postulación, eliminando el registro de ambos lados.
  Future<void> cancelarPostulacion({
    required String trabajoId,
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

    final batch = _firestore.batch();
    
    // 1. Eliminar la postulación de la subcolección del trabajo
    batch.delete(postulacionRef);

    // 2. Eliminar el registro de postulación del usuario
    batch.delete(postulacionesUsuarioRef);

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
    bool limitarAUsuario = false,
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
    final trabajoRef = _firestore.collection('trabajos').doc(trabajoId);

    String estadoTrabajo = '';
    bool sinFechaLimiteTrabajo = false;
    Map<String, dynamic>? trabajoData;

    if (estadoNormalizado == 'aceptado' || estadoNormalizado == 'rechazado') {
      final trabajoDoc = await trabajoRef.get();
      if (!trabajoDoc.exists) {
        throw Exception('El trabajo $trabajoId no existe.');
      }
      trabajoData = trabajoDoc.data();
      estadoTrabajo = trabajoData?['estado'] as String? ?? '';
      sinFechaLimiteTrabajo = trabajoData?['sinFechaLimite'] == true;
    }

    // Validar que no haya otro usuario con estado "aceptado" o "confirmado"
    if (estadoNormalizado == 'aceptado') {
      final estadoTrabajoNormalizado = estadoTrabajo.toLowerCase();

      // Solo permitir aceptar postulantes si el trabajo está en estado "activo" o "abierto"
      if (estadoTrabajoNormalizado != 'activo' && estadoTrabajoNormalizado != 'abierto') {
        throw Exception(
            'No se puede aceptar postulaciones porque el trabajo no está en estado Abierto. Estado actual: $estadoTrabajo');
      }
      
      final querySnapshot = await _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('postulaciones')
          .where('estado', whereIn: ['aceptado', 'confirmado'])
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        throw Exception(
            'Ya existe un usuario con el estado "aceptado" o "confirmado" para este trabajo.');
      }

      // Cambiar el estado del trabajo a "Por confirmar"
      final confirmarAntesDe = _calcularConfirmarAntesDe(trabajoData);
      final timestamp = FieldValue.serverTimestamp();

      final trabajoUpdate = {
        'estado': 'porConfirmar',
        'aceptadoEn': timestamp,
        'confirmarAntesDe': confirmarAntesDe,
        'trabajadorAsignadoId': postulanteId,
        'estadoAsignacion': 'pendiente_confirmacion',
      };

      final batch = _firestore.batch();
      batch.set(trabajoRef, trabajoUpdate, SetOptions(merge: true));

      Map<String, dynamic> data = {
        'estado': estadoNormalizado,
        'fechaAceptacion': timestamp,
        'aceptadoEn': timestamp,
        'confirmarAntesDe': confirmarAntesDe,
      };

      final usuarioData = {
        ...data,
        'trabajoId': trabajoId,
        'usuarioId': postulanteId,
        if (trabajoTitulo != null) 'trabajoTitulo': trabajoTitulo,
      };

      batch.set(
        postulacionRef,
        data,
        SetOptions(merge: true),
      );

      batch.set(
        postulacionesUsuarioRef,
        usuarioData,
        SetOptions(merge: true),
      );

      await batch.commit();
      return;
    }

    if (estadoNormalizado == 'rechazado') {
      // Verificar si no hay otros postulantes aceptados o confirmados
      final querySnapshot = await _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('postulaciones')
          .where('estado', whereIn: ['aceptado', 'confirmado'])
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Cambiar el estado del trabajo a "Abierto" o "Activo" según corresponda
        final nuevoEstado = sinFechaLimiteTrabajo ? 'abierto' : 'activo';
        final updateData = {
          'estado': nuevoEstado,
          'trabajadorAsignadoId': FieldValue.delete(),
          'estadoAsignacion': FieldValue.delete(),
          'confirmarAntesDe': FieldValue.delete(),
          'aceptadoEn': FieldValue.delete(),
        };
        await trabajoRef.set(updateData, SetOptions(merge: true));
      }
    }

    Map<String, dynamic> data = {
      'estado': estadoNormalizado,
    };

    if (estadoNormalizado == 'rechazado') {
      data['fechaAceptacion'] = FieldValue.delete();
      data['aceptadoEn'] = FieldValue.delete();
      data['confirmarAntesDe'] = FieldValue.delete();
    }

    final usuarioData = {
      ...data,
      'trabajoId': trabajoId,
      'usuarioId': postulanteId,
      if (trabajoTitulo != null) 'trabajoTitulo': trabajoTitulo,
    };

    if (limitarAUsuario) {
      usuarioData.remove('aceptadoEn');
      usuarioData.remove('confirmarAntesDe');
    }
    
    if (limitarAUsuario) {
      await postulacionesUsuarioRef.set(
        usuarioData,
        SetOptions(merge: true),
      );
      return;
    }

    final batch = _firestore.batch();
    batch.set(
      postulacionRef,
      data,
      SetOptions(merge: true),
    );

    batch.set(
      postulacionesUsuarioRef,
      usuarioData,
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
    
    // Actualizar la postulación en la subcolección del trabajo
    batch.set(
      postulacionRef,
      {
        'estado': 'confirmado',
        'fechaAceptacion': timestamp,
        'confirmadoEn': timestamp,
      },
      SetOptions(merge: true),
    );
    
    // Actualizar la postulación en la subcolección del usuario
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
    
    // Actualizar el estado del trabajo
    batch.set(
      trabajoRef,
      {
        'trabajadorAsignadoId': postulanteId,
        'estado': 'pendiente',
        'confirmadoEn': timestamp,
        'estadoAsignacion': 'confirmado',
      },
      SetOptions(merge: true),
    );
    
    // Crear notificación para el admin
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

  Future<void> marcarTrabajoPendienteRevision({
    required String trabajoId,
    required String usuarioId,
  }) async {
    final postulacionTrabajoRef = _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(usuarioId);

    final postulacionUsuarioRef = _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('postulaciones')
        .doc(trabajoId);

    final trabajoRef = _firestore.collection('trabajos').doc(trabajoId);

    final data = {
      'estado': 'pendiente_revision',
      'estadoTrabajo': 'pendiente_revision',
      'trabajoCompletado': true,
      'pendienteRevisionEn': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();

    batch.set(postulacionTrabajoRef, data, SetOptions(merge: true));
    batch.set(postulacionUsuarioRef, data, SetOptions(merge: true));
    batch.set(trabajoRef, {'estadoTrabajo': 'pendiente_revision'},
        SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> registrarCheckIn({
    required String trabajoId,
    required String usuarioId,
    DateTime? checkInLocal,
  }) async {
    final postulacionTrabajoRef = _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(usuarioId);

    final postulacionUsuarioRef = _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('postulaciones')
        .doc(trabajoId);

    final trabajoRef = _firestore.collection('trabajos').doc(trabajoId);

    final serverTimestamp = FieldValue.serverTimestamp();

    final updates = {
      'estadoTrabajo': 'en_curso',
      'inicioTrabajoReal': serverTimestamp,
      'finTrabajoReal': FieldValue.delete(),
      'duracionTrabajoMinutos': FieldValue.delete(),
      'trabajoCompletado': false,
      if (checkInLocal != null) 'inicioTrabajoLocal': Timestamp.fromDate(checkInLocal),
    };

    final batch = _firestore.batch();
    batch.set(postulacionTrabajoRef, updates, SetOptions(merge: true));
    batch.set(postulacionUsuarioRef, updates, SetOptions(merge: true));
    batch.set(
      trabajoRef,
      {
        'estado': 'enCurso',
        'estadoTrabajo': 'en_curso',
        'inicioTrabajoReal': serverTimestamp,
        'finTrabajoReal': FieldValue.delete(),
        'duracionTrabajoMinutos': FieldValue.delete(),
        'trabajoCompletado': false,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> registrarCheckOut({
    required String trabajoId,
    required String usuarioId,
    DateTime? checkOutLocal,
  }) async {
    final postulacionTrabajoRef = _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('postulaciones')
        .doc(usuarioId);

    final postulacionUsuarioRef = _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('postulaciones')
        .doc(trabajoId);

    final trabajoRef = _firestore.collection('trabajos').doc(trabajoId);

    Timestamp? inicioTrabajo;
    try {
      final snapshot = await postulacionTrabajoRef.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final rawInicio = data?['inicioTrabajoReal'];
        if (rawInicio is Timestamp) {
          inicioTrabajo = rawInicio;
        } else if (rawInicio is DateTime) {
          inicioTrabajo = Timestamp.fromDate(rawInicio);
        }
      }
    } catch (_) {
      inicioTrabajo = null;
    }

    final checkOutMoment = checkOutLocal ?? DateTime.now();
    int? duracionMinutos;
    if (inicioTrabajo != null) {
      final duracion = checkOutMoment.difference(inicioTrabajo.toDate());
      if (!duracion.isNegative) {
        duracionMinutos = duracion.inMinutes;
      }
    }

    final serverTimestamp = FieldValue.serverTimestamp();

    final updates = {
      'finTrabajoReal': serverTimestamp,
      'trabajoCompletado': true,
      if (checkOutLocal != null) 'finTrabajoLocal': Timestamp.fromDate(checkOutLocal),
      if (duracionMinutos != null) 'duracionTrabajoMinutos': duracionMinutos,
    };

    final batch = _firestore.batch();
    batch.set(postulacionTrabajoRef, updates, SetOptions(merge: true));
    batch.set(postulacionUsuarioRef, updates, SetOptions(merge: true));
    batch.set(
      trabajoRef,
      {
        'finTrabajoReal': serverTimestamp,
        if (duracionMinutos != null) 'duracionTrabajoMinutos': duracionMinutos,
        'trabajoCompletado': true,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}