import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Importar para usar Color

// --- ENUM ESTADO TRABAJO ---
enum EstadoTrabajo {
  activo,
  porConfirmar,
  pendiente,
  enCurso,
  porRevisar,
  porPagar,
  finalizado,
  cancelado,
  rechazado,
}

extension EstadoTrabajoExtension on EstadoTrabajo {
  String get texto {
    switch (this) {
      case EstadoTrabajo.activo: return "Abierto";
      case EstadoTrabajo.porConfirmar: return "Por confirmar";
      case EstadoTrabajo.pendiente: return "Pendiente";
      case EstadoTrabajo.enCurso: return "En curso";
      case EstadoTrabajo.porRevisar: return "Por revisar";
      case EstadoTrabajo.porPagar: return "Por pagar";
      case EstadoTrabajo.finalizado: return "Finalizado";
      case EstadoTrabajo.cancelado: return "Cancelado";
      case EstadoTrabajo.rechazado: return "Rechazado";
    }
  }

  // Colores del Chip (Paleta mejorada)
  Color get colorChip {
    switch (this) {
      case EstadoTrabajo.activo:
      case EstadoTrabajo.enCurso: return Colors.blue.shade100;
      case EstadoTrabajo.porConfirmar: return Colors.orange.shade100;
      case EstadoTrabajo.pendiente: return Colors.yellow.shade100;
      case EstadoTrabajo.porRevisar: return Colors.cyan.shade100;
      case EstadoTrabajo.porPagar: return Colors.purple.shade100;
      case EstadoTrabajo.finalizado: return Colors.grey.shade300;
      case EstadoTrabajo.cancelado: return Colors.red.shade100;
      case EstadoTrabajo.rechazado: return Colors.pink.shade100;
    }
  }

  // Colores del Texto del Chip (Paleta mejorada)
  Color get colorTextoChip {
    switch (this) {
      case EstadoTrabajo.activo:
      case EstadoTrabajo.enCurso: return Colors.blue.shade800;
      case EstadoTrabajo.porConfirmar: return Colors.orange.shade800;
      case EstadoTrabajo.pendiente: return Colors.brown.shade800;
      case EstadoTrabajo.porRevisar: return Colors.cyan.shade900;
      case EstadoTrabajo.porPagar: return Colors.purple.shade800;
      case EstadoTrabajo.finalizado: return Colors.grey.shade800;
      case EstadoTrabajo.cancelado: return Colors.red.shade800;
      case EstadoTrabajo.rechazado: return Colors.pink.shade900;
    }
  }
}

// --- CLASE TRABAJO ---
class Trabajo {
  final String id;
  final String titulo;
  final String descripcion;
  final String empresa;
  final Map<String, dynamic> ubicacion;
  final DateTime? fechaLimite; // Puede ser nulo
  final DateTime fechaInicioTrabajo;
  final DateTime fechaFinTrabajo;
  final double precio;
  final String instrucciones;
  final bool requiereUniforme;
  final List<String> implementosUniforme;
  final Map<String, String> contacto;
  EstadoTrabajo estado; // Cambiado a no final si necesitas modificarlo
  final bool sinFechaLimite;
  final bool pagado;
  final String? trabajadorAsignadoId; // Puede ser nulo
  final String? motivoRechazo; // Puede ser nulo
  final DateTime? creadoEn; // Añadido para completitud
  final DateTime? actualizadoEn; // Añadido para completitud
  final bool destacado; // Añadido para completitud

  // ⚠️ CAMPO AÑADIDO
  final String? imagenPrincipalUrl;

  Trabajo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.empresa,
    required this.ubicacion,
    this.fechaLimite, // Hacer opcional en constructor
    required this.fechaInicioTrabajo,
    required this.fechaFinTrabajo,
    required this.precio,
    required this.instrucciones,
    required this.requiereUniforme,
    required this.implementosUniforme,
    required this.contacto,
    required this.estado,
    this.sinFechaLimite = false,
    this.pagado = false,
    this.trabajadorAsignadoId,
    this.motivoRechazo,
    this.creadoEn, // Añadido
    this.actualizadoEn, // Añadido
    this.destacado = false, // Añadido

    // ⚠️ PARÁMETRO AÑADIDO AL CONSTRUCTOR
    this.imagenPrincipalUrl,
  });

  // --- Helper Interno para Timestamps ---
  static DateTime? _timestampToDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  // --- Helper Interno para Estado ---
  static EstadoTrabajo _parseEstado(String? estadoStr) {
    if (estadoStr == null) return EstadoTrabajo.activo;
    final estadoLower = estadoStr.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (estadoLower == 'abierto') return EstadoTrabajo.activo; // O EstadoTrabajo.abierto si lo defines

    return EstadoTrabajo.values.firstWhere(
        (e) {
          final nombreNormalizado = e.name.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
          // final textoNormalizado = e.texto.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ''); // Podrías comparar con .texto también
          return estadoLower == nombreNormalizado; // || estadoLower == textoNormalizado;
        },
        orElse: () => EstadoTrabajo.activo // Default seguro
    );
  }

  // --- CONSTRUCTOR fromFirestore (usado para leer de Firestore) ---
  factory Trabajo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {}; // Manejo seguro si no hay datos

    return Trabajo(
      id: doc.id,
      titulo: data['titulo'] as String? ?? 'Sin Título',
      descripcion: data['descripcion'] as String? ?? '',
      empresa: data['empresa'] as String? ?? 'Sin Empresa',
      ubicacion: Map<String, dynamic>.from(data['ubicacion'] ?? {}),
      fechaLimite: _timestampToDateTime(data['fechaLimite'] ?? data['fechaLimitePostulacion']), // Maneja campo antiguo
      fechaInicioTrabajo: _timestampToDateTime(data['fechaInicioTrabajo']) ?? DateTime.now(),
      fechaFinTrabajo: _timestampToDateTime(data['fechaFinTrabajo']) ?? DateTime.now().add(const Duration(hours: 1)), // Asegurar fin > inicio
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      instrucciones: data['instrucciones'] as String? ?? '',
      requiereUniforme: data['requiereUniforme'] as bool? ?? false,
      implementosUniforme: List<String>.from(data['implementosUniforme'] ?? []),
      contacto: Map<String, String>.from(data['contacto'] ?? {}),
      estado: _parseEstado(data['estado'] as String?),
      sinFechaLimite: data['sinFechaLimite'] as bool? ?? false,
      pagado: data['pagado'] as bool? ?? false,
      trabajadorAsignadoId: data['trabajadorAsignadoId'] as String?,
      motivoRechazo: data['motivoRechazo'] as String?,
      creadoEn: _timestampToDateTime(data['creadoEn']),
      actualizadoEn: _timestampToDateTime(data['actualizadoEn']),
      destacado: data['destacado'] as bool? ?? false,

      // ⚠️ LEER EL CAMPO DESDE FIRESTORE
      imagenPrincipalUrl: data['imagenPrincipalUrl'] as String?,
    );
  }

  // --- ⚠️ CONSTRUCTOR fromMap (útil para pasar datos entre pantallas) ---
  factory Trabajo.fromMap(String id, Map<String, dynamic> data) {
     // Reutiliza la lógica de fromFirestore si los mapas son idénticos
     // O copia/adapta la lógica aquí:
     return Trabajo(
       id: id, // Usa el ID pasado
       titulo: data['titulo'] as String? ?? 'Sin Título',
       descripcion: data['descripcion'] as String? ?? '',
       empresa: data['empresa'] as String? ?? 'Sin Empresa',
       ubicacion: Map<String, dynamic>.from(data['ubicacion'] ?? {}),
       fechaLimite: _timestampToDateTime(data['fechaLimite'] ?? data['fechaLimitePostulacion']),
       fechaInicioTrabajo: _timestampToDateTime(data['fechaInicioTrabajo']) ?? DateTime.now(),
       fechaFinTrabajo: _timestampToDateTime(data['fechaFinTrabajo']) ?? DateTime.now().add(const Duration(hours: 1)),
       precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
       instrucciones: data['instrucciones'] as String? ?? '',
       requiereUniforme: data['requiereUniforme'] as bool? ?? false,
       implementosUniforme: List<String>.from(data['implementosUniforme'] ?? []),
       contacto: Map<String, String>.from(data['contacto'] ?? {}),
       estado: _parseEstado(data['estado'] as String?),
       sinFechaLimite: data['sinFechaLimite'] as bool? ?? false,
       pagado: data['pagado'] as bool? ?? false,
       trabajadorAsignadoId: data['trabajadorAsignadoId'] as String?,
       motivoRechazo: data['motivoRechazo'] as String?,
       creadoEn: _timestampToDateTime(data['creadoEn']),
       actualizadoEn: _timestampToDateTime(data['actualizadoEn']),
       destacado: data['destacado'] as bool? ?? false,

       // ⚠️ LEER EL CAMPO DESDE EL MAPA
       imagenPrincipalUrl: data['imagenPrincipalUrl'] as String?,
     );
   }


  // --- MÉTODO toMap (útil para guardar/actualizar en Firestore) ---
  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{ // Usar inferencia de tipo
      'titulo': titulo,
      'descripcion': descripcion,
      'empresa': empresa,
      'ubicacion': ubicacion,
      'fechaInicioTrabajo': Timestamp.fromDate(fechaInicioTrabajo),
      'fechaFinTrabajo': Timestamp.fromDate(fechaFinTrabajo),
      'precio': precio,
      'instrucciones': instrucciones,
      'requiereUniforme': requiereUniforme,
      'implementosUniforme': implementosUniforme,
      'contacto': contacto,
      // Guarda 'abierto' o el nombre del enum
      'estado': estado == EstadoTrabajo.activo && sinFechaLimite ? 'abierto' : estado.name,
      'sinFechaLimite': sinFechaLimite,
      'pagado': pagado,
      'destacado': destacado, // Añadido
      'actualizadoEn': FieldValue.serverTimestamp(), // Siempre se actualiza
      // Campos opcionales (solo incluir si no son null)
      if (trabajadorAsignadoId != null) 'trabajadorAsignadoId': trabajadorAsignadoId,
      if (motivoRechazo != null) 'motivoRechazo': motivoRechazo,

      // ⚠️ GUARDAR EL CAMPO EN FIRESTORE
      'imagenPrincipalUrl': imagenPrincipalUrl,
    };

    // Añadir fechaLimite solo si aplica
    if (fechaLimite != null && !sinFechaLimite) {
      data['fechaLimite'] = Timestamp.fromDate(fechaLimite!);
    }
    // No añadir 'creadoEn' aquí, se maneja en el servicio al crear

    return data;
  }
}