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

  Future<void> guardarPlantilla({
    required String nombre,
    required Map<String, dynamic> data,
  }) async {
    final payload = <String, dynamic>{
      'nombre': nombre,
      ...data,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    await _plantillasRef.add(payload);
  }
}