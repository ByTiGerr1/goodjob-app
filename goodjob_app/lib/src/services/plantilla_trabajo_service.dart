import 'package:cloud_firestore/cloud_firestore.dart';

class TrabajoPlantilla {
  TrabajoPlantilla({
    required this.id,
    required this.nombre,
    required this.data,
  });

  final String id;
  final String nombre;
  final Map<String, dynamic> data;
}

class PlantillaTrabajoService {
  PlantillaTrabajoService()
      : _plantillasRef = FirebaseFirestore.instance.collection('trabajoPlantillas');

  final CollectionReference<Map<String, dynamic>> _plantillasRef;

  Future<List<TrabajoPlantilla>> obtenerPlantillas() async {
    final snapshot = await _plantillasRef.orderBy('nombre').get();
    return snapshot.docs
        .map((doc) => TrabajoPlantilla(id: doc.id, nombre: doc.data()['nombre'] as String? ?? 'Sin nombre', data: doc.data()))
        .toList();
  }

  Future<TrabajoPlantilla> guardarPlantilla({
    required String nombre,
    required Map<String, dynamic> data,
  }) async {
    final docRef = _plantillasRef.doc();
    final payload = <String, dynamic>{
      'nombre': nombre,
      ...data,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    await docRef.set(payload);

    // Evitamos realizar una lectura inmediata del documento recién creado
    // porque en algunos dispositivos provocaba bloqueos cuando la conexión
    // quedaba a la espera de la respuesta del servicio nativo de Firestore.
    // En su lugar retornamos un modelo local con los mismos datos.

    final fallbackData = <String, dynamic>{
      ...data,
      'nombre': nombre,
      'actualizadoEn': Timestamp.fromDate(DateTime.now()),
    };

    return TrabajoPlantilla(id: docRef.id, nombre: nombre, data: fallbackData);
  }
}