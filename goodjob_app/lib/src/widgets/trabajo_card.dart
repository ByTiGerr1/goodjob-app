import 'dart:async';
import 'package:flutter/material.dart';

class TrabajoCard extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final DateTime fechaLimite;

  const TrabajoCard({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.fechaLimite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(descripcion),
            const SizedBox(height: 10),
            TiempoRestante(fechaLimite: fechaLimite),
          ],
        ),
      ),
    );
  }
}

class TiempoRestante extends StatefulWidget {
  final DateTime fechaLimite;
  const TiempoRestante({super.key, required this.fechaLimite});

  @override
  State<TiempoRestante> createState() => _TiempoRestanteState();
}

class _TiempoRestanteState extends State<TiempoRestante> {
  late Timer _timer;
  late Duration _diferencia;

  @override
  void initState() {
    super.initState();
    _diferencia = widget.fechaLimite.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _diferencia = widget.fechaLimite.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_diferencia.isNegative) {
      return const Text(
        "Cerrado",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      );
    }

    final dias = _diferencia.inDays;
    final horas = _diferencia.inHours % 24;
    final minutos = _diferencia.inMinutes % 60;
    final segundos = _diferencia.inSeconds % 60;

    String texto;
    if (dias > 0) {
      texto = "Cierra en $dias d $horas h";
    } else if (horas > 0) {
      texto = "Cierra en $horas h $minutos min";
    } else if (minutos > 0) {
      texto = "Cierra en $minutos min $segundos s";
    } else {
      texto = "Cierra en $segundos s";
    }

    return Text(
      texto,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
    );
  }
}
