import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/trabajo_service.dart';
import 'detalle_trabajo_screen.dart';

enum DisplayOption { upcoming, recent }

class TrabajosScreen extends StatefulWidget {
  const TrabajosScreen({super.key});

  @override
  State<TrabajosScreen> createState() => _TrabajosScreenState();
}

class _TrabajosScreenState extends State<TrabajosScreen> {
  final _servicio = TrabajoService();
  DisplayOption _selectedDisplay = DisplayOption.upcoming;
  Position? _currentPosition;
  int _vistaActual = 0; // 0 -> Lista, 1 -> Mapa
  final MapController _mapController = MapController();
  static const LatLng _defaultLocation = LatLng(-33.447487, -70.673676);

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
      _centrarEnUbicacion();
    } catch (_) {
      // Ignorar errores de ubicación
    }
  }
  void _centrarEnUbicacion() {
    if (_currentPosition == null) return;
    final dest =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    _mapController.move(dest, 16.0);
  }

  @override
  void dispose() {
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
    int compareDate(a, b) =>
        ((a['fechaTrabajo'] as Timestamp?)?.toDate() ?? DateTime(0)).compareTo(
          (b['fechaTrabajo'] as Timestamp?)?.toDate() ?? DateTime(0),
        );
    int compareCreated(a, b) =>
        ((a['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0)).compareTo(
          (b['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0),
        );

    switch (_selectedDisplay) {
      case DisplayOption.upcoming:
        trabajos.sort(compareDate); // Ordena por fecha de trabajo ascendente
        break;
      case DisplayOption.recent:
        trabajos.sort(
          (a, b) => compareCreated(b, a),
        ); // Ordena por fecha de creación descendente
        break;
    }
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
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      content: Text(
                          '${t['titulo']} - ${String.fromCharCode(36)}${t['precio']}'),
                    ),
                  );
                },
                child:
                    const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
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
              child: const Icon(
                Icons.my_location,
                color: Color(0xFF7B0997),
                size: 40,
              ),
            ),
          );
        }

        final center = _currentPosition != null
            ? LatLng(
                _currentPosition!.latitude, _currentPosition!.longitude)
            : _defaultLocation;

        final zoom = _currentPosition != null ? 16.0 : 5.0;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                maxZoom: 40,
                minZoom: 9,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            if (_currentPosition != null)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _centrarEnUbicacion,
                  child: const Icon(Icons.my_location),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSelectorVista() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _vistaActual = 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _vistaActual == 0
                    ? const Color(0xFF7B0997)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Lista',
                style: TextStyle(
                  color: _vistaActual == 0 ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _vistaActual = 1);
              _centrarEnUbicacion();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _vistaActual == 1
                    ? const Color(0xFF7B0997)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Mapa',
                style: TextStyle(
                  color: _vistaActual == 1 ? Colors.white : Colors.black,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          // Aumentamos la altura de la lista y el ancho de las tarjetas
          SizedBox(
            height: 200, // Altura fija para el carrusel de tarjetas
            child: StreamBuilder<QuerySnapshot>(
              stream: _servicio.obtenerTrabajosDestacados(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No hay trabajos destacados.'),
                  );
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
                    final fechaInicio = (data['fechaTrabajo'] as Timestamp?)
                        ?.toDate();
                    final fechaTxt = _formatFecha(fechaInicio);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        width: 250, 
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Imagen de avatar a la izquierda
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: const Icon(
                                      Icons.business_center,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Contenido de texto a la derecha
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          empresa,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        Text(
                                          fechaTxt,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        Text(
                                          '\$$precio',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      DetalleTrabajoScreen(
                                                        trabajoId: data['id'],
                                                        trabajo: data,
                                                      ),
                                                ),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor:
                                                  Colors.yellow[700],
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
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
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    return StreamBuilder<QuerySnapshot>(
      stream: _servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No hay trabajos disponibles',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
          );
        }
        final trabajos = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dist = _calcularDistancia(data);
          return {...data, 'distance': dist, 'id': doc.id};
        }).toList();

        _ordenar(trabajos);

        // Se utiliza CustomScrollView para una experiencia de scroll unificada,
        // combinando la sección de trabajos destacados con la lista principal.
        return CustomScrollView(
          slivers: [
            // SliverToBoxAdapter se usa para widgets que no son listas, como la sección de destacados.
            SliverToBoxAdapter(child: _buildDestacados()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                        () => _selectedDisplay = DisplayOption.upcoming,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedDisplay == DisplayOption.upcoming
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Próximas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    _selectedDisplay == DisplayOption.upcoming
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            Text(
                              'más próximas a iniciar',
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    _selectedDisplay == DisplayOption.upcoming
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(
                        () => _selectedDisplay = DisplayOption.recent,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedDisplay == DisplayOption.recent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Recientes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _selectedDisplay == DisplayOption.recent
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            Text(
                              'recientemente publicadas',
                              style: TextStyle(
                                fontSize: 10,
                                color: _selectedDisplay == DisplayOption.recent
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // SliverList construye la lista de elementos de manera eficiente.
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final data = trabajos[index];
                final fechaInicio = (data['fechaTrabajo'] as Timestamp?)
                    ?.toDate();
                final fechaFin = (data['fechaLimite'] as Timestamp?)?.toDate();
                final fechaTxt =
                    '${_formatFecha(fechaInicio)}${fechaFin != null ? ' - ${_formatFecha(fechaFin)}' : ''}';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.business_center, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              Text(
                                fechaTxt,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
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
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Ver más',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: trabajos.length),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: ImageIcon(
            const AssetImage(
              'assets/images/GoodJob_con_margen_en_logo_sin_nombre.png',
            ),
            color: Theme.of(context).colorScheme.secondary, // Color del ícono
            size: 24, // Tamaño del ícono
          ),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
        title: _buildSelectorVista(),
        centerTitle: true,
      ),
      body: _vistaActual == 0 ? _buildLista() : _buildMapa(),
    );
  }
}


