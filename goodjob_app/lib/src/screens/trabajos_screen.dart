import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/trabajo_service.dart';
import '../services/user_eligibility_service.dart';
import '../widgets/user_eligibility_gate.dart';
import '../widgets/verification_required_view.dart';
import 'account_verification_screen.dart';
import 'detalle_trabajo_screen.dart';
import 'login_screen.dart';

// Opciones de ordenamiento
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
  final PageController _carouselController = PageController(viewportFraction: 0.75);
  String? _ultimoTrabajoSeleccionadoId;
  static const LatLng _defaultLocation = LatLng(-33.447487, -70.673676);

  // Color primario utilizado en los selectores/marcadores
  static const Color _primaryAppColor = Color(0xFF7B0997);
  static const Color _secondaryAppColor = Color(0xFFE91E63);

  bool get _mapReady =>
      _mapController is MapControllerImpl &&
      (_mapController).value.options != null;


  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  // --- LÓGICA DE TIEMPO (SOPORTE DUAL-SCHEMA) ---

  /// Función auxiliar para convertir dinámicamente cualquier Map genérico
  /// a Map<String, dynamic> de forma segura, evitando errores de tipado.
  Map<String, dynamic>? _safeMapCast(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
  
  /// Obtiene la fecha y hora de inicio del trabajo de forma robusta (Dual-Schema).
  DateTime? _getTrabajoStartDateTime(Map<String, dynamic> trabajo) {
    // 1. Probar campo nuevo (Timestamp combinado)
    final newStartTs = trabajo['fechaInicioTrabajo'] as Timestamp?;
    if (newStartTs != null) return newStartTs.toDate();

    // 2. Probar esquema antiguo (Timestamp de fecha + Map de hora)
    final oldDateTs = trabajo['fechaTrabajo'] as Timestamp?;
    final oldHourMap = _safeMapCast(trabajo['horaInicio']);

    if (oldDateTs != null && oldHourMap != null) {
      final date = oldDateTs.toDate();
      final h = oldHourMap['h'] as int? ?? 0;
      final m = oldHourMap['m'] as int? ?? 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    return null;
  }
  
  /// Obtiene la fecha límite de postulación (Dual-Schema).
  DateTime? _getFechaLimite(Map<String, dynamic> trabajo) {
    // Intentar leer el campo principal (fechaLimite)
    final fechaLimiteTs = trabajo['fechaLimite'] as Timestamp? ??
        trabajo['fechaLimitePostulacion'] as Timestamp?; // Campo de respaldo

    return fechaLimiteTs?.toDate();
  }
  
  /// Obtiene la fecha y hora de fin del trabajo de forma robusta (Dual-Schema).
  DateTime? _getTrabajoEndDateTime(Map<String, dynamic> trabajo) {
    // 1. Probar campo nuevo (Timestamp combinado)
    final newEndTs = trabajo['fechaFinTrabajo'] as Timestamp?;
    if (newEndTs != null) return newEndTs.toDate();

    // 2. Probar esquema antiguo (Timestamp de fecha + Map de hora)
    final oldDateTs = trabajo['fechaTrabajo'] as Timestamp?;
    final oldHourMap = _safeMapCast(trabajo['horaFin']);

    if (oldDateTs != null && oldHourMap != null) {
      final date = oldDateTs.toDate();
      final h = oldHourMap['h'] as int? ?? 0;
      final m = oldHourMap['m'] as int? ?? 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }

    return null;
  }


  // --- LÓGICA DE UBICACIÓN Y MAPA ---

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
      if (_mapReady) _centrarEnUbicacion();
    } catch (_) {
      // Ignorar errores de ubicación
    }
  }

  void _centrarEnUbicacion() {
    if (_currentPosition == null || !_mapReady) return;
    final dest =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    _mapController.move(dest, 16.0);
  }

  void _centrarEnTrabajo(Map<String, dynamic> trabajo) {
    if (!_mapReady) return;
    final ubicacion = trabajo['ubicacion'] as Map<String, dynamic>?;
    final lat = ubicacion?['lat'];
    final lng = ubicacion?['lng'];
    if (lat == null || lng == null) return;
    final destino = LatLng((lat as num).toDouble(), (lng as num).toDouble());
    _mapController.move(destino, 17.0);
  }

  void _onTrabajoCarruselTap(
      BuildContext context, Map<String, dynamic> trabajo) {
    final id = trabajo['id'] as String?;
    if (id == null) return;

    if (_ultimoTrabajoSeleccionadoId == id) {
      final detalleTrabajo = Map<String, dynamic>.from(trabajo)
        ..remove('distance');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleTrabajoScreen(
            trabajoId: id,
            trabajo: detalleTrabajo,
          ),
        ),
      );
    } else {
      setState(() => _ultimoTrabajoSeleccionadoId = id);
      _centrarEnTrabajo(trabajo);
    }
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  double? _calcularDistancia(Map<String, dynamic> trabajo) {
    if (_currentPosition == null) return null;
    final ubicacion = trabajo['ubicacion'] as Map<String, dynamic>?;
    final lat = ubicacion?['lat'];
    final lng = ubicacion?['lng'];
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          (lat as num).toDouble(),
          (lng as num).toDouble(),
        ) /
        1000;
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

  bool _estaDisponibleParaPostular(Map<String, dynamic> trabajo, DateTime ahora) {
    final fechaLimite = _getFechaLimite(trabajo);
    if (fechaLimite != null && ahora.isAfter(fechaLimite)) return false;

    final camposEstado = <String?>[
      trabajo['estado']?.toString(),
      trabajo['estadoTrabajo']?.toString(),
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

  List<Map<String, dynamic>> _filtrarTrabajosVigentes(
      List<Map<String, dynamic>> trabajos) {
    final ahora = DateTime.now();
    return trabajos
        .where((trabajo) => _estaDisponibleParaPostular(trabajo, ahora))
        .toList();
  }

  List<Map<String, dynamic>> _prepararTrabajosParaMostrar(
      QuerySnapshot? snapshot) {
    final trabajosDocs = snapshot?.docs ?? [];
    final trabajosSinProcesar = trabajosDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id};
    }).toList();

    final filtrados = _filtrarTrabajosVigentes(trabajosSinProcesar);

    return filtrados
        .map((trabajo) => {
              ...trabajo,
              'distance': _calcularDistancia(trabajo),
            })
        .toList();
  }

  void _ordenar(List<Map<String, dynamic>> trabajos) {
    int compareDate(a, b) {
      final dateA = _getTrabajoStartDateTime(a);
      final dateB = _getTrabajoStartDateTime(b);
      // Usar fecha actual si es nula para forzar el orden
      return (dateA ?? DateTime.now()).compareTo(dateB ?? DateTime.now());
    }
      
    int compareCreated(a, b) =>
        ((a['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0)).compareTo(
          (b['creadoEn'] as Timestamp?)?.toDate() ?? DateTime(0),
        );

    switch (_selectedDisplay) {
      case DisplayOption.upcoming:
        trabajos.sort(compareDate); // Ordena por fecha de trabajo ascendente (usando nueva lógica)
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
  
  // --- WIDGETS DE VISTA ---

  Widget _buildSelectorVista() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectorButton(
            label: 'Lista',
            isSelected: _vistaActual == 0,
            onTap: () => setState(() => _vistaActual = 0),
          ),
          const SizedBox(width: 8),
          _buildSelectorButton(
            label: 'Mapa',
            isSelected: _vistaActual == 1,
            onTap: () {
              setState(() => _vistaActual = 1);
              // Centrar en ubicación solo cuando el mapa esté listo
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _centrarEnUbicacion();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryAppColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  // WIDGET DE ORDENADOR MEJORADO
  Widget _buildOrdenador() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildOrdenadorButton(
            title: 'Próximas',
            icon: Icons.calendar_today, // Ícono para "Próximas"
            option: DisplayOption.upcoming,
          ),
          const SizedBox(width: 12),
          _buildOrdenadorButton(
            title: 'Recientes',
            icon: Icons.access_time, // Ícono para "Recientes"
            option: DisplayOption.recent,
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrdenadorButton({
    required String title,
    required IconData icon, 
    required DisplayOption option,
  }) {
    final isSelected = _selectedDisplay == option;
    final color = isSelected ? _primaryAppColor : Colors.grey[200];
    final contentColor = isSelected ? Colors.white : Colors.black87;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDisplay = option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // Padding ajustado
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: _primaryAppColor.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row( // Uso de Row para ícono y texto
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: contentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
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
        
        if (snapshot.hasError) {
          // Mejorar el manejo de errores
          return const Center(child: Text('Error al cargar las ofertas de trabajo.'));
        }

        var trabajos = _prepararTrabajosParaMostrar(snapshot.data);
        _ordenar(trabajos);

        if (trabajos.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                '¡Vaya! No hay ofertas de trabajo vigentes en este momento. Intenta más tarde.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          );
        }

        // Se utiliza CustomScrollView para una experiencia de scroll unificada
        return CustomScrollView(
          slivers: [
            // Ordenador fijo en la parte superior
            SliverToBoxAdapter(child: _buildOrdenador()),
            
            // Lista de elementos
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final data = trabajos[index];
                
                // --- LECTURA DUAL DE FECHAS (NUEVO) ---
                final fechaInicio = _getTrabajoStartDateTime(data);
                final fechaFin = _getTrabajoEndDateTime(data);
                final fechaLimite = _getFechaLimite(data); // Usado para mostrar si es fecha límite
                
                final distancia = data['distance'] as double?;
                
                String fechaTxt = _formatFecha(fechaInicio);

                if (fechaInicio != null && fechaFin != null && fechaFin.day != fechaInicio.day) {
                    fechaTxt = 'Del ${_formatFecha(fechaInicio)} al ${_formatFecha(fechaFin)}';
                } else if (fechaLimite != null && fechaInicio == null) {
                    // Si solo tenemos fecha límite y no fecha de inicio (trabajo antiguo/incompleto)
                    fechaTxt = 'Postula antes del ${_formatFecha(fechaLimite)}';
                }
                // Si solo tenemos fecha de inicio, ya se muestra en _formatFecha(fechaInicio)

                return GestureDetector(
                  onTap: () {
                    // Asegurar que el objeto de trabajo pasado contenga todos los datos.
                    final detalleTrabajo = Map<String, dynamic>.from(data)
                      ..remove('distance');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleTrabajoScreen(
                          trabajoId: data['id'],
                          trabajo: detalleTrabajo,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: _primaryAppColor,
                            child: const Icon(Icons.work_outline, size: 28, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['titulo'] ?? 'Sin título',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis, maxLines: 2,
                                ),
                                Text(
                                  data['empresa'] ?? 'Empresa N/D',
                                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '\$${data['precio'] ?? 'N/D'}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.event, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(fechaTxt, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                                if (distancia != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.near_me_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${distancia.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: trabajos.length,
            ),
          )],
        );
      },
    );
  }

  Widget _buildMapa() {
    return StreamBuilder<QuerySnapshot>(
      stream: _servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final trabajos = _prepararTrabajosParaMostrar(snapshot.data);

        // Mostrar todos los trabajos disponibles, priorizando los más cercanos cuando
        // se cuenta con la ubicación del usuario. De esta forma, no ocultamos
        // oportunidades vigentes que puedan estar lejos pero igual disponibles.
        final trabajosOrdenadosPorDistancia = List<Map<String, dynamic>>.from(
          trabajos,
        )
          ..sort((a, b) {
            final distanciaA = a['distance'] as double? ?? double.infinity;
            final distanciaB = b['distance'] as double? ?? double.infinity;
            return distanciaA.compareTo(distanciaB);
          });

        final markers = <Marker>[];

        // Añadir marcadores de trabajos
        for (final t in trabajos) {
          final ubicacion = t['ubicacion'] as Map<String, dynamic>?;
          final lat = ubicacion?['lat'];
          final lng = ubicacion?['lng'];
          if (lat == null || lng == null) continue;
          final pos = LatLng((lat as num).toDouble(), (lng as num).toDouble());
          
          final isSelected = t['id'] == _ultimoTrabajoSeleccionadoId;
          
          markers.add(
            Marker(
              width: 40,
              height: 40,
              point: pos,
              child: GestureDetector(
                onTap: () {
                    setState(() => _ultimoTrabajoSeleccionadoId = t['id']);
                    _centrarEnTrabajo(t);
                    // Navegar al carrusel al elemento seleccionado (UX)
                    final index = trabajosOrdenadosPorDistancia
                        .indexWhere((tc) => tc['id'] == t['id']);
                    if (index != -1 && _carouselController.hasClients) {
                        _carouselController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                        );
                    }
                },
                child: Icon(
                    Icons.location_on, 
                    color: isSelected ? _secondaryAppColor : _primaryAppColor, 
                    size: isSelected ? 45 : 35
                ),
              ),
            ),
          );
        }

        // Marcador de ubicación actual del usuario
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
            ? LatLng(
                _currentPosition!.latitude, _currentPosition!.longitude)
            : _defaultLocation;

        final zoom = _currentPosition != null ? 14.0 : 5.0;

        final double fabBottom = trabajosOrdenadosPorDistancia.isNotEmpty ? 180.0 : 16.0;
        final bool hayTrabajosDisponibles = trabajos.isNotEmpty;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                maxZoom: 40,
                minZoom: 9,
                onMapReady: () {
                    // Si la ubicación ya está, centramos al iniciar el mapa
                    if (_currentPosition != null) {
                        _centrarEnUbicacion();
                    }
                }
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
            
            // Mensaje de que no hay trabajos
            if (!hayTrabajosDisponibles)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: const Text('No hay trabajos disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            
            // Botón para centrar en ubicación
            if (_currentPosition != null)
              Positioned(
                bottom: fabBottom,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _centrarEnUbicacion,
                  backgroundColor: _primaryAppColor,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),
              
             // Carrusel de trabajos ordenados por distancia (mostramos todos)
            if (trabajosOrdenadosPorDistancia.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicación UX más limpia
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Selecciona el pin o desliza para ver los trabajos disponibles',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    SizedBox(
                      height: 150,
                      child: PageView.builder(
                        controller: _carouselController,
                        itemCount: trabajosOrdenadosPorDistancia.length,
                        onPageChanged: (index) {
                            // Centrar el mapa en el trabajo seleccionado al deslizar
                            final trabajo = trabajosOrdenadosPorDistancia[index];
                            setState(() => _ultimoTrabajoSeleccionadoId = trabajo['id']);
                            _centrarEnTrabajo(trabajo);
                        },
                        itemBuilder: (context, index) {
                          final trabajo = trabajosOrdenadosPorDistancia[index];
                          final id = trabajo['id'] as String?;
                          final seleccionado = id != null && id == _ultimoTrabajoSeleccionadoId;
                          final distancia = trabajo['distance'] as double?;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: GestureDetector(
                              onTap: () => _onTrabajoCarruselTap(context, trabajo),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: seleccionado ? _secondaryAppColor : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: seleccionado ? _secondaryAppColor.withOpacity(0.4) : Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      trabajo['titulo'] ?? 'Sin título',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      trabajo['empresa'] ?? 'Empresa no registrada',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '\$${trabajo['precio'] ?? 'N/D'}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    if (distancia != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text(
                                          '${distancia.toStringAsFixed(1)} km de distancia',
                                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // --- LÓGICA DE NAVEGACIÓN Y ELEGIBILIDAD ---

  void _navigateAndRefresh(
    BuildContext context,
    Widget screen,
    Future<void> Function() refresh,
  ) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (!mounted) return;
      refresh();
    });
  }

  Widget _buildEligibilityNotice(
    BuildContext context,
    UserEligibilityStatus status,
    Future<void> Function() refresh,
  ) {
    final authenticated = status.isAuthenticated;
    final title =
        authenticated ? 'Completa tu registro' : 'Tu sesión no está activa';
    final description =
        status.messageForAction('acceder a las ofertas disponibles');
    final primaryLabel =
        authenticated ? 'Completa tus datos' : 'Iniciar sesión';

    return VerificationRequiredView(
      title: title,
      description: description,
      primaryButtonLabel: primaryLabel,
      onPrimaryPressed: () {
        if (authenticated) {
          _navigateAndRefresh(
            context,
            const AccountVerificationScreen(),
            refresh,
          );
        } else {
          _navigateAndRefresh(
            context,
            const LoginScreen(),
            refresh,
          );
        }
      },
      secondaryButtonLabel:
          authenticated ? 'Ya completé mis datos' : null,
      onSecondaryPressed: authenticated ? () => refresh() : null,
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Removiendo la imagen del leading, usando solo un título simple y el selector
        title: const Text('Explorar Trabajos', style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildSelectorVista(),
          ),
        ],
      ),
      body: UserEligibilityGate(
        eligibleBuilder: (context, status, refresh) {
          return _vistaActual == 0 ? _buildLista() : _buildMapa();
        },
        blockedBuilder: _buildEligibilityNotice,
      ),
    );
  }
}
