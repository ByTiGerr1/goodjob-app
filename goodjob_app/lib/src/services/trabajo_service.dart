import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Necesario para TimeOfDay

enum EstadoTrabajo {
  activo,        // buscando postulantes
  porConfirmar,  // se eligió un postulante pero no ha confirmado
  pendiente,     // postulante confirmó, falta la fecha
  enCurso,       // trabajo en ejecución
  porRevisar,    // evidencias pendientes de revisión
  porPagar,      // evidencias aceptadas, pago pendiente
  finalizado,    // pago completado
  cancelado,     // trabajo cancelado por el administrador
}
extension EstadoTrabajoExtension on EstadoTrabajo {
  String get texto {
    switch (this) {
      case EstadoTrabajo.activo: return "Activo";
      case EstadoTrabajo.porConfirmar: return "Por confirmar";
      case EstadoTrabajo.pendiente: return "Pendiente";
      case EstadoTrabajo.enCurso: return "En curso";
      case EstadoTrabajo.porRevisar: return "Por revisar";
      case EstadoTrabajo.porPagar: return "Por pagar";
      case EstadoTrabajo.finalizado: return "Finalizado";
      case EstadoTrabajo.cancelado: return "Cancelado";
    }
  }
}
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
      'estado': EstadoTrabajo.activo.name, // Estado default
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  // --- NUEVA FUNCIÓN PARA EDICIÓN ---
  /// Updates an existing job document in Firestore.
  Future<void> actualizarTrabajo({
    required String trabajoId,
    required String titulo,
    required String descripcion,
    required String empresa,
    required Map<String, dynamic> ubicacion,
    required DateTime fechaLimite,
    required DateTime fechaInicioTrabajo,
    required DateTime fechaFinTrabajo,
    required double precio,
    required String instrucciones,
    required bool requiereUniforme,
    required List<String> implementosUniforme,
    required Map<String, String> contacto,
  }) {
    // Usamos Timestamp.fromDate() con los DateTime no nulos
    final updateData = {
      'titulo': titulo,
      'descripcion': descripcion,
      'empresa': empresa,
      'ubicacion': ubicacion,
      'fechaLimite': Timestamp.fromDate(fechaLimite),
      'fechaInicioTrabajo': Timestamp.fromDate(fechaInicioTrabajo),
      'fechaFinTrabajo': Timestamp.fromDate(fechaFinTrabajo),
      'precio': precio,
      'instrucciones': instrucciones,
      'contacto': contacto,
      'requiereUniforme': requiereUniforme,
      'implementosUniforme': implementosUniforme,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    
    return _trabajos.doc(trabajoId).update(updateData);
  }
  // ---------------------------------


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
