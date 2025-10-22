import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService();

  // Especificar el bucket correcto de Firebase Storage
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://good-job-1.firebasestorage.app',
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Map<String, int> _ordenEtapas = {
    'inicio': 0,
    'medio': 1,
    'final': 2,
  };

  /// Permite subir una evidencia fotográfica y registrar los metadatos
  /// necesarios para la trazabilidad del trabajo.
  /// Retorna la URL de descarga de la imagen o null si hubo un error.
  Future<String?> subirEvidencia({
    required String trabajoId,
    required File imagen,
    required String usuarioId,
    required String etapa,
    required double latitud,
    required double longitud,
    required DateTime capturadaEn,
  }) async {
    try {
      final evidenciasCollection = _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('evidencias');

      final etapaDoc = evidenciasCollection.doc(etapa);
      DocumentSnapshot<Map<String, dynamic>>? etapaSnapshot;

      try {
        etapaSnapshot = await etapaDoc.get();
      } catch (_) {
        etapaSnapshot = null;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          _storage.ref().child('trabajos/$trabajoId/evidencias/$fileName');

      final uploadTask = await ref.putFile(imagen);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      await etapaDoc.set({
        'url': imageUrl,
        'uploadedBy': usuarioId,
        'createdAt': FieldValue.serverTimestamp(),
        'capturadaEn': Timestamp.fromDate(capturadaEn.toUtc()),
        'gps': {
          'lat': latitud,
          'lng': longitud,
        },
        'etapa': etapa,
        'orden': _ordenEtapas[etapa] ?? 999,
        'storagePath': ref.fullPath,
      });

      // Si existía una evidencia previa para la etapa la eliminamos del storage
      final previousData = etapaSnapshot?.data();
      final previousPath = previousData?['storagePath'] as String?;
      final previousUrl = previousData?['url'] as String?;
      if (previousPath != null && previousPath != ref.fullPath) {
        await _storage.ref(previousPath).delete().catchError((_) {});
      } else if (previousUrl != null && previousUrl != imageUrl) {
        await _storage.refFromURL(previousUrl).delete().catchError((_) {});
      }

      return imageUrl;
    } catch (e) {
      return null;
    }
  }

  /// Mostrar evidencias de un trabajo
  /// Retorna un Stream de listas de mapas con los datos de las evidencias
  /// cada mapa contiene el ID del documento y sus datos
  Stream<List<Map<String, dynamic>>> mostrarEvidencias(String trabajoId) {
    return _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('evidencias')
        .snapshots()
        .map((snapshot) {
      final evidencias = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      evidencias.sort((a, b) {
        final aOrden = a['orden'] as int? ?? 999;
        final bOrden = b['orden'] as int? ?? 999;
        return aOrden.compareTo(bOrden);
      });
      return evidencias;
    });
  }

  /// Elimina una evidencia tanto de Firestore como de Firebase Storage
  Future<void> eliminarEvidencia({
    required String trabajoId,
    required String evidenciaId,
    required String imageUrl,
  }) async {
    try {
      final docRef = _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('evidencias')
          .doc(evidenciaId);

      final snapshot = await docRef.get();
      await docRef.delete();

      final data = snapshot.data();
      final storagePath = data?['storagePath'] as String?;

      final ref = storagePath != null
          ? _storage.ref(storagePath)
          : _storage.refFromURL(imageUrl);

      await ref.delete();
    } catch (e) {
      // Ignorar errores de eliminación para no interrumpir el flujo principal
    }
  }

  /// Sube una evidencia de pago para un trabajo
  /// Solo se permite una evidencia de pago por trabajo
  /// Retorna la URL de descarga de la imagen o null si hubo un error
  Future<String?> subirEvidenciaPago({
    required String trabajoId,
    required File imagen,
    required String usuarioId,
  }) async {
    try {
      if (trabajoId.isEmpty) throw Exception('El trabajoId está vacío');
      if (!await imagen.exists()) throw Exception('El archivo no existe');

      final evidenciasCollection = _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('evidenciasPagos');

      final existingDocs = await evidenciasCollection.limit(1).get();
      DocumentSnapshot<Map<String, dynamic>>? existingDoc;
      if (existingDocs.docs.isNotEmpty) {
        existingDoc = existingDocs.docs.first;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_comprobante.jpg';
      final ref =
          _storage.ref().child('trabajos/$trabajoId/evidenciasPagos/$fileName');

      final uploadTask = ref.putFile(imagen);
      final snapshot = await uploadTask.whenComplete(() => null);
      final imageUrl = await snapshot.ref.getDownloadURL();

      if (existingDoc != null) {
        final previousData = existingDoc.data();
        final previousPath = previousData?['storagePath'] as String?;
        if (previousPath != null) {
          await _storage.ref(previousPath).delete().catchError((_) {});
        }
        await existingDoc.reference.delete();
      }

      await evidenciasCollection.add({
        'url': imageUrl,
        'uploadedBy': usuarioId,
        'createdAt': FieldValue.serverTimestamp(),
        'storagePath': ref.fullPath,
      });

      return imageUrl;
    } catch (e, st) {
      print('❌ Error al subir evidencia de pago: $e');
      print(st);
      return null;
    }
  }


  /// Obtiene las evidencias de pago de un trabajo
  /// Retorna un Stream con la lista de evidencias (debe ser solo una)
  Stream<List<Map<String, dynamic>>> mostrarEvidenciasPagos(String trabajoId) {
    return _firestore
        .collection('trabajos')
        .doc(trabajoId)
        .collection('evidenciasPagos')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
  }

  /// Elimina una evidencia de pago
  Future<void> eliminarEvidenciaPago({
    required String trabajoId,
    required String evidenciaId,
  }) async {
    try {
      final docRef = _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('evidenciasPagos')
          .doc(evidenciaId);

      final snapshot = await docRef.get();
      final data = snapshot.data();
      final storagePath = data?['storagePath'] as String?;

      await docRef.delete();

      if (storagePath != null) {
        await _storage.ref(storagePath).delete().catchError((_) {});
      }
    } catch (e) {
      // Ignorar errores de eliminación
    }
  }
}