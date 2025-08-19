import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrabajoService {
  final CollectionReference _trabajos =
      FirebaseFirestore.instance.collection('trabajos');

  Stream<QuerySnapshot> obtenerTrabajos() {
    return _trabajos.orderBy('creadoEn', descending: true).snapshots();
  }

  Future<void> crearTrabajo({
    required String titulo,
    required String descripcion,
    required String empresa,
    required Map<String, String> origen,
    required Map<String, String> destino,
    required DateTime fechaLimite,
    required DateTime fechaTrabajo,
    required TimeOfDay horaInicio,
    required TimeOfDay horaFin,
    required double precio,
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
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }
}