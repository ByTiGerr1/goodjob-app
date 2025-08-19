import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
    } catch (_) {
      // Ignorar errores de ubicación
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajos'),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
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
      body: StreamBuilder<QuerySnapshot>(
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
          _ordenar(trabajos);

          return ListView.builder(
            itemCount: trabajos.length,
            itemBuilder: (context, index) {
              final data = trabajos[index];
              final distancia = data['distance'] as double?;
              final distanciaTxt =
                  distancia != null ? '${distancia.toStringAsFixed(1)} km' : 'N/D';
              return ListTile(
                title: Text(data['titulo'] ?? ''),
                subtitle: Text(
                    '${data['empresa'] ?? ''} · Distancia: $distanciaTxt'),
                trailing: data['precio'] != null
                    ? Text('${data['precio']}')
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleTrabajoScreen(trabajo: data),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}