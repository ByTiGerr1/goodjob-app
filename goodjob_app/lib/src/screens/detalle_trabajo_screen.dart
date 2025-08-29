import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
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
  bool _yaPostulado = false;

  @override
  void initState() {
    super.initState();
    _verificarPostulacion();
  }

  Future<void> _verificarPostulacion() async {
    final auth = Auth();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final existe = await PostulacionService().existePostulacion(
      trabajoId: widget.trabajoId,
      usuarioId: uid,
    );
    if (mounted) {
      setState(() => _yaPostulado = existe);
    }
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return '';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
      ubicacion['pais'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes;
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
    final Timestamp? fechaFinTs = widget.trabajo['fechaLimite'];
    final fechaInicio = fechaInicioTs?.toDate();
    final fechaFin = fechaFinTs?.toDate();
    final horaInicio = widget.trabajo['horaInicio'] as Map<String, dynamic>?;
    final horaFin = widget.trabajo['horaFin'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: Text('Detalle del Trabajo')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Título del trabajo
          Text(
            widget.trabajo['titulo'] ?? 'Título no disponible',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 54), // Espacio grande
          // Detalle de la oferta (izquierda) y imagen (derecha)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de la oferta',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.trabajo['descripcion'] ??
                          'Descripción no disponible.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              // Imagen de la oferta (placeholder)
              Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: Center(child: Text('Imagen', style: TextStyle(color: Colors.black54))),
              ),
            ],
          ),
          SizedBox(height: 54), // Espacio grande
          // Horario (izquierda) y Día (derecha)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Horario
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horario',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.black54),
                      SizedBox(width: 4),
                      Text('${_formatHora(horaInicio)} - ${_formatHora(horaFin)} hrs'),
                    ],
                  ),
                ],
              ),
              // Día
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Día',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                      SizedBox(width: 4),
                      Text(_formatFecha(fechaInicio)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24), // Espacio grande
          // Ubicación (izquierda) y Fecha límite (derecha)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ubicación
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    if (widget.trabajo['empresa'] != null ||
                        widget.trabajo['origen'] != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.black54),
                          SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.trabajo['empresa'] != null)
                                  Text(widget.trabajo['empresa'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                if (widget.trabajo['origen'] != null)
                                  Text(
                                      _formatearUbicacion(widget.trabajo['origen'])),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(width: 6), // Espacio entre las columnas
              // Fecha límite
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fecha límite de la oferta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_busy, size: 16, color: Colors.black54),
                      SizedBox(width: 4),
                      Text(_formatFecha(fechaFin)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 54), // Espacio grande

          // Precio
          if (widget.trabajo['precio'] != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Precio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${widget.trabajo['precio']} Bruto por oferta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: 52), // Espacio grande

          // Botón de "Postular"
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _yaPostulado
                  ? null
                  : () async {
                  final auth = Auth();
                  final uid = auth.currentUser?.uid;
                  if (uid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Usuario no autenticado')),
                    );
                    return;
                  }
                  try {
                    await PostulacionService().crearPostulacion(
                      trabajoId: widget.trabajoId,
                      trabajoTitulo: widget.trabajo['titulo'] ?? '',
                      usuarioId: uid,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Postulación enviada')),
                      );
                      setState(() => _yaPostulado = true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al postular: $e')),
                      );
                    }
                  }
              },
              child: Text(
                  _yaPostulado ? 'Ya postulaste' : 'Postular',
                  style: const TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}