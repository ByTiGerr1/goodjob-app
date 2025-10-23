import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/src/models/trabajo.dart';
import '/src/services/trabajo_service.dart';

class TrabajoProvider with ChangeNotifier {
  final TrabajoService _service;
  StreamSubscription<QuerySnapshot>? _trabajosSubscription;
  bool _isDisposed = false;

  TrabajoProvider(this._service) {
    _escucharTrabajos();
  }

  List<Trabajo> _trabajos = [];
  List<Trabajo> get trabajos => _trabajos;

  // Filtros opcionales
  EstadoTrabajo? _filtroEstado;
  EstadoTrabajo? get filtroEstado => _filtroEstado;

  DateTime? _filtroFechaInicio;
  DateTime? _filtroFechaFin;

  void setFiltroEstado(EstadoTrabajo? estado) {
    _filtroEstado = estado;
    _aplicarFiltros();
  }

  void setFiltroFechas(DateTime? inicio, DateTime? fin) {
    _filtroFechaInicio = inicio;
    _filtroFechaFin = fin;
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    if (_isDisposed) return;

    final filtrados = _trabajos.where((t) {
      // Filtro por estado
      final estadoOk = _filtroEstado == null || t.estado == _filtroEstado;

      // Filtro por fechas (solo si las fechas del filtro están definidas)
      var fechaOk = true;
      if (_filtroFechaInicio != null) {
        fechaOk = fechaOk && t.fechaInicioTrabajo.isAfter(_filtroFechaInicio!);
      }
      if (_filtroFechaFin != null) {
        fechaOk = fechaOk && t.fechaFinTrabajo.isBefore(_filtroFechaFin!);
      }

      return estadoOk && fechaOk;
    }).toList();
    _trabajosFiltrados = filtrados;
    notifyListeners();
  }

  List<Trabajo> _trabajosFiltrados = [];
  List<Trabajo> get trabajosFiltrados => _trabajosFiltrados;

  // Escucha los cambios en la colección de trabajos
  void _escucharTrabajos() {
    _trabajosSubscription?.cancel();
    _trabajosSubscription = _service.obtenerTrabajos().listen((snapshot) {
      if (_isDisposed) return;
      _trabajos =
          snapshot.docs.map((doc) => Trabajo.fromFirestore(doc)).toList();
      _aplicarFiltros();
    });
  }

  // Actualizar la lista de trabajos desde el servicio
  Future<void> actualizarEstado(String trabajoId, EstadoTrabajo estado) async {
    await _service.actualizarEstado(trabajoId, estado);
    if (_isDisposed) return;

    final index = _trabajos.indexWhere((t) => t.id == trabajoId);
    if (index != -1) {
      _trabajos[index].estado = estado;
      _aplicarFiltros();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _trabajosSubscription?.cancel();
    _trabajosSubscription = null;
    super.dispose();
  }
}