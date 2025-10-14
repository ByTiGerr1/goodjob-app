import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

// --- CONSTANTES GLOBALES (MOVIDAS AQUI PARA ACCESO EN EL MODAL) ---
const Color _PRIMARY_COLOR = Color(0xFF7B0997);
const Color _ACCENT_COLOR = Color(0xFFFFD900);
const Color _SUCCESS_COLOR = Color(0xFF4CAF50); // Verde
// --- FIN CONSTANTES GLOBALES ---

// --- MODELO DE DATOS PARA INSTRUCCIONES ---
class Instruccion {
  final int paso;
  final String titulo;
  final String descripcion;

  Instruccion({
    required this.paso,
    required this.titulo,
    required this.descripcion,
  });
}
// --- FIN MODELO DE DATOS ---

// Simulación de la pantalla de instrucciones (debe ser reemplazada por tu implementacion real)
// Ya no la navegamos, la mostramos en un modal.
// import 'instrucciones_trabajo_screen.dart';

class TrabajoEnCursoScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;
  final DateTime startTime;

  const TrabajoEnCursoScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
    required this.startTime,
  });

  @override
  State<TrabajoEnCursoScreen> createState() => _TrabajoEnCursoScreenState();
}

class _TrabajoEnCursoScreenState extends State<TrabajoEnCursoScreen> {
  late LatLng _trabajoCoords;
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  // --- CONFIGURACION DE LA ZONA DELIMITADA ---
  static const double _CHECKIN_RADIUS_METERS = 50.0;
  // Las constantes de color se eliminaron de aqui

  @override
  void initState() {
    super.initState();
    _parseTrabajoCoords();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _parseTrabajoCoords() {
    final ubicacion = widget.trabajo['ubicacion'] as Map<String, dynamic>?;
    final lat = ubicacion?['lat'];
    final lng = ubicacion?['lng'];

    if (lat is num && lng is num) {
      _trabajoCoords = LatLng(lat.toDouble(), lng.toDouble());
    } else {
      _trabajoCoords = const LatLng(-33.447487, -70.673676);
    }
  }

  Future<void> _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Obtener una posición inicial para centrar el mapa
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentPosition ?? _trabajoCoords, 17.0);
    } catch (_) {
      _mapController.move(_trabajoCoords, 17.0);
    }

    // Escuchar cambios de ubicación en tiempo real
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5, // Actualizar cada 5 metros
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentPosition = LatLng(position.latitude, position.longitude);
            });
          }
        });
  }

  // --- LOGICA DE ACCIONES ---

  void _completeJob() {
    final DateTime endTime = DateTime.now();
    final Duration duration = endTime.difference(widget.startTime);

    // Simular guardar la hora de fin y actualizar estado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Trabajo finalizado en ${duration.inHours}h ${duration.inMinutes % 60}m. Esperando aprobacion.',
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
    // Volver a la pantalla anterior (seguimiento)
    Navigator.of(context).pop();
  }

  Future<void> _contactViaWhatsapp() async {
    final contacto = widget.trabajo['contacto'] as Map<String, dynamic>?;
    final numero = contacto?['numero'] as String?;

    if (numero == null || numero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numero de contacto no disponible.')),
      );
      return;
    }

    final cleanedNumber = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('whatsapp://send?phone=$cleanedNumber');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir WhatsApp. Asegurese de tener la aplicacion instalada.',
          ),
        ),
      );
    }
  }

  void _uploadPhotoEvidence() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Iniciando subida de evidencia fotografica... (Simulado)',
        ),
      ),
    );
    // Logica para abrir la camara/galeria
  }

  // FUNCION ACTUALIZADA: Muestra las instrucciones en un modal
  void _showInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que ocupe mas espacio vertical
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, // Ocupa el 80% de la pantalla inicialmente
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return _InstructionsModalContent(
              trabajo: widget.trabajo,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  // --- WIDGET PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      // Usamos la pantalla completa sin AppBar
      body: Stack(
        children: [
          // 1. MAPA DE PANTALLA COMPLETA
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _trabajoCoords,
                initialZoom: 17.0,
                maxZoom: 19.0,
                minZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.goodjob.app',
                ),

                // ZONA DELIMITADA (Geovalla - Geofence)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _trabajoCoords,
                      radius: _CHECKIN_RADIUS_METERS,
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
                      child: const Icon(
                        Icons.work,
                        color: _PRIMARY_COLOR,
                        size: 40,
                      ),
                    ),
                  ],
                ),

                // MARCADOR DE LA UBICACION DEL USUARIO (Tiempo real)
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: _currentPosition!,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. BOTONES SUPERIORES (Completar / Volver / Instrucciones)

          // Botón Volver/Home (Top-Left, mas pequeño)
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'goBack',
              onPressed: () => Navigator.of(context).pop(),
              backgroundColor: Colors.white,
              child: const Icon(Icons.arrow_back, color: _PRIMARY_COLOR),
            ),
          ),

          // Botón Completar Trabajo (Top-Center-Left, grande)
          Positioned(
            top: 40,
            left: 70, // Ajuste para dejar espacio al botón 'Volver'
            child: FloatingActionButton.extended(
              heroTag: 'completeJob',
              onPressed: _completeJob,
              icon: const Icon(Icons.flag, color: Colors.white),
              label: const Text(
                'Completar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.red.shade700,
            ),
          ),

          // Botón Instrucciones (Top-Right, pequeño)
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'showInstructions',
              onPressed: _showInstructions, // Llama a la nueva función modal
              backgroundColor: _ACCENT_COLOR,
              child: const Icon(Icons.list_alt, color: Colors.black),
            ),
          ),

          // 4. BOTONES INFERIORES (Subir Foto / WhatsApp / Centrar)

          // Botón Subir Foto (Inferior Izquierda)
          Positioned(
            bottom: 40,
            left: 16,
            child: FloatingActionButton(
              heroTag: 'uploadPhoto',
              onPressed: _uploadPhotoEvidence,
              backgroundColor: _ACCENT_COLOR,
              child: const Icon(
                Icons.photo_camera,
                color: Colors.black,
                size: 30,
              ),
            ),
          ),

          // Botón WhatsApp (Inferior Derecha)
          Positioned(
            bottom: 40,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'contactWhatsapp',
              onPressed: _contactViaWhatsapp,
              backgroundColor: _SUCCESS_COLOR,
              child: const Icon(
                Icons.wechat_sharp,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          // Botón para centrar en el usuario (Inferior Central - Opcional)
          Positioned(
            bottom: 40,
            right:
                (screenSize.width / 2) -
                30, // Posiciona en el centro (ajustado por el tamaño del FAB)
            child: FloatingActionButton(
              heroTag: 'centerUser',
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 17.0);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ubicacion no disponible aun.'),
                    ),
                  );
                }
              },
              backgroundColor: _PRIMARY_COLOR,
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// WIDGET PARA CONTENIDO DEL MODAL DE INSTRUCCIONES
// -----------------------------------------------------------

class _InstructionsModalContent extends StatelessWidget {
  final Map<String, dynamic> trabajo;
  final ScrollController scrollController;

  const _InstructionsModalContent({
    required this.trabajo,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Definición de las instrucciones solicitadas
    final List<Instruccion> _instrucciones = [
      Instruccion(
        paso: 1,
        titulo: 'Contar y Confirmar Stock',
        descripcion:
            'Verifica que la cantidad de flyers a repartir coincida con el registro. Reporta cualquier discrepancia antes de salir.',
      ),
      Instruccion(
        paso: 2,
        titulo: 'Establecer Ruta y Zona',
        descripcion:
            'Confirma la zona de reparto (ej. Calles principales entre A y B). Prioriza areas de alto trafico peatonal para maximizar el alcance.',
      ),
      Instruccion(
        paso: 3,
        titulo: 'Metodo de Distribucion',
        descripcion:
            'Reparte un flyer por persona o por buzon (si esta permitido). Se amable, sonrie y no fuerces la entrega. La imagen es clave!',
      ),
      Instruccion(
        paso: 4,
        titulo: 'Reporte de Tarea y Geoubicacion',
        descripcion:
            'Usa la funcion de "Check-in" al inicio y "Check-out" al finalizar. Documenta la cantidad de flyers restantes y cualquier incidente.',
      ),
      Instruccion(
        paso: 5,
        titulo: 'CRITICO! Reglas de Limpieza y Legalidad',
        descripcion:
            'Esta estrictamente PROHIBIDO dejar material en el suelo, pegar en mobiliario urbano o bloquear el paso. Manten la zona limpia y respeta las normativas locales, ya que esto puede llevar a la terminacion inmediata del contrato.',
      ),
    ];

    // Extracción de datos de trabajo para la sección de requisitos (SE ELIMINA ESTA LOGICA)
    // final String instruccionesGenerales = trabajo['instrucciones'] as String? ?? 'No se especificaron requisitos generales.';
    // final bool requiereUniforme = trabajo['requiereUniforme'] as bool? ?? false;
    // final List<String> implementosUniforme =
    //   (trabajo['implementosUniforme'] as List<dynamic>?)
    //  ?.map((e) => e.toString())
    //  .toList() ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        controller: scrollController,
        children: [
          const Center(
            child: Text(
              'INSTRUCCIONES DEL TRABAJO',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _PRIMARY_COLOR,
              ),
            ),
          ),
          const Divider(height: 30),

          // Sección de Pasos Detallados (La nueva lista solicitada)
          const Text(
            'Pasos Detallados del Reparto',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _PRIMARY_COLOR,
            ),
          ),
          const SizedBox(height: 16),
          ..._instrucciones.map(
            (inst) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _PRIMARY_COLOR,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${inst.paso}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          inst.titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 34.0, top: 4.0),
                    child: Text(
                      inst.descripcion,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SECCIONES ELIMINADAS: Requisitos Generales, Uniforme, Pago
          const SizedBox(height: 30),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CERRAR INSTRUCCIONES',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
