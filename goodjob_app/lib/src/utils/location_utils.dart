import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

LatLng? extractLatLngFromUbicacion(Map<String, dynamic>? ubicacion) {
  if (ubicacion == null) return null;

  final dynamic coord = ubicacion['coordenadas'];
  if (coord is GeoPoint) {
    return LatLng(coord.latitude, coord.longitude);
  }

  final lat = ubicacion['lat'];
  final lng = ubicacion['lng'];
  if (lat is num && lng is num) {
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  return null;
}

Map<String, dynamic> buildUbicacionPayload({
  required String direccion,
  required String ciudad,
  required String pais,
  required LatLng coordenadas,
}) {
  final geoPoint = GeoPoint(coordenadas.latitude, coordenadas.longitude);
  return {
    'direccion': direccion,
    'ciudad': ciudad,
    'pais': pais,
    'lat': coordenadas.latitude,
    'lng': coordenadas.longitude,
    'coordenadas': geoPoint,
  };
}