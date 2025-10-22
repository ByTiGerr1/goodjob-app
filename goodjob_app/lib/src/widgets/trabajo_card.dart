import 'dart:async';
import 'package:flutter/material.dart';

class TrabajoCard extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final DateTime? fechaLimite;
  final bool sinFechaLimite;

  const TrabajoCard({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.fechaLimite,
    this.sinFechaLimite = false,
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
            TiempoRestante(
              fechaLimite: fechaLimite,
              sinFechaLimite: sinFechaLimite,
            ),
          ],
        ),
      ),
    );
  }
}

class TiempoRestante extends StatefulWidget {
  final DateTime? fechaLimite;
  final bool sinFechaLimite;
  const TiempoRestante({
    super.key,
    required this.fechaLimite,
    this.sinFechaLimite = false,
  });

  @override
  State<TiempoRestante> createState() => _TiempoRestanteState();
}

class _TiempoRestanteState extends State<TiempoRestante> {
  Timer? _timer;
  Duration? _diferencia;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
  }

  @override
  void didUpdateWidget(covariant TiempoRestante oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fechaLimite != widget.fechaLimite ||
        oldWidget.sinFechaLimite != widget.sinFechaLimite) {
      _timer?.cancel();
      _initializeTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeTimer() {
    if (widget.sinFechaLimite || widget.fechaLimite == null) {
      setState(() {
        _diferencia = null;
      });
      return;
    }

    _diferencia = widget.fechaLimite!.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _diferencia = widget.fechaLimite!.difference(DateTime.now());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sinFechaLimite || widget.fechaLimite == null) {
      return const Text(
        "Postulaciones abiertas",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      );
    }

    if (_diferencia == null || _diferencia!.isNegative) {
      return const Text(
        "Cerrado",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      );
    }

    final dias = _diferencia!.inDays;
    final horas = _diferencia!.inHours % 24;
    final minutos = _diferencia!.inMinutes % 60;
    final segundos = _diferencia!.inSeconds % 60;

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
