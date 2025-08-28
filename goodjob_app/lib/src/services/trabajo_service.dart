import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrabajoService {
  final CollectionReference _trabajos =
      FirebaseFirestore.instance.collection('trabajos');

  /// Fetches a stream of all jobs, ordered by creation date.
  Stream<QuerySnapshot> obtenerTrabajos() {
    return _trabajos.orderBy('creadoEn', descending: true).snapshots();
  }

  /// Fetches a stream of featured jobs.
  Stream<QuerySnapshot> obtenerTrabajosDestacados() {
    return _trabajos
        .where('destacado', isEqualTo: true)
        .orderBy('creadoEn', descending: true)
        .snapshots();
  }

  /// Creates a new job document in Firestore.
  Future<void> crearTrabajo({
    required String titulo,
    required String descripcion,
    required String empresa,
    required Map<String, dynamic> origen,
    required Map<String, dynamic> destino,
    required DateTime fechaLimite,
    required DateTime fechaTrabajo,
    required TimeOfDay horaInicio,
    required TimeOfDay horaFin,
    required double precio,
    bool destacado = false, 
  }) {
    return _trabajos.add({
      'titulo': titulo,
      'descripcion': descripcion,
      'empresa': empresa,
      'origen': origen,
      'destino': destino,
      'fechaLimite': Timestamp.fromDate(fechaLimite),
      'fechaTrabajo': Timestamp.fromDate(fechaTrabajo),
      'horaInicio': {'h': horaInicio.hour, 'm': horaInicio.minute},
      'horaFin': {'h': horaFin.hour, 'm': horaFin.minute},
      'precio': precio,
      'destacado': destacado,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }
}
