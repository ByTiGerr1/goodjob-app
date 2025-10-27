import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Necesario para TimeOfDay (asumiendo que está aquí)
import 'package:goodjob_app/src/models/trabajo.dart'; // Asumiendo que contiene EstadoTrabajo

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

  Future<Trabajo?> obtenerDatosTrabajo(String trabajoId) async {
    try {
      final docSnapshot = await _trabajos.doc(trabajoId).get();

      if (docSnapshot.exists) {
        // Usamos tu modelo Trabajo para parsear los datos
        return Trabajo.fromFirestore(docSnapshot);
      } else {
        debugPrint('No se encontró el trabajo con ID: $trabajoId');
        return null;
      }
    } catch (e) {
      debugPrint('Error al obtener datos del trabajo $trabajoId: $e');
      rethrow; // Lanza el error para que el FutureBuilder lo maneje
    }
  }

  Stream<QuerySnapshot> obtenerTrabajosTerminadosRecientes({int limite = 10}) {
    return _trabajos
        .where('estado', isEqualTo: EstadoTrabajo.porRevisar.name) // Filtra por 'finalizado'
        .orderBy('actualizadoEn', descending: true) // Ordena por fecha de finalización
        .limit(limite) // Limita los resultados
        .snapshots();
  }

  /// Creates a new job document in Firestore.
  Future<String> crearTrabajo({
    required String titulo,
    required String descripcion,
    required String empresa,
    required Map<String, dynamic> ubicacion,
    DateTime? fechaLimite,
    required DateTime fechaInicioTrabajo,
    required DateTime fechaFinTrabajo,
    required double precio,
    required String instrucciones,
    required bool requiereUniforme,
    required List<String> implementosUniforme,
    required Map<String, String> contacto,
    bool sinFechaLimite = false,
    bool destacado = false,
    String? imagenPrincipalUrl, // AÑADIDO: URL de la imagen principal
    String? trabajoId,
  }) async {
    // Usamos Timestamp.fromDate() con los DateTime no nulos que vienen del Canvas
    final data = {
      'titulo': titulo,
      'descripcion': descripcion,
      'empresa': empresa,
      'ubicacion': ubicacion,
      'fechaInicioTrabajo': Timestamp.fromDate(fechaInicioTrabajo),
      'fechaFinTrabajo': Timestamp.fromDate(fechaFinTrabajo),
      'precio': precio,
      'instrucciones': instrucciones,
      
      'contacto': contacto,
      'requiereUniforme': requiereUniforme,
      'implementosUniforme': implementosUniforme,

      'destacado': destacado,
      'estado': sinFechaLimite ? 'abierto' : EstadoTrabajo.activo.name, // Estado default
      'creadoEn': FieldValue.serverTimestamp(),
      'sinFechaLimite': sinFechaLimite,
      'imagenPrincipalUrl': imagenPrincipalUrl, // Guardar la URL de la imagen
    };

    if (fechaLimite != null && !sinFechaLimite) {
      data['fechaLimite'] = Timestamp.fromDate(fechaLimite);
    }

    if (trabajoId != null) {
      await _trabajos.doc(trabajoId).set(data);
      return trabajoId;
    } else {
      final docRef = await _trabajos.add(data);
      return docRef.id;
    }
  }

  /// Updates an existing job document in Firestore.
  Future<void> actualizarTrabajo({
    required String trabajoId,
    required String titulo,
    required String descripcion,
    required String empresa,
    required Map<String, dynamic> ubicacion,
    DateTime? fechaLimite,
    required DateTime fechaInicioTrabajo,
    required DateTime fechaFinTrabajo,
    required double precio,
    required String instrucciones,
    required bool requiereUniforme,
    required List<String> implementosUniforme,
    required Map<String, String> contacto,
    bool sinFechaLimite = false,
    String? imagenPrincipalUrl, // AÑADIDO: URL de la imagen principal
  }) async {
    // Usamos Timestamp.fromDate() con los DateTime no nulos
    final updateData = {
      'titulo': titulo,
      'descripcion': descripcion,
      'empresa': empresa,
      'ubicacion': ubicacion,
      'fechaInicioTrabajo': Timestamp.fromDate(fechaInicioTrabajo),
      'fechaFinTrabajo': Timestamp.fromDate(fechaFinTrabajo),
      'precio': precio,
      'instrucciones': instrucciones,
      'contacto': contacto,
      'requiereUniforme': requiereUniforme,
      'implementosUniforme': implementosUniforme,
      'actualizadoEn': FieldValue.serverTimestamp(),
      'sinFechaLimite': sinFechaLimite,
      'imagenPrincipalUrl': imagenPrincipalUrl, // Guardar la URL de la imagen
    };

    if (fechaLimite != null && !sinFechaLimite) {
      updateData['fechaLimite'] = Timestamp.fromDate(fechaLimite);
    } else {
      updateData['fechaLimite'] = FieldValue.delete();
      updateData['fechaLimitePostulacion'] = FieldValue.delete();
    }

    await _trabajos.doc(trabajoId).update(updateData);
  }
  
  /// Updates the status of a job.
  Future<void> actualizarEstado(String trabajoId, EstadoTrabajo estado) {
    return _trabajos.doc(trabajoId).update({
      'estado': estado.name,
      'actualizadoEn': FieldValue.serverTimestamp(), // <-- AÑADIDO
    });
  }

  /// Updates the status of a job to 'finalizado' and marks it as paid.
  Future<void> finalizarYMarcarComoPagado(String trabajoId) {
    return _trabajos.doc(trabajoId).update({
      'estado': EstadoTrabajo.finalizado.name,
      'pagado': true,
      'actualizadoEn': FieldValue.serverTimestamp(), // <-- AÑADIDO
    });
  }

  /// Cancels a job by updating its state to 'cancelado'.
  Future<void> cancelarTrabajo(String trabajoId) {
    return _trabajos.doc(trabajoId).update({'estado': EstadoTrabajo.cancelado.name});
  }

Future<void> actualizarCamposTrabajo(String trabajoId, Map<String, dynamic> data) async {
  try {
    // Si pasamos un enum, lo convertimos a string
    if (data['estado'] is EstadoTrabajo) {
      data['estado'] = (data['estado'] as EstadoTrabajo).name;
    }

    // Aseguramos que la fecha de actualización siempre esté presente
    data['actualizadoEn'] = FieldValue.serverTimestamp(); // <-- AÑADIDO

    await _trabajos.doc(trabajoId).update(data);
  } catch (e) {
    debugPrint('Error al actualizar campos del trabajo: $e');
    rethrow; // Lanza el error para que la UI lo maneje
  }
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
