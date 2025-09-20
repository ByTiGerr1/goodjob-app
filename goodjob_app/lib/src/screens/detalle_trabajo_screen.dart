import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/postulacion_service.dart';

class DetalleTrabajoScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const DetalleTrabajoScreen(
      {super.key, required this.trabajoId, required this.trabajo});

  @override
  State<DetalleTrabajoScreen> createState() => _DetalleTrabajoScreenState();
}

class _DetalleTrabajoScreenState extends State<DetalleTrabajoScreen> {
  final PostulacionService _postulacionService = PostulacionService();
  final String? _usuarioId = FirebaseAuth.instance.currentUser?.uid;
  Timer? _timer;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    final fechaFinTs = widget.trabajo['fechaLimite'];
    if (fechaFinTs is! Timestamp) {
      setState(() {
        _countdownText = 'Fecha límite no disponible';
      });
      return;
    }

    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final fechaFin = widget.trabajo['fechaLimite'];
    if (fechaFin is! Timestamp) {
      _timer?.cancel();
      return;
    }

    final remaining = fechaFin.toDate().difference(DateTime.now());

    if (remaining.isNegative) {
      setState(() {
        _countdownText = 'Ya acabó';
      });
      _timer?.cancel();
    } else {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      final minutes = remaining.inMinutes % 60;
      final seconds = remaining.inSeconds % 60;
      setState(() {
        _countdownText =
            '${days}d ${hours}h ${minutes}m ${seconds}s';
      });
    }
  }

  Future<void> _postularse() async {
    if (_usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para postularte.')),
      );
      return;
    }

    try {
      await _postulacionService.crearPostulacion(
        trabajoId: widget.trabajoId,
        trabajoTitulo: widget.trabajo['titulo'] ?? '',
        usuarioId: _usuarioId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Te has postulado con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al postularte: $e')),
        );
      }
    }
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'N/D';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
      ubicacion['pais'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes.isEmpty ? 'N/D' : partes;
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

  @override
  Widget build(BuildContext context) {
    final Timestamp? fechaInicioTs = widget.trabajo['fechaTrabajo'];
    final fechaInicio = fechaInicioTs?.toDate();
    final horaInicio = widget.trabajo['horaInicio'] as Map<String, dynamic>?;
    final horaFin = widget.trabajo['horaFin'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Trabajo')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Ícono del trabajo con forma cuadrada y bordes redondeados
          Center(
            child: Container(
              height: 180,
              width: 420,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(24.0),
              ),
              child: const Icon(Icons.business_center, color: Colors.black54, size: 60),
            ),
          ),
          const SizedBox(height: 16),

          // Título del trabajo
          Text(
            widget.trabajo['titulo'] ?? 'Título no disponible',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Sección de la descripción
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Descripción:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.trabajo['descripcion'] ?? 'Descripción no disponible.',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 34),

          // Título de "Detalles de la oferta"
          const Text(
            'Detalles de la oferta:',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),

          // Tarjeta de Ubicación (fila completa)
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: Color(0xFF7B0997), size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ubicación',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.trabajo['empresa'] ?? 'N/D',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatearUbicacion(widget.trabajo['ubicacion']),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cards de Horario y Día (mitad y mitad)
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time_filled, color: Color(0xFF7B0997), size: 24),
                        const SizedBox(height: 8),
                        const Text(
                          'Horario',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatHora(horaInicio)} - ${_formatHora(horaFin)} hrs',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF7B0997), size: 24),
                        const SizedBox(height: 8),
                        const Text(
                          'Día',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFecha(fechaInicio),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fecha límite de la oferta con cuenta regresiva
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_busy, color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Esta oferta termina en:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _countdownText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Precio
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments, color: Colors.green, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Pago',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${widget.trabajo['precio']?.toString() ?? 'N/D'} Bruto por oferta',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 52),

          // Botón de "Postular"
          SizedBox(
            width: double.infinity,
            child: FutureBuilder<bool>(
              future: _usuarioId != null
                  ? _postulacionService.existePostulacion(
                      trabajoId: widget.trabajoId,
                      usuarioId: _usuarioId,
                    )
                  : Future.value(false), // Si no hay usuario, no está postulado
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ElevatedButton(
                    onPressed: null,
                    child: CircularProgressIndicator(),
                  );
                }

                final yaPostulado = snapshot.data ?? false;
                final isAuth = _usuarioId != null;

                return ElevatedButton(
                  onPressed: isAuth && !yaPostulado ? _postularse : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B0997),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    !isAuth
                        ? 'Inicia sesión para postularte'
                        : yaPostulado
                            ? 'Ya te has postulado'
                            : 'Postular',
                    style: const TextStyle(fontSize: 18, color: Colors.white)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}