import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:goodjob_app/src/utils/location_utils.dart';
import 'package:latlong2/latlong.dart';

class TrabajosMapCoordinator {
  TrabajosMapCoordinator({
    required LatLng defaultLocation,
  })  : _defaultLocation = defaultLocation,
        _mapController = MapController();

  final LatLng _defaultLocation;
  final MapController _mapController;
  Position? currentPosition;

  MapController get mapController => _mapController;

  bool get isMapReady =>
      _mapController is MapControllerImpl &&
      (_mapController).value.options != null;

  LatLng get initialCenter => currentPosition != null
      ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
      : _defaultLocation;

  double get initialZoom => currentPosition != null ? 14.0 : 5.0;

  Future<void> loadUserPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      currentPosition = position;
      if (isMapReady) {
        centerOnUserPosition();
      }
    } catch (_) {
      // Ignorar errores de ubicación
    }
  }

  void centerOnUserPosition() {
    if (currentPosition == null || !isMapReady) return;
    final dest = LatLng(currentPosition!.latitude, currentPosition!.longitude);
    _mapController.move(dest, 16.0);
  }

  void centerOnTrabajo(Map<String, dynamic> trabajo) {
    if (!isMapReady) return;
    final ubicacion = trabajo['ubicacion'] as Map<String, dynamic>?;
    final coords = extractLatLngFromUbicacion(ubicacion);
    if (coords == null) return;
    _mapController.move(coords, 17.0);
  }

  double? calculateDistance(Map<String, dynamic> trabajo) {
    final origin = currentPosition;
    if (origin == null) return null;
    final ubicacion = trabajo['ubicacion'] as Map<String, dynamic>?;
    final coords = extractLatLngFromUbicacion(ubicacion);
    if (coords == null) return null;
    return Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          coords.latitude,
          coords.longitude,
        ) /
        1000;
  }
}

