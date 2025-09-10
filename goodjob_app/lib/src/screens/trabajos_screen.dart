import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/trabajo_service.dart';
import 'detalle_trabajo_screen.dart';


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

  String _formatHora(Map<String, dynamic>? hora) {
    if (hora == null) return 'N/D';
    final h = hora['h'];
    final m = hora['m'];
    final hour = (h is int ? h : int.tryParse(h?.toString() ?? '0') ?? 0)
        .toString()
        .padLeft(2, '0');
    final min = (m is int ? m : int.tryParse(m?.toString() ?? '0') ?? 0)
        .toString()
        .padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/D';
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    final year = (fecha.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
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
        color: Color(0xFF7B0997),
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

  Widget _buildDestacados() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Trabajos destacados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180, // Altura fija para el carrusel de tarjetas
            child: StreamBuilder<QuerySnapshot>(
              stream: _servicio.obtenerTrabajosDestacados(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No hay trabajos destacados.'));
                }

                final trabajosDestacados = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {...data, 'id': doc.id};
                }).toList();

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: trabajosDestacados.length,
                  itemBuilder: (context, index) {
                    final data = trabajosDestacados[index];
                    final titulo = data['titulo'] ?? 'Sin título';
                    final empresa = data['empresa'] ?? '';
                    final precio = data['precio'] ?? 'N/D';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Container(
                        width: 250,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              titulo,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD900),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              empresa,
                              style: const TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Text(
                              '\$$precio',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Bruto por oferta',
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD900),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DetalleTrabajoScreen(
                                        trabajoId: data['id'],
                                        trabajo: data,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Ver más', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return Column(
      children: [
        // Sección de trabajos destacados
        _buildDestacados(),
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF212121)),
                    filled: true,
                    fillColor: Color(0xFFFFD900),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15.0),
                    hintStyle: const TextStyle(color: Color(0xFF212121)),
                  ),
                  style: const TextStyle(color: Color(0xFF212121)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<SortOption>(
                icon: const Icon(Icons.filter_list, color: Color(0xFF212121)),
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
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _servicio.obtenerTrabajos(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay trabajos disponibles', style: TextStyle(color: Color(0xFF212121))));
              }
              final trabajos = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dist = _calcularDistancia(data);
                return {...data, 'distance': dist, 'id': doc.id};
              }).toList();


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
                  final horaInicio =
                      data['horaInicio'] as Map<String, dynamic>?;
                  final horaFin = data['horaFin'] as Map<String, dynamic>?;
                  final fechaInicio =
                      (data['fechaTrabajo'] as Timestamp?)?.toDate();
                  final fechaFin =
                      (data['fechaLimite'] as Timestamp?)?.toDate();
                      (data['origen'] as Map<String, dynamic>?) ?? {};
                      '${_formatHora(horaInicio)} - ${_formatHora(horaFin)}';
                  final fechaTxt =
                      '${_formatFecha(fechaInicio)}${fechaFin != null ? ' - ${_formatFecha(fechaFin)}' : ''}';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Imagen de avatar a la izquierda
                          CircleAvatar(
                            radius: 30,
                            child: const Icon(Icons.business_center, size: 30),
                          ),
                          const SizedBox(width: 16),
                          // Contenido de texto en el centro
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombre del trabajo en letra grande
                                Text(
                                  data['titulo'] ?? 'Sin título',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                // Fecha del trabajo en letra pequeña
                                Text(
                                  fechaTxt,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Precio o pago más grande
                                Text(
                                  '\$${data['precio'] ?? 'N/D'}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botón "Ver más" a la derecha
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetalleTrabajoScreen(
                                    trabajoId: data['id'],
                                    trabajo: data,
                                  ),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.yellow[700],
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Ver más',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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
        leading: IconButton(
          icon: ImageIcon(
            const AssetImage('assets/images/onlylogo.png'),
            color: const Color(0xFFFFD900), // Color del ícono
            size: 24, // Tamaño del ícono
          ),
          onPressed: () {
          },
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
