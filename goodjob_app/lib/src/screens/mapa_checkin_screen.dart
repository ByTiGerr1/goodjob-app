import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:goodjob_app/src/utils/location_utils.dart';

import 'trabajo_en_curso_screen.dart'; // Importamos la nueva pantalla

class MapaCheckinScreen extends StatefulWidget {
 final String trabajoId;
 final Map<String, dynamic> trabajo;

 const MapaCheckinScreen({
  super.key,
  required this.trabajoId,
  required this.trabajo,
 });

 @override
 State<MapaCheckinScreen> createState() => _MapaCheckinScreenState();
}

class _MapaCheckinScreenState extends State<MapaCheckinScreen> {
 LatLng? _currentPosition;
 late LatLng _trabajoCoords;
 final MapController _mapController = MapController();
 
  // --- MODO DE PRUEBA: Cambia a 'false' en producción ---
  // Si es true, el check-in se puede realizar sin estar dentro de la zona delimitada.
  final bool _testingMode = false;

  // --- CONFIGURACIÓN DE LA ZONA DELIMITADA ---
  // Establece un radio de 100 metros (personalizable)
  static const double _CHECKIN_RADIUS_METERS = 100.0;
  // Color Morado principal
  static const Color _PRIMARY_COLOR = AppColors.primary;

  DateTime? _scheduledStartTime;
  DateTime? _scheduledEndTime;

  @override
  void initState() {
    super.initState();
    _parseTrabajoCoords();
    _scheduledStartTime = _extractStartDateTime(widget.trabajo);
    _scheduledEndTime = _extractEndDateTime(widget.trabajo);
    _getCurrentLocationAndStartListening();
  }

  @override
  void dispose() {
    // Es importante detener cualquier stream de ubicación que no se cierre solo
    super.dispose();
  }

  void _parseTrabajoCoords() {
    // Lectura robusta de las coordenadas del trabajo
    final ubicacion = widget.trabajo['ubicacion'] as Map<String, dynamic>?;
    final coords = extractLatLngFromUbicacion(ubicacion);

    if (coords != null) {
      _trabajoCoords = coords;
    } else {
      // Fallback si no hay coordenadas válidas (ej. centro de Santiago, Chile)
      _trabajoCoords = const LatLng(-33.447487, -70.673676);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No se encontraron coordenadas válidas para el trabajo. Usando ubicación predeterminada.')),
        );
      });
    }
  }

  Future<void> _getCurrentLocationAndStartListening() async {
    // Si estamos en modo de prueba, no necesitamos permisos obligatorios.
    if (_testingMode) {
      // Simular ubicación para que el mapa se vea mejor
      _currentPosition = _trabajoCoords;
      return;
    }

    // 1. Verificar y solicitar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Permiso de ubicación denegado. No se puede realizar el check-in.')),
        );
      }
      return;
    }

    // 2. Obtener la posición inicial
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
      // Mover el mapa a la ubicación del usuario o del trabajo
      _mapController.move(_currentPosition ?? _trabajoCoords, 17.0);

      // 3. (Opcional) Escuchar cambios de ubicación para actualizar el marcador del usuario
      Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Actualizar cada 10 metros
      )).listen((Position position) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener la ubicación: $e')),
        );
      }
    }
  }

  // Lógica de Geovalla (anulada en modo de prueba)
  bool _isInsideGeofence() {
    if (_testingMode) return true; // Permite el check-in en modo de prueba

    if (_currentPosition == null) return false;

    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _trabajoCoords.latitude,
      _trabajoCoords.longitude,
    );

    return distanceInMeters <= _CHECKIN_RADIUS_METERS;
  }

  bool _isWithinSchedule() {
    final start = _scheduledStartTime;
    if (start == null) return true;

    final now = DateTime.now();
    final end = _scheduledEndTime ??
        DateTime(start.year, start.month, start.day, 23, 59, 59);

    if (now.isBefore(start)) {
      return false;
    }

    if (now.isAfter(end)) {
      return false;
    }

    return true;
  }

  DateTime? _extractStartDateTime(Map<String, dynamic> trabajo) {
    final fechaInicio = _parseDateTime(trabajo['fechaInicioTrabajo']);
    if (fechaInicio != null) {
      return fechaInicio;
    }

    final fechaTrabajo = _parseDateTime(trabajo['fechaTrabajo']);
    final horaInicio = _timeOfDayFromData(trabajo['horaInicio']);

    if (fechaTrabajo != null && horaInicio != null) {
      return DateTime(fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day,
          horaInicio.hour, horaInicio.minute);
    }

    return fechaTrabajo;
  }

  DateTime? _extractEndDateTime(Map<String, dynamic> trabajo) {
    final fechaFin = _parseDateTime(trabajo['fechaFinTrabajo']);
    if (fechaFin != null) {
      return fechaFin;
    }

    final fechaTrabajo = _parseDateTime(trabajo['fechaTrabajo']);
    final horaFin = _timeOfDayFromData(trabajo['horaFin']);

    if (fechaTrabajo != null && horaFin != null) {
      return DateTime(fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day,
          horaFin.hour, horaFin.minute);
    }

    return fechaFin;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  TimeOfDay? _timeOfDayFromData(dynamic value) {
    if (value is Map) {
      final hour = value['hour'] ?? value['h'];
      final minute = value['minute'] ?? value['m'];
      if (hour is num && minute is num) {
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
      }
    } else if (value is List && value.length >= 2) {
      final hour = value[0];
      final minute = value[1];
      if (hour is num && minute is num) {
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
      }
    } else if (value is String && value.contains(':')) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
    return null;
  }

  String _scheduleStatusMessage(bool isWithinSchedule) {
    if (_testingMode) {
      return '⚠️ MODO PRUEBA: Check-in habilitado';
    }

    if (!isWithinSchedule) {
      final start = _scheduledStartTime;
      if (start == null) {
        return 'No se pudo validar la fecha y hora del trabajo.';
      }

      final now = DateTime.now();
      if (now.isBefore(start)) {
        final formatted = _formatDateTime(start);
        return 'El trabajo comienza el $formatted. Aún no puedes iniciar.';
      }

      final end = _scheduledEndTime ??
          DateTime(start.year, start.month, start.day, 23, 59, 59);
      if (now.isAfter(end)) {
        return 'El horario del trabajo ya finalizó.';
      }

      return 'Verifica el horario del trabajo para iniciar.';
    }

    return '¡Estás dentro del horario del trabajo!';
  }

  String _locationStatusMessage(bool isInside) {
    if (_testingMode) {
      return '⚠️ MODO PRUEBA: Check-in habilitado';
    }

    if (isInside) {
      return '¡Estás dentro de la zona de check-in!';
    }

    return 'Muévete dentro del círculo para hacer check-in.';
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year a las $hour:$minute';
  }

  void _performCheckIn() {
    // Si no estamos en modo de prueba, aplica la restricción
    if (!_testingMode && !_isWithinSchedule()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _scheduleStatusMessage(false),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_testingMode && !_isInsideGeofence()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes estar dentro del círculo delimitado para hacer check-in.',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // --- LÓGICA DE INICIO DE TRABAJO ---
    final DateTime startTime = DateTime.now();

    // Simulación de guardado en Firestore y actualización de estado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Check-in realizado! Iniciando trabajo...',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
      ),
    );

    // Navegar a la nueva pantalla de trabajo en curso, pasando la hora de inicio.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TrabajoEnCursoScreen(
          trabajoId: widget.trabajoId,
          trabajo: widget.trabajo,
          startTime: startTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInside = _isInsideGeofence();
    final isWithinSchedule = _isWithinSchedule();
    final buttonActive =
        _testingMode || (isInside && isWithinSchedule);
    final buttonColor = buttonActive ? Colors.green.shade600 : Colors.grey;
    final scheduleMessage = _scheduleStatusMessage(isWithinSchedule);
    final locationMessage = _locationStatusMessage(isInside);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in del Trabajo'),
        backgroundColor: _PRIMARY_COLOR,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _trabajoCoords,
              initialZoom: 17.0,
              maxZoom: 19.0,
              minZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.goodjob.app',
              ),

              // ZONA DELIMITADA (Geovalla - Geofence)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _trabajoCoords,
                    radius: _CHECKIN_RADIUS_METERS, // Radio en metros
                    color: _PRIMARY_COLOR.withOpacity(0.15),
                    borderColor: _PRIMARY_COLOR.withOpacity(0.8),
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                  ),
                ],
              ),

              // MARCADOR DEL TRABAJO
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _trabajoCoords,
                    child:
                        const Icon(Icons.work, color: _PRIMARY_COLOR, size: 40),
                  ),
                ],
              ),

              // MARCADOR DE LA UBICACIÓN DEL USUARIO
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: _currentPosition!,
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.blue, size: 40),
                    ),
                  ],
                ),
            ],
          ),

          // Botón de Check-in en la parte inferior
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: buttonActive
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        scheduleMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (isWithinSchedule || _testingMode)
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locationMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _testingMode
                              ? Colors.orange.shade800
                              : (isInside
                                  ? Colors.green.shade800
                                  : Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: buttonActive ? _performCheckIn : null,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('HACER CHECK-IN'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Botón para centrar en el usuario
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'centerUser',
              backgroundColor: _PRIMARY_COLOR,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 17.0);
                } else {
                  _mapController.move(_trabajoCoords, 17.0);
                }
              },
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
