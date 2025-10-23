import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class SeleccionarUbicacionScreen extends StatefulWidget {
  final LatLng initialPosition;
  const SeleccionarUbicacionScreen({super.key, required this.initialPosition});

  @override
  State<SeleccionarUbicacionScreen> createState() => _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState extends State<SeleccionarUbicacionScreen> {
  late MapController _mapController;
  LatLng? _selected;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Usa la posición inicial proporcionada o una ubicación por defecto
    _selected = widget.initialPosition;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnCurrentLocation();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final current = LatLng(position.latitude, position.longitude);
      _mapController.move(current, 15);
      setState(() => _selected = current);
    } catch (_) {
      // Ignoramos los errores silenciosamente para no interrumpir la selección manual.
    }
  }
  Future<void> _buscarDireccion() async {
    final query = _searchCtrl.text;
    if (query.isEmpty) return;
    try {
      final results = await geocoding.locationFromAddress(query);
      if (results.isNotEmpty) {
        final loc = results.first;
        final point = LatLng(loc.latitude, loc.longitude);
        _mapController.move(point, 15);
        setState(() => _selected = point);
      } else {
        // Muestra un mensaje si no se encuentra la dirección
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dirección no encontrada.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al buscar la dirección.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar ubicación')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección exacta...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _buscarDireccion(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF7B0997)),
                  onPressed: _buscarDireccion,
                )
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selected ?? widget.initialPosition,
                initialZoom: 13,
                onTap: (tapPosition, point) {
                  setState(() => _selected = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.goodjob.app',
                ),
                if (_selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 50,
                        height: 50,
                        point: _selected!,
                        child: const Icon(
                          Icons.location_pin, 
                          color: Colors.red, 
                          size: 50
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7B0997),
        onPressed: _selected == null
            ? null
            : () {
                // Devuelve la ubicación seleccionada a la pantalla anterior
                Navigator.of(context).pop(_selected);
              },
        label: const Text(
          'Confirmar Ubicación',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.check, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
