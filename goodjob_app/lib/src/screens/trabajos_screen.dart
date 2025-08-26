import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/trabajo_service.dart';
import 'detalle_trabajo_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


enum SortOption {
  distanceAsc,
  distanceDesc,
  priceAsc,
  priceDesc,
  dateDesc,
  dateAsc,
}

class TrabajosScreen extends StatefulWidget {
  const TrabajosScreen({super.key});

  @override
  State<TrabajosScreen> createState() => _TrabajosScreenState();
}

class _TrabajosScreenState extends State<TrabajosScreen> {
  final _servicio = TrabajoService();
  SortOption _sortOption = SortOption.dateDesc;
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  bool _soloHoy = false;
  int _vistaActual = 0; // 0 -> Lista, 1 -> Mapa
  final MapController _mapController = MapController();
  static const LatLng _defaultLocation = LatLng(19.432608, -99.133209);

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = pos);
      _mapController.move(
        LatLng(pos.latitude, pos.longitude),
        12,
      );
    } catch (_) {
      // Ignorar errores de ubicación
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double? _calcularDistancia(Map<String, dynamic> trabajo) {
    if (_currentPosition == null) return null;
    final origen = trabajo['origen'] as Map<String, dynamic>?;
    final lat = origen?['lat'];
    final lng = origen?['lng'];
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          (lat as num).toDouble(),
          (lng as num).toDouble(),
        ) /
        1000;
  }

  void _ordenar(List<Map<String, dynamic>> trabajos) {
    int compareDistance(a, b) =>
        (a['distance'] ?? double.infinity)
            .compareTo(b['distance'] ?? double.infinity);
    int comparePrice(a, b) => (a['precio'] ?? 0).compareTo(b['precio'] ?? 0);
    int compareDate(a, b) =>
        ((a['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0))
            .compareTo((b['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0));

    switch (_sortOption) {
      case SortOption.distanceAsc:
        trabajos.sort(compareDistance);
        break;
      case SortOption.distanceDesc:
        trabajos.sort((a, b) => compareDistance(b, a));
        break;
      case SortOption.priceAsc:
        trabajos.sort(comparePrice);
        break;
      case SortOption.priceDesc:
        trabajos.sort((a, b) => comparePrice(b, a));
        break;
      case SortOption.dateAsc:
        trabajos.sort(compareDate);
        break;
      case SortOption.dateDesc:
        trabajos.sort((a, b) => compareDate(b, a));
        break;
    }
  }

  Widget _buildMapa() {
    return StreamBuilder<QuerySnapshot>(
      stream: _servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay trabajos disponibles'));
        }

        final trabajos = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {...data, 'id': doc.id};
        }).toList();

        final markers = <Marker>[];

        for (final t in trabajos) {
          final origen = t['origen'] as Map<String, dynamic>?;
          final lat = origen?['lat'];
          final lng = origen?['lng'];
          if (lat == null || lng == null) continue;
          final pos = LatLng((lat as num).toDouble(), (lng as num).toDouble());
          markers.add(
            Marker(
              width: 40,
              height: 40,
              point: pos,
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          );
        }

        if (_currentPosition != null) {
          markers.add(
            Marker(
              width: 40,
              height: 40,
              point: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
            ),
          );
        }

        final center = _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : _defaultLocation;

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(markers: markers),
          ],
        );
      },
    );
  }

  Widget _buildSelectorVista() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _vistaActual = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _vistaActual == 0 ? Colors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Lista',
                style: TextStyle(
                  color: _vistaActual == 0 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _vistaActual = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _vistaActual == 1 ? Colors.amber : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Mapa',
                style: TextStyle(
                  color: _vistaActual == 1 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<SortOption>(
                icon: const Icon(Icons.filter_list),
                onSelected: (opt) => setState(() => _sortOption = opt),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: SortOption.distanceAsc,
                      child: Text('Distancia (asc)')),
                  PopupMenuItem(
                      value: SortOption.distanceDesc,
                      child: Text('Distancia (desc)')),
                  PopupMenuItem(
                      value: SortOption.priceAsc,
                      child: Text('Precio (asc)')),
                  PopupMenuItem(
                      value: SortOption.priceDesc,
                      child: Text('Precio (desc)')),
                  PopupMenuItem(
                      value: SortOption.dateDesc,
                      child: Text('Fecha más reciente')),
                  PopupMenuItem(
                      value: SortOption.dateAsc,
                      child: Text('Fecha más antigua')),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Como obtener tu primer trabajo'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Help'),
                  ),
                )
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Para hoy'),
              Switch(
                value: _soloHoy,
                onChanged: (v) => setState(() => _soloHoy = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _servicio.obtenerTrabajos(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay trabajos disponibles'));
              }
              final trabajos = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dist = _calcularDistancia(data);
                return {...data, 'distance': dist};
              }).toList();

              if (_soloHoy) {
                final hoy = DateTime.now();
                trabajos.removeWhere((t) {
                  final fecha = (t['fechaTrabajo'] as Timestamp?)?.toDate();
                  return fecha == null ||
                      fecha.year != hoy.year ||
                      fecha.month != hoy.month ||
                      fecha.day != hoy.day;
                });
              }

              final query = _searchController.text.toLowerCase();
              if (query.isNotEmpty) {
                trabajos.retainWhere((t) {
                  final titulo =
                      (t['titulo'] ?? '').toString().toLowerCase();
                  final empresa =
                      (t['empresa'] ?? '').toString().toLowerCase();
                  return titulo.contains(query) || empresa.contains(query);
                });
              }

              _ordenar(trabajos);

              return ListView.builder(
                itemCount: trabajos.length,
                itemBuilder: (context, index) {
                  final data = trabajos[index];
                  final distancia = data['distance'] as double?;
                  final distanciaTxt = distancia != null
                      ? '${distancia.toStringAsFixed(1)} km'
                      : 'N/D';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey.shade300,
                        child:
                            const Icon(Icons.image, color: Colors.black54),
                      ),
                      title: Text(data['titulo'] ?? 'Text'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['empresa'] ?? ''),
                          Text('Distancia: $distanciaTxt'),
                        ],
                      ),
                      trailing: data['precio'] != null
                          ? Text('${data['precio']}')
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetalleTrabajoScreen(trabajo: data),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.work, color: Colors.yellow),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
        title: _buildSelectorVista(),
        centerTitle: true,
      ),
      body: _vistaActual == 0
          ? _buildLista()
          : _buildMapa(),
    );
  }
}