import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoTrabajo { 
  activo,
  porConfirmar,
  pendiente,
  enCurso,
  porRevisar,
  porPagar,
  finalizado,
  cancelado, 
}
extension EstadoTrabajoExtension on EstadoTrabajo {
  String get texto {
    switch (this) {
      case EstadoTrabajo.activo:
        return "Activo";
      case EstadoTrabajo.porConfirmar:
        return "Por confirmar";
      case EstadoTrabajo.pendiente:
        return "Pendiente";
      case EstadoTrabajo.enCurso:
        return "En curso";
      case EstadoTrabajo.porRevisar:
        return "Por revisar";
      case EstadoTrabajo.porPagar:
        return "Por pagar";
      case EstadoTrabajo.finalizado:
        return "Finalizado";
      case EstadoTrabajo.cancelado:
        return "Cancelado";
    }
  }
}

class Trabajo {
  final String id;
  final String titulo;
  final String descripcion;
  final String empresa;
  final Map<String, dynamic> ubicacion;
  final DateTime fechaLimite;
  final DateTime fechaInicioTrabajo;
  final DateTime fechaFinTrabajo;
  final double precio;
  final String instrucciones;
  final bool requiereUniforme;
  final List<String> implementosUniforme;
  final Map<String, String> contacto;
  EstadoTrabajo estado;
  final bool destacado;

  Trabajo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.empresa,
    required this.ubicacion,
    required this.fechaLimite,
    required this.fechaInicioTrabajo,
    required this.fechaFinTrabajo,
    required this.precio,
    required this.instrucciones,
    required this.requiereUniforme,
    required this.implementosUniforme,
    required this.contacto,
    required this.estado,
    required this.destacado,
  });

  factory Trabajo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Trabajo(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      empresa: data['empresa'] ?? '',
      ubicacion: data['ubicacion'] ?? {},
      fechaLimite: (data['fechaLimite'] as Timestamp).toDate(),
      fechaInicioTrabajo: (data['fechaInicioTrabajo'] as Timestamp).toDate(),
      fechaFinTrabajo: (data['fechaFinTrabajo'] as Timestamp).toDate(),
      precio: (data['precio'] as num).toDouble(),
      instrucciones: data['instrucciones'] ?? '',
      requiereUniforme: data['requiereUniforme'] ?? false,
      implementosUniforme: List<String>.from(data['implementosUniforme'] ?? []),
      contacto: Map<String, String>.from(data['contacto'] ?? {}),
      estado: EstadoTrabajo.values.firstWhere(
        (e) => e.texto == data['estado'],
        orElse: () => EstadoTrabajo.activo,
      ),
      destacado: data['destacado'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'empresa': empresa,
      'ubicacion': ubicacion,
      'fechaLimite': Timestamp.fromDate(fechaLimite),
      'fechaInicioTrabajo': Timestamp.fromDate(fechaInicioTrabajo),
      'fechaFinTrabajo': Timestamp.fromDate(fechaFinTrabajo),
      'precio': precio,
      'instrucciones': instrucciones,
      'requiereUniforme': requiereUniforme,
      'implementosUniforme': implementosUniforme,
      'contacto': contacto,
      'estado': estado.texto,
      'destacado': destacado,
    };
  }
}