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

  @override
  Widget build(BuildContext context) {
    final Timestamp? fechaLimiteTs = trabajo['fechaLimite'];
    final fechaLimite = fechaLimiteTs?.toDate();

    return Scaffold(
      appBar: AppBar(title: Text(trabajo['titulo'] ?? 'Detalle del Trabajo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (trabajo['descripcion'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  trabajo['descripcion'],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            if (trabajo['empresa'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Empresa: ${trabajo['empresa']}'),
              ),
            if (trabajo['precio'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text('Pago: ${trabajo['precio']}'),
              ),
            if (trabajo['origen'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child:
                    Text('Ubicación: ${_formatearUbicacion(trabajo['origen'])}'),
              ),
            if (fechaLimite != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                    'Fecha límite: ${fechaLimite.toLocal().toString().split(' ')[0]}'),
              ),
          ],
        ),
      ),
    );
  }
}