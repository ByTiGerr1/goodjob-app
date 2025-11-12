import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/screens/trabajos_vista_usuario/display_option.dart';
import 'package:goodjob_app/src/screens/trabajos_vista_usuario/trabajos_time_utils.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';

typedef DistanceCalculator = double? Function(Map<String, dynamic> trabajo);

class TrabajosDataProcessor {
  TrabajosDataProcessor({
    required TrabajoService trabajoService,
    Set<String>? trabajosMarcadosPorRevisar,
  }) : _trabajoService = trabajoService,
       _trabajosMarcadosPorRevisar = trabajosMarcadosPorRevisar ?? <String>{};

  final TrabajoService _trabajoService;
  final Set<String> _trabajosMarcadosPorRevisar;

  List<Map<String, dynamic>> prepararTrabajosParaMostrar(
    QuerySnapshot? snapshot,
    DistanceCalculator calcularDistancia,
  ) {
    final trabajosDocs = snapshot?.docs ?? [];
    final trabajosSinProcesar = trabajosDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id};
    }).toList();

    final filtrados = _filtrarTrabajosVigentes(trabajosSinProcesar);

    return filtrados
        .map((trabajo) => {...trabajo, 'distance': calcularDistancia(trabajo)})
        .toList();
  }

  List<Map<String, dynamic>> excluirTrabajosPostulados(
    List<Map<String, dynamic>> trabajos,
    Set<String> postulaciones,
  ) {
    if (postulaciones.isEmpty) {
      return List<Map<String, dynamic>>.from(trabajos);
    }

    return trabajos.where((trabajo) {
      final id = trabajo['id'] as String?;
      if (id == null) return true;
      return !postulaciones.contains(id);
    }).toList();
  }

  void ordenar(
    List<Map<String, dynamic>> trabajos,
    DisplayOption selectedDisplay,
  ) {
    int compareDate(Map<String, dynamic> a, Map<String, dynamic> b) {
      final dateA = getTrabajoStartDateTime(a);
      final dateB = getTrabajoStartDateTime(b);
      return (dateA ?? DateTime.now()).compareTo(dateB ?? DateTime.now());
    }

    int compareCreated(Map<String, dynamic> a, Map<String, dynamic> b) {
      final createdA = (a['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0);
      final createdB = (b['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0);
      return createdA.compareTo(createdB);
    }

    switch (selectedDisplay) {
      case DisplayOption.upcoming:
        trabajos.sort(compareDate);
        break;
      case DisplayOption.recent:
        trabajos.sort((a, b) => compareCreated(b, a));
        break;
    }
  }

  List<Map<String, dynamic>> _filtrarTrabajosVigentes(
    List<Map<String, dynamic>> trabajos,
  ) {
    final ahora = DateTime.now();
    return trabajos.where((trabajo) {
      final fechaFin = getTrabajoEndDateTime(trabajo);
      if (fechaFin != null && !fechaFin.isAfter(ahora)) {
        // --- MODIFICACIÓN ---
        // Se comenta la siguiente línea para evitar el error PERMISSION_DENIED.
        // _marcarTrabajoComoPorRevisar(trabajo);

        return false; // <-- El trabajo igual se ocultará de la lista
      }

      return _estaDisponibleParaPostular(trabajo, ahora);
    }).toList();
  }

  bool _estaDisponibleParaPostular(
    Map<String, dynamic> trabajo,
    DateTime ahora,
  ) {
    final fechaLimite = getFechaLimite(trabajo);
    if (fechaLimite != null && ahora.isAfter(fechaLimite)) return false;

    final camposEstado = <String?>[
      trabajo['estado']?.toString(),
      trabajo['estadoAsignacion']?.toString(),
    ];

    if (camposEstado.any(_estadoIndicaCierre)) {
      return false;
    }

    final postulacionesHabilitadas = trabajo['postulacionesHabilitadas'];
    if (postulacionesHabilitadas is bool && !postulacionesHabilitadas) {
      return false;
    }

    final maxPostulantes = trabajo['maxPostulantes'];
    final totalPostulaciones =
        trabajo['totalPostulaciones'] ?? trabajo['postulacionesActuales'];

    if (maxPostulantes is num && totalPostulaciones is num) {
      if (totalPostulaciones >= maxPostulantes) return false;
    }

    return true;
  }

  bool _estadoIndicaCierre(String? estado) {
    if (estado == null) return false;
    final normalizado = estado.toLowerCase().replaceAll('_', ' ').trim();
    if (normalizado.isEmpty) return false;

    const estadosCerrados = {
      'cerrado',
      'cerrada',
      'cancelado',
      'cancelada',
      'finalizado',
      'finalizada',
      'completado',
      'completada',
      'en curso',
      'en progreso',
      'no disponible',
    };

    return estadosCerrados.contains(normalizado);
  }

  void _marcarTrabajoComoPorRevisar(Map<String, dynamic> trabajo) {
    final id = trabajo['id'] as String?;
    if (id == null) return;

    final estadoActual = trabajo['estado']?.toString().toLowerCase();
    if (estadoActual == EstadoTrabajo.porRevisar.name.toLowerCase()) {
      return;
    }

    if (_trabajosMarcadosPorRevisar.contains(id)) {
      return;
    }

    _trabajosMarcadosPorRevisar.add(id);
    _trabajoService.actualizarEstado(id, EstadoTrabajo.porRevisar).catchError((
      error,
    ) {
      debugPrint('No se pudo actualizar el estado del trabajo $id: $error');
    });
  }
}
