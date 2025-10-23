import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Servicio encargado de la gestión de archivos (Firebase Storage)
/// y la persistencia de sus metadatos (Cloud Firestore).
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

  // -----------------------------------------------------------------
  // LÓGICA DE GESTIÓN DE FOTOS DE PERFIL (Regla: /profile_pictures/{userId}/...)
  // -----------------------------------------------------------------

  /// Sube la foto de perfil del usuario.
  /// La subida es destructiva (sobrescribe la anterior).
  /// Retorna la URL de descarga o null en caso de error.
  Future<String?> subirFotoPerfil({
    required String userId,
    required File imagen,
  }) async {
    try {
      if (userId.isEmpty) throw Exception('El userId está vacío');
      if (!await imagen.exists()) throw Exception('El archivo de imagen no existe');

      // 1. Definir la ruta fija: profile_pictures/{userId}/profile_photo.jpg
      final ref = _storage
          .ref()
          .child('profile_pictures') 
          .child(userId)
          .child('profile_photo.jpg'); // Nombre de archivo fijo para sobrescribir

      // 2. Subir el archivo
      final uploadTask = ref.putFile(imagen);
      await uploadTask.whenComplete(() {});

      // 3. Obtener y retornar la URL
      final imageUrl = await ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      // Manejo de errores
      print('❌ Error al subir foto de perfil: $e');
      return null;
    }
  }

  // -----------------------------------------------------------------
  // LÓGICA DE GESTIÓN DE IMAGEN PRINCIPAL DE TRABAJO 
  // -----------------------------------------------------------------

  /// Sube la imagen principal o de portada para un trabajo.
  Future<String?> subirImagenPrincipal({
    required String trabajoId,
    required File imagen,
  }) async {
    try {
      if (trabajoId.isEmpty) throw Exception('El trabajoId está vacío');
      
      // 1. Definir la RUTA LIMPIA: trabajos/{trabajoId}/principal/cover_image.jpg
      final ref = _storage
          .ref()
          .child('trabajos')
          .child(trabajoId)
          .child('principal') // NUEVA SUB-CARPETA
          .child('cover_image.jpg'); // Nombre fijo para sobrescribir si se edita

      // 2. Subir el archivo
      final uploadTask = await ref.putFile(imagen);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      // NOTA: La URL obtenida debe ser guardada en el documento del trabajo por el 'TrabajoService'.

      return imageUrl;
    } catch (e) {
      print('❌ Error al subir imagen principal del trabajo: $e');
      return null;
    }
  }


  // -----------------------------------------------------------------
  // LÓGICA EXISTENTE: EVIDENCIAS DE ETAPA (INICIO, MEDIO, FINAL)
  // -----------------------------------------------------------------

  /// Permite subir una evidencia fotográfica y registrar los metadatos
  /// necesarios para la trazabilidad del trabajo (GPS, hora, etapa).
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

      // El ID del documento es la etapa (inicio, medio, final) para garantizar 
      // que solo exista una evidencia por etapa.
      final etapaDoc = evidenciasCollection.doc(etapa);
      DocumentSnapshot<Map<String, dynamic>>? etapaSnapshot;

      try {
        etapaSnapshot = await etapaDoc.get();
      } catch (_) {
        etapaSnapshot = null;
      }

      // 1. Subir a Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          _storage.ref().child('trabajos/$trabajoId/evidencias/$fileName'); 

      final uploadTask = await ref.putFile(imagen);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      // 2. Guardar Metadatos en Firestore (sobrescribe la metadata si existe)
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

      // 3. Eliminar evidencia previa del Storage si existía
      final previousData = etapaSnapshot?.data();
      final previousPath = previousData?['storagePath'] as String?;
      final previousUrl = previousData?['url'] as String?;
      
      if (previousPath != null && previousPath != ref.fullPath) {
        await _storage.ref(previousPath).delete().catchError((_) {});
      } else if (previousUrl != null && previousUrl != imageUrl) {
        // Fallback si solo se guardó la URL y no el path
        await _storage.refFromURL(previousUrl).delete().catchError((_) {});
      }

      return imageUrl;
    } catch (e) {
      print('❌ Error al subir evidencia de etapa: $e');
      return null;
    }
  }

  /// Mostrar evidencias de un trabajo
  /// Retorna un Stream de listas de mapas con los datos de las evidencias
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
      
      // Ordenar por el mapa de etapas (Inicio, Medio, Final)
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
    required String evidenciaId, // Corresponde al nombre de la etapa
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

      await ref.delete().catchError((_) {}); // Ignorar errores de eliminación de Storage
    } catch (e) {
       print('❌ Error al eliminar evidencia de etapa: $e');
    }
  }

  // -----------------------------------------------------------------
  // LÓGICA EXISTENTE: COMPROBANTE DE PAGO (Regla: /trabajos/{trabajoId}/evidenciasPagos/...)
  // -----------------------------------------------------------------

  /// Sube una evidencia de pago para un trabajo (solo se permite una).
  /// Retorna la URL de descarga de la imagen o null si hubo un error.
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

      // Buscar si ya existe un comprobante (debería ser solo uno)
      final existingDocs = await evidenciasCollection.limit(1).get();
      DocumentSnapshot<Map<String, dynamic>>? existingDoc;
      if (existingDocs.docs.isNotEmpty) {
        existingDoc = existingDocs.docs.first;
      }

      // 1. Subir a Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_comprobante.jpg';
      final ref =
          _storage.ref().child('trabajos/$trabajoId/evidenciasPagos/$fileName');

      final uploadTask = ref.putFile(imagen);
      final snapshot = await uploadTask.whenComplete(() => null);
      final imageUrl = await snapshot.ref.getDownloadURL();

      // 2. Eliminar el archivo y el registro anterior (si existe)
      if (existingDoc != null) {
        final previousData = existingDoc.data();
        final previousPath = previousData?['storagePath'] as String?;
        
        if (previousPath != null) {
          await _storage.ref(previousPath).delete().catchError((_) {});
        }
        await existingDoc.reference.delete(); // Eliminar registro de Firestore
      }

      // 3. Guardar el nuevo registro en Firestore
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
      print('❌ Error al eliminar evidencia de pago: $e');
    }
  }
}
