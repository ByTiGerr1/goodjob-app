import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DetalleTrabajoScreen extends StatelessWidget {
  final Map<String, dynamic> trabajo;

  const DetalleTrabajoScreen({super.key, required this.trabajo});

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
    final Timestamp? fechaInicioTs = trabajo['fechaTrabajo'];
    final Timestamp? fechaFinTs = trabajo['fechaLimite'];
    final fechaInicio = fechaInicioTs?.toDate();
    final fechaFin = fechaFinTs?.toDate();
    final horaInicio = trabajo['horaInicio'] as Map<String, dynamic>?;
    final horaFin = trabajo['horaFin'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: Text(trabajo['titulo'] ?? 'Detalle del Trabajo')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (trabajo['empresa'] != null || trabajo['origen'] != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trabajo['empresa'] != null)
                        Text(trabajo['empresa'],
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (trabajo['origen'] != null)
                        Text(_formatearUbicacion(trabajo['origen'])),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text('${_formatHora(horaInicio)} - ${_formatHora(horaFin)} hrs'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text('${_formatFecha(fechaInicio)} - ${_formatFecha(fechaFin)}'),
            ],
          ),
          const SizedBox(height: 16),
          if (trabajo['precio'] != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${trabajo['precio']} Bruto por oferta',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                    const Text('El monto que te depositaremos será el monto líquido posterior a los descuentos legales y estará sujeto a verificación de asistencia.',
                        style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (trabajo['descripcion'] != null) ...[
            const Text('Descripción de la oferta',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              trabajo['descripcion'],
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }
}