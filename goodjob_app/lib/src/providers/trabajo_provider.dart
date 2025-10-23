import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/src/models/trabajo.dart';
import '/src/services/trabajo_service.dart';

class TrabajoProvider with ChangeNotifier {
  final TrabajoService _service;
  StreamSubscription<QuerySnapshot>? _trabajosSubscription;
  bool _isDisposed = false;

  // ESTADOS DE CARGA Y ERROR AÑADIDOS para el AdminTrabajosScreen
  bool _isLoading =
      true; // Inicialmente es true porque comienza a cargar de inmediato
  bool get isLoading => _isLoading;

  bool _hasError = false;
  bool get hasError => _hasError;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  TrabajoProvider(this._service) {
    _escucharTrabajos();
  }

  List<Trabajo> _trabajos = [];
  List<Trabajo> get trabajos => _trabajos;

  // Filtros opcionales
  EstadoTrabajo? _filtroEstado;
  EstadoTrabajo? get filtroEstado => _filtroEstado;

  // FILTRO DE BÚSQUEDA (Implementación necesaria para AdminTrabajosScreen)
  String _filtroBusqueda = '';
  String get filtroBusqueda => _filtroBusqueda;

  DateTime? _filtroFechaInicio;
  DateTime? _filtroFechaFin;

  void setFiltroBusqueda(String busqueda) {
    if (_filtroBusqueda != busqueda.toLowerCase()) {
      _filtroBusqueda = busqueda.toLowerCase();
      _aplicarFiltros();
    }
  }

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
      // 1. Filtro por estado
      final estadoOk = _filtroEstado == null || t.estado == _filtroEstado;

      // 2. Filtro por fechas (solo si las fechas del filtro están definidas)
      var fechaOk = true;
      if (_filtroFechaInicio != null) {
        fechaOk = fechaOk && t.fechaInicioTrabajo.isAfter(_filtroFechaInicio!);
      }
      if (_filtroFechaFin != null) {
        fechaOk = fechaOk && t.fechaFinTrabajo.isBefore(_filtroFechaFin!);
      }

      // 3. Filtro por búsqueda de texto
      final busquedaOk =
          _filtroBusqueda.isEmpty ||
          t.titulo.toLowerCase().contains(_filtroBusqueda) ||
          t.empresa.toLowerCase().contains(_filtroBusqueda);

      return estadoOk && fechaOk && busquedaOk;
    }).toList();
    _trabajosFiltrados = filtrados;
    notifyListeners();
  }

  List<Trabajo> _trabajosFiltrados = [];
  List<Trabajo> get trabajosFiltrados => _trabajosFiltrados;

  // Escucha los cambios en la colección de trabajos
  void _escucharTrabajos() {
    _trabajosSubscription?.cancel();

    // Al iniciar o reiniciar la escucha, resetear errores y mostrar carga
    if (_trabajos.isEmpty) {
      _isLoading = true; // Solo mostrar carga si la lista está vacía
    }
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    _trabajosSubscription = _service.obtenerTrabajos().listen(
      (snapshot) {
        if (_isDisposed) return;

        // Manejo de datos (éxito)
        _trabajos = snapshot.docs
            .map((doc) => Trabajo.fromFirestore(doc))
            .toList();
        _isLoading = false;
        _hasError = false;
        _aplicarFiltros(); // Esto llama a notifyListeners
      },
      onError: (error) {
        if (_isDisposed) return;

        // Manejo de error
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error de conexión/base de datos: $error';
        notifyListeners();
      },
    );
  }

  // Actualizar la lista de trabajos desde el servicio
  Future<void> actualizarEstado(String trabajoId, EstadoTrabajo estado) async {
    try {
      await _service.actualizarEstado(trabajoId, estado);

      if (!_isDisposed) {
        _hasError = false;
        _errorMessage = '';
        notifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) {
        _hasError = true;
        _errorMessage = 'Error al actualizar el estado del trabajo: $e';
        notifyListeners();
      }
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
