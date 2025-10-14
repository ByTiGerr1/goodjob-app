import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Necesario para TimeOfDay

enum EstadoTrabajo {
  abierto,
  cerrado, 
  finalizado,
  cancelado, 
}

class TrabajoService {
  // Nota: Deberías inicializar Firebase y Firestore adecuadamente en tu proyecto.
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
  /// Acepta los DateTime combinados y los nuevos campos de contacto/uniforme.
  Future<void> crearTrabajo({
    required String titulo,
    required String descripcion,
    required String empresa,
    required Map<String, dynamic> ubicacion,
    required DateTime fechaLimite,
    required DateTime fechaInicioTrabajo,
    required DateTime fechaFinTrabajo,
    required double precio,
    required String instrucciones,
    required bool requiereUniforme, // Nuevo campo
    required List<String> implementosUniforme, // Nuevo campo
    required Map<String, String> contacto, // Nuevo campo
    bool destacado = false,
  }) {
    // Usamos Timestamp.fromDate() con los DateTime no nulos que vienen del Canvas
    return _trabajos.add({
      'titulo': titulo,
      'descripcion': descripcion,
      'empresa': empresa,
      'ubicacion': ubicacion,
      'fechaLimite': Timestamp.fromDate(fechaLimite),
      'fechaInicioTrabajo': Timestamp.fromDate(fechaInicioTrabajo),
      'fechaFinTrabajo': Timestamp.fromDate(fechaFinTrabajo),
      'precio': precio,
      'instrucciones': instrucciones,
      
      // Nuevos campos de contacto y requisitos
      'contacto': contacto,
      'requiereUniforme': requiereUniforme,
      'implementosUniforme': implementosUniforme,
      
      'destacado': destacado,
      'estado': EstadoTrabajo.abierto.name, // Estado default
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }


  /// Cancels a job by updating its state to 'cancelado'.
  Future<void> cancelarTrabajo(String trabajoId) {
    return _trabajos.doc(trabajoId).update({'estado': EstadoTrabajo.cancelado.name});
  }

  /// Counts the number of applications for a specific job.
  Future<int> contarPostulaciones(String trabajoId) async {
    try {
      final querySnapshot = await _trabajos
          .doc(trabajoId)
          .collection('postulaciones')
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error al contar postulaciones: $e'); 
      return 0;
    }
  }
}
