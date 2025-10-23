import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Importar para usar Color

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
      case EstadoTrabajo.activo:
        return "Abierto";
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
      case EstadoTrabajo.rechazado:
        return "Rechazado";
    }
  }

  // UX: Color de fondo claro para el chip - PALETA MEJORADA PARA DISTINCIÓN Y CONTRASTE
  Color get colorChip {
    switch (this) {
      case EstadoTrabajo.activo:
        return Colors.green.shade100; // Verde claro (Éxito/Disponible)
      case EstadoTrabajo.enCurso:
        return Colors.blue.shade100; // Azul claro (Proceso Activo)
      case EstadoTrabajo.porConfirmar:
        return Colors.orange.shade100; // Naranja claro (Advertencia, requiere acción)
      case EstadoTrabajo.pendiente:
        return Colors.yellow.shade100; // Amarillo claro (Esperando)
      case EstadoTrabajo.porRevisar:
        return Colors.cyan.shade100; // Cian claro (Necesita atención)
      case EstadoTrabajo.porPagar:
        return Colors.purple.shade100; // Púrpura claro (Acción financiera)
      case EstadoTrabajo.finalizado:
        return Colors.grey.shade300; // Gris medio (Completado, historial)
      case EstadoTrabajo.cancelado:
        return Colors.red.shade100; // Rojo claro (Fallo/Interrumpido)
      case EstadoTrabajo.rechazado:
        return Colors.pink.shade100; // Rosa claro (Decisión final/Rechazo - Distinto de Cancelado)
    }
  }

  // UX: Color de texto oscuro para el chip - PALETA MEJORADA PARA CONTRASTE
  Color get colorTextoChip {
    switch (this) {
      case EstadoTrabajo.activo:
        return Colors.green.shade800; 
      case EstadoTrabajo.enCurso:
        return Colors.blue.shade800;
      case EstadoTrabajo.porConfirmar:
        return Colors.orange.shade800;
      case EstadoTrabajo.pendiente:
        return Colors.brown.shade800; // Cambiado a Marrón oscuro para un contraste superior sobre Amarillo claro
      case EstadoTrabajo.porRevisar:
        return Colors.cyan.shade900;
      case EstadoTrabajo.porPagar:
        return Colors.purple.shade800;
      case EstadoTrabajo.finalizado:
        return Colors.grey.shade800;
      case EstadoTrabajo.cancelado:
        return Colors.red.shade800;
      case EstadoTrabajo.rechazado:
        return Colors.pink.shade900; // Magenta oscuro (Distinto de Rojo estándar)
    }
  }
}

class Trabajo {
  final String id;
  final String titulo;
  final String descripcion;
  final String empresa;
  final Map<String, dynamic> ubicacion;
  final DateTime? fechaLimite;
  final DateTime fechaInicioTrabajo;
  final DateTime fechaFinTrabajo;
  final double precio;
  final String instrucciones;
  final bool requiereUniforme;
  final List<String> implementosUniforme;
  final Map<String, String> contacto;
  EstadoTrabajo estado;
  final bool sinFechaLimite;
  final bool pagado;

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
    this.sinFechaLimite = false,
    this.pagado = false,
  });

  factory Trabajo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Determinar el estado del trabajo (soporta tanto 'name' como 'texto')
    EstadoTrabajo estado;
    try {
      final estadoData = data['estado'] as String?;
      if (estadoData != null) {
        final estadoLower = estadoData.toLowerCase();
        if (estadoLower == 'abierto') {
          estado = EstadoTrabajo.activo;
        } else {
          // Intentar primero por name (ej: "activo", "porConfirmar")
          estado = EstadoTrabajo.values.firstWhere(
            (e) => e.name == estadoLower,
            orElse: () {
              // Si no funciona, intentar por texto (ej: "Activo", "Por confirmar")
              return EstadoTrabajo.values.firstWhere(
                (e) => e.texto.toLowerCase() == estadoLower,
                orElse: () => EstadoTrabajo.activo,
              );
            },
          );
        }
      } else {
        estado = EstadoTrabajo.activo;
      }
    } catch (e) {
      estado = EstadoTrabajo.activo;
    }
    
    return Trabajo(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      descripcion: data['descripcion'] ?? '',
      empresa: data['empresa'] ?? '',
      ubicacion: data['ubicacion'] ?? {},
      fechaLimite: (data['fechaLimite'] as Timestamp?)?.toDate(),
      fechaInicioTrabajo: (data['fechaInicioTrabajo'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaFinTrabajo: (data['fechaFinTrabajo'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 8)),
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      instrucciones: data['instrucciones'] ?? '',
      requiereUniforme: data['requiereUniforme'] ?? false,
      implementosUniforme: List<String>.from(data['implementosUniforme'] ?? []),
      contacto: Map<String, String>.from(data['contacto'] ?? {}),
      estado: estado,
      sinFechaLimite: data['sinFechaLimite'] == true,
      pagado: data['pagado'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    final data = {
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
      'estado': estado == EstadoTrabajo.activo && sinFechaLimite ? 'abierto' : estado.name, // Usar .name para consistencia
      'sinFechaLimite': sinFechaLimite,
      'pagado': pagado,
    };
    if (fechaLimite != null && !sinFechaLimite) {
      data['fechaLimite'] = Timestamp.fromDate(fechaLimite!);
    }
    return data;
  }
}
