import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:goodjob_app/src/screens/trabajos_vista_usuario/display_option.dart';
import 'package:goodjob_app/src/screens/trabajos_vista_usuario/trabajos_time_utils.dart';
import 'package:goodjob_app/src/screens/trabajos_vista_usuario/rabajos_data_processor.dart';
import 'package:goodjob_app/src/screens/trabajos_vista_usuario/trabajos_map_coordinator.dart';
import 'package:goodjob_app/src/screens/trabajos_vista_usuario/trabajos_screen_controller.dart';
import 'package:latlong2/latlong.dart';
import 'package:goodjob_app/src/utils/location_utils.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/utils/resistant_page_scroll_physics.dart';
import 'package:goodjob_app/theme/app_colors.dart';

import '../../models/trabajo.dart';
import '../../services/postulacion_service.dart';
import '../../services/trabajo_service.dart';
import '../../services/user_eligibility_service.dart';
import '../../widgets/user_eligibility_gate.dart';
import '../../widgets/verification_required_view.dart';
import '../auth/account_verification_screen.dart';
import '../detalle_trabajo_screen.dart';
import '../auth/login_screen.dart';

class TrabajosScreen extends StatefulWidget {
  const TrabajosScreen({super.key});

  @override
  State<TrabajosScreen> createState() => _TrabajosScreenState();
}

class _TrabajosScreenState extends State<TrabajosScreen> {
  final _servicio = TrabajoService();
  final PostulacionService _postulacionService = PostulacionService();
  final PageController _carouselController = PageController(
    viewportFraction: 0.75,
  );
  static const LatLng _defaultLocation = LatLng(-33.447487, -70.673676);
  late final TrabajosMapCoordinator _mapCoordinator;
  late final TrabajosDataProcessor _dataProcessor;
  late final TrabajosScreenController _controller;
  // Color primario utilizado en los selectores/marcadores
  static const Color _primaryAppColor = AppColors.primary;
  static const Color _secondaryAppColor = AppColors.accent;

  @override
  void initState() {
    super.initState();
    _mapCoordinator = TrabajosMapCoordinator(defaultLocation: _defaultLocation);
    _dataProcessor = TrabajosDataProcessor(trabajoService: _servicio);
    _controller = TrabajosScreenController()..addListener(_onControllerChanged);
    _initializeLocation();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _initializeLocation() async {
    await _mapCoordinator.loadUserPosition();
    if (!mounted) return;
    setState(() {});
  }

  void _onTrabajoCarruselTap(
    BuildContext context,
    Map<String, dynamic> trabajo,
  ) {
    final id = trabajo['id'] as String?;
    if (id == null) return;

    if (_controller.registerTrabajoTap(id)) {
      final detalleTrabajo = Map<String, dynamic>.from(trabajo)
        ..remove('distance');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetalleTrabajoScreen(trabajoId: id, trabajo: detalleTrabajo),
        ),
      );
    } else {
      _mapCoordinator.centerOnTrabajo(trabajo);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _carouselController.dispose();
    super.dispose();
  }
  // --- WIDGETS DE VISTA ---

  Widget _buildSelectorVista() {
    final vistaActual = _controller.vistaActual;
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
            isSelected: vistaActual == 0,
            onTap: () => _controller.setVistaActual(0),
          ),
          const SizedBox(width: 8),
          _buildSelectorButton(
            label: 'Mapa',
            isSelected: vistaActual == 1,
            onTap: () {
              _controller.setVistaActual(1);
              // Centrar en ubicación solo cuando el mapa esté listo
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapCoordinator.centerOnUserPosition();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
    final isSelected = _controller.selectedDisplay == option;
    final color = isSelected ? _primaryAppColor : Colors.grey[200];
    final contentColor = isSelected ? Colors.white : Colors.black87;

    return Expanded(
      child: GestureDetector(
        onTap: () => _controller.setSelectedDisplay(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // Padding ajustado
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primaryAppColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            // Uso de Row para ícono y texto
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

  Widget _buildListaContent(List<Map<String, dynamic>> trabajos) {
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
            final fechaInicio = getTrabajoStartDateTime(data);
            final fechaFin = getTrabajoEndDateTime(data);
            final fechaLimite = getFechaLimite(
              data,
            ); // Usado para mostrar si es fecha límite

            final distancia = data['distance'] as double?;
            final imagenUrl =
                data['imagenPrincipalUrl'] as String?; // <--- Extraemos la URL

            String fechaTxt = formatFecha(fechaInicio);

            if (fechaInicio != null &&
                fechaFin != null &&
                fechaFin.day != fechaInicio.day) {
              fechaTxt =
                  'Del ${formatFecha(fechaInicio)} al ${formatFecha(fechaFin)}';
            } else if (fechaLimite != null && fechaInicio == null) {
              // Si solo tenemos fecha límite y no fecha de inicio (trabajo antiguo/incompleto)
              fechaTxt = fechaTxt =
                  'Postula antes del ${formatFecha(fechaLimite)}';
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // *** INICIO: Círculo de Avatar con Imagen/Icono ***
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _primaryAppColor,
                        // Lógica para mostrar la imagen de red o el icono
                        backgroundImage:
                            (imagenUrl != null && imagenUrl.isNotEmpty)
                            ? NetworkImage(imagenUrl)
                            : null,
                        child: (imagenUrl == null || imagenUrl.isEmpty)
                            ? const Icon(
                                Icons.work_outline,
                                size: 28,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      // *** FIN: Círculo de Avatar con Imagen/Icono ***
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
                              maxLines: 2,
                            ),
                            Text(
                              data['empresa'] ?? 'Empresa N/D',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (data['precio'] != null)
                                  ? FormatUtils.formatCurrency(
                                      data['precio'].toDouble(),
                                    )
                                  : 'N/D',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.event,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  fechaTxt,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            if (distancia != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.near_me_outlined,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${distancia.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
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
              ),
            );
          }, childCount: trabajos.length),
        ),
      ],
    );
  }

  Widget _buildLista(UserEligibilityStatus status) {
    final userId = status.userId;

    return StreamBuilder<QuerySnapshot>(
      stream: _servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Error al cargar las ofertas de trabajo.'),
          );
        }

        final trabajosPreparados = _dataProcessor.prepararTrabajosParaMostrar(
          snapshot.data,
          _mapCoordinator.calculateDistance,
        );

        if (userId == null) {
          final trabajosOrdenados = List<Map<String, dynamic>>.from(
            trabajosPreparados,
          );
          _dataProcessor.ordenar(
            trabajosOrdenados,
            _controller.selectedDisplay,
          );
          return _buildListaContent(trabajosOrdenados);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _postulacionService.obtenerPostulacionesDeUsuario(userId),
          builder: (context, postulacionesSnapshot) {
            if (postulacionesSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (postulacionesSnapshot.hasError) {
              return const Center(
                child: Text('Error al cargar tus postulaciones.'),
              );
            }

            final postulacionesDocs =
                postulacionesSnapshot.data?.docs ?? <QueryDocumentSnapshot>[];
            final postulacionesIds = postulacionesDocs
                .map((doc) => doc.id)
                .toSet();

            final trabajosFiltrados = _dataProcessor.excluirTrabajosPostulados(
              trabajosPreparados,
              postulacionesIds,
            );

            _dataProcessor.ordenar(
              trabajosFiltrados,
              _controller.selectedDisplay,
            );
            return _buildListaContent(trabajosFiltrados);
          },
        );
      },
    );
  }

  Widget _buildMapaContent(List<Map<String, dynamic>> trabajos) {
    final position = _mapCoordinator.currentPosition;
    final trabajosOrdenadosPorDistancia =
        List<Map<String, dynamic>>.from(trabajos)..sort((a, b) {
          final distanciaA = a['distance'] as double? ?? double.infinity;
          final distanciaB = b['distance'] as double? ?? double.infinity;
          return distanciaA.compareTo(distanciaB);
        });

    final markers = <Marker>[];

    for (final t in trabajos) {
      final ubicacion = t['ubicacion'] as Map<String, dynamic>?;
      final pos = extractLatLngFromUbicacion(ubicacion);
      if (pos == null) continue;
      final isSelected = _controller.selectedTrabajoId == t['id'];

      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: pos,
          child: GestureDetector(
            onTap: () {
              final trabajoId = t['id'] as String?;
              if (trabajoId != null) {
                _controller.setTrabajoSeleccionado(trabajoId);
              }
              _mapCoordinator.centerOnTrabajo(t);
              final index = trabajosOrdenadosPorDistancia.indexWhere(
                (tc) => tc['id'] == t['id'],
              );
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
              size: isSelected ? 45 : 35,
            ),
          ),
        ),
      );
    }

    if (position != null) {
      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: LatLng(position.latitude, position.longitude),
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
        ),
      );
    }

    final center = _mapCoordinator.initialCenter;

    final zoom = _mapCoordinator.initialZoom;

    final double fabBottom = trabajosOrdenadosPorDistancia.isNotEmpty
        ? 180.0
        : 16.0;
    final bool hayTrabajosDisponibles = trabajos.isNotEmpty;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: _controller.isCarouselInteracting,
          child: FlutterMap(
            mapController: _mapCoordinator.mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              maxZoom: 40,
              minZoom: 9,
              onMapReady: () {
                _mapCoordinator.centerOnUserPosition();
              },
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
        ),

        if (!hayTrabajosDisponibles)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'No hay trabajos disponibles',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),

        if (position != null)
          Positioned(
            bottom: fabBottom,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              onPressed: _mapCoordinator.centerOnUserPosition,
              backgroundColor: _primaryAppColor,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

        if (trabajosOrdenadosPorDistancia.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                  child: Listener(
                    onPointerDown: (_) =>
                        _controller.setCarouselInteraction(true),
                    onPointerCancel: (_) =>
                        _controller.setCarouselInteraction(false),
                    onPointerUp: (_) =>
                        _controller.setCarouselInteraction(false),

                    child: PageView.builder(
                      controller: _carouselController,
                      physics: const ResistantPageScrollPhysics(),
                      itemCount: trabajosOrdenadosPorDistancia.length,
                      onPageChanged: (index) {
                        final trabajo = trabajosOrdenadosPorDistancia[index];
                        final trabajoId = trabajo['id'] as String?;
                        if (trabajoId != null) {
                          _controller.setTrabajoSeleccionado(trabajoId);
                        }
                        _mapCoordinator.centerOnTrabajo(trabajo);
                      },
                      itemBuilder: (context, index) {
                        final trabajo = trabajosOrdenadosPorDistancia[index];
                        final id = trabajo['id'] as String?;
                        final seleccionado =
                            id != null && id == _controller.selectedTrabajoId;
                        final distancia = trabajo['distance'] as double?;
                        final imagenUrl =
                            trabajo['imagenPrincipalUrl'] as String?;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: GestureDetector(
                            onTap: () =>
                                _onTrabajoCarruselTap(context, trabajo),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: seleccionado
                                      ? _secondaryAppColor
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: seleccionado
                                        ? _secondaryAppColor.withOpacity(0.4)
                                        : Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: _primaryAppColor,
                                      borderRadius: BorderRadius.circular(8),
                                      image:
                                          (imagenUrl != null &&
                                              imagenUrl.isNotEmpty)
                                          ? DecorationImage(
                                              image: NetworkImage(imagenUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child:
                                        (imagenUrl == null || imagenUrl.isEmpty)
                                        ? const Icon(
                                            Icons.work_outline,
                                            size: 30,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          trabajo['titulo'] ?? 'Sin título',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          trabajo['empresa'] ??
                                              'Empresa no registrada',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          (trabajo['precio'] != null)
                                              ? FormatUtils.formatCurrency(
                                                  trabajo['precio'].toDouble(),
                                                )
                                              : 'N/D',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        if (distancia != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6.0,
                                            ),
                                            child: Text(
                                              '${distancia.toStringAsFixed(1)} km de distancia',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
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
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapa(UserEligibilityStatus status) {
    final userId = status.userId;

    return StreamBuilder<QuerySnapshot>(
      stream: _servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Error al cargar las ofertas de trabajo.'),
          );
        }

        final trabajosPreparados = _dataProcessor.prepararTrabajosParaMostrar(
          snapshot.data,
          _mapCoordinator.calculateDistance,
        );
        if (userId == null) {
          return _buildMapaContent(trabajosPreparados);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _postulacionService.obtenerPostulacionesDeUsuario(userId),
          builder: (context, postulacionesSnapshot) {
            if (postulacionesSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (postulacionesSnapshot.hasError) {
              return const Center(
                child: Text('Error al cargar tus postulaciones.'),
              );
            }

            final postulacionesDocs =
                postulacionesSnapshot.data?.docs ?? <QueryDocumentSnapshot>[];
            final postulacionesIds = postulacionesDocs
                .map((doc) => doc.id)
                .toSet();

            final trabajosFiltrados = _dataProcessor.excluirTrabajosPostulados(
              trabajosPreparados,
              postulacionesIds,
            );

            return _buildMapaContent(trabajosFiltrados);
          },
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
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
    final title = authenticated
        ? 'Completa tu registro'
        : 'Tu sesión no está activa';
    final description = status.messageForAction(
      'acceder a las ofertas disponibles',
    );
    final primaryLabel = authenticated
        ? 'Completa tus datos'
        : 'Iniciar sesión';

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
          _navigateAndRefresh(context, const LoginScreen(), refresh);
        }
      },
      secondaryButtonLabel: authenticated ? 'Ya completé mis datos' : null,
      onSecondaryPressed: authenticated ? () => refresh() : null,
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Removiendo la imagen del leading, usando solo un título simple y el selector
        title: const Text(
          'Explorar Trabajos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
          return _controller.vistaActual == 0
              ? _buildLista(status)
              : _buildMapa(status);
        },
        blockedBuilder: _buildEligibilityNotice,
      ),
    );
  }
}
