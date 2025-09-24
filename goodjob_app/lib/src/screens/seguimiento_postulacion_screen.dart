import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum _PasoEstado { completado, actual, pendiente }

class SeguimientoPostulacionScreen extends StatelessWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const SeguimientoPostulacionScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  Widget build(BuildContext context) {
    final usuarioId = FirebaseAuth.instance.currentUser?.uid;

    if (usuarioId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Estado de mi postulación')),
        body: const Center(
          child: Text('Debes iniciar sesión para ver esta información.'),
        ),
      );
    }

    final postulacionStream = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuarioId)
        .collection('postulaciones')
        .doc(trabajoId)
        .snapshots();

    final trabajoStream = FirebaseFirestore.instance
        .collection('trabajos')
        .doc(trabajoId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Estado de mi postulación')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: postulacionStream,
        builder: (context, postulacionSnapshot) {
          if (postulacionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!postulacionSnapshot.hasData || !postulacionSnapshot.data!.exists) {
            return const Center(
              child: Text('No encontramos información de tu postulación.'),
            );
          }

          final postulacionData =
              postulacionSnapshot.data!.data() ?? <String, dynamic>{};

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: trabajoStream,
            builder: (context, trabajoSnapshot) {
              final trabajoData =
                  trabajoSnapshot.data?.data() ?? Map<String, dynamic>.from(trabajo);

              return _PostulacionContent(
                postulacion: postulacionData,
                trabajo: trabajoData,
              );
            },
          );
        },
      ),
    );
  }
}

class _PostulacionContent extends StatelessWidget {
  final Map<String, dynamic> postulacion;
  final Map<String, dynamic> trabajo;

  const _PostulacionContent({
    required this.postulacion,
    required this.trabajo,
  });

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'Ubicación no disponible';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
      ubicacion['pais'],
    ].where((elemento) =>
        elemento != null && elemento.toString().trim().isNotEmpty).join(', ');
    return partes.isEmpty ? 'Ubicación no disponible' : partes;
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Fecha por confirmar';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    return '$dia/$mes/$anio';
  }

  String _formatearHora(Map<String, dynamic>? horaMap) {
    if (horaMap == null) return 'Horario por confirmar';
    final hora = horaMap['h'];
    final minuto = horaMap['m'];
    final horaTexto = (hora is int ? hora : int.tryParse('$hora') ?? 0)
        .toString()
        .padLeft(2, '0');
    final minutoTexto = (minuto is int ? minuto : int.tryParse('$minuto') ?? 0)
        .toString()
        .padLeft(2, '0');
    return '$horaTexto:$minutoTexto';
  }

  int _indiceProgreso(Map<String, dynamic> postulacion, Map<String, dynamic> trabajo) {
    final estado = (postulacion['estado'] as String? ?? '').toLowerCase();
    final estadoTrabajo = (postulacion['estadoTrabajo'] ?? trabajo['estadoTrabajo'])
            ?.toString()
            .toLowerCase() ??
        '';
    final estadoPago = (postulacion['estadoPago'] ?? trabajo['estadoPago'])
            ?.toString()
            .toLowerCase() ??
        '';
    final trabajoEnCurso = estadoTrabajo == 'en curso' ||
        estadoTrabajo == 'en_curso' ||
        estadoTrabajo == 'activo' ||
        estadoTrabajo == 'ejecutando' ||
        estadoTrabajo == 'realizando';
    final trabajoCompletado = postulacion['trabajoCompletado'] == true ||
        estadoTrabajo == 'completado' ||
        estadoTrabajo == 'realizado' ||
        estadoTrabajo == 'finalizado';
    final pagoEnCurso = estadoPago == 'en_curso' ||
        estadoPago == 'procesando' ||
        estadoPago == 'en proceso';
    final pagoCompletado = estadoPago == 'completado' || estadoPago == 'pagado';

    if (estado == 'rechazado') {
      return -1;
    }

    int indice = 0;

    if (estado == 'aceptado' || estado == 'confirmado') {
      indice = 1;
    }
    if (estado == 'confirmado') {
      indice = 2;
    }
    if (trabajoEnCurso || trabajoCompletado) {
      indice = 3;
    }
    if (trabajoCompletado) {
      indice = 4;
    }
    if (pagoEnCurso || pagoCompletado) {
      indice = 5;
    }
    if (pagoCompletado) {
      indice = 6;
    }

    return indice;
  }

  _PasoEstado _estadoPaso(int paso, int indiceActual) {
    if (indiceActual < 0) {
      return _PasoEstado.pendiente;
    }
    if (indiceActual > paso) {
      return _PasoEstado.completado;
    }
    if (indiceActual == paso) {
      return _PasoEstado.actual;
    }
    return _PasoEstado.pendiente;
  }

  Color _colorPaso(_PasoEstado estado) {
    switch (estado) {
      case _PasoEstado.completado:
        return Colors.green;
      case _PasoEstado.actual:
        return const Color(0xFF7B0997);
      case _PasoEstado.pendiente:
        return Colors.grey.shade400;
    }
  }

  Widget _buildPaso(
    BuildContext context, {
    required int indice,
    required String titulo,
    required String descripcion,
    required _PasoEstado estado,
    required bool esUltimo,
  }) {
    final color = _colorPaso(estado);
    final textoColor = estado == _PasoEstado.pendiente
        ? Colors.grey.shade600
        : Colors.black87;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: estado == _PasoEstado.completado ? color : Colors.white,
                border: Border.all(color: color, width: 2),
              ),
              alignment: Alignment.center,
              child: estado == _PasoEstado.completado
                  ? Icon(Icons.check, size: 20, color: Colors.white)
                  : Text(
                      '${indice + 1}',
                      style: TextStyle(
                        color: estado == _PasoEstado.actual ? color : Colors.black87,
                        fontWeight: estado == _PasoEstado.actual
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
            ),
            if (!esUltimo)
              Container(
                width: 2,
                height: 48,
                color: esUltimo
                    ? Colors.transparent
                    : (estado == _PasoEstado.pendiente
                        ? Colors.grey.shade300
                        : color.withOpacity(0.5)),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textoColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fechaTrabajoTs = trabajo['fechaTrabajo'] as Timestamp?;
    final fechaTrabajo = fechaTrabajoTs?.toDate();
    final horaInicio = trabajo['horaInicio'] as Map<String, dynamic>?;
    final empresa = trabajo['empresa'] ?? '';
    final estadoActual = (postulacion['estado'] as String? ?? '').toLowerCase();
    final progreso = _indiceProgreso(postulacion, trabajo);

    final pasos = [
      (
        titulo: 'Esperando selección',
        descripcion:
            'Tu postulación está en revisión por parte del administrador.',
        estado: _estadoPaso(0, progreso),
      ),
      (
        titulo: 'Postulación aceptada',
        descripcion:
            'El administrador te eligió para este trabajo. Revisa los detalles.',
        estado: _estadoPaso(1, progreso),
      ),
      (
        titulo: 'Trabajo confirmado',
        descripcion: 'Confirmaste tu asistencia y compromiso con el trabajo.',
        estado: _estadoPaso(2, progreso),
      ),
      (
        titulo: 'Trabajo en curso',
        descripcion:
            '¡Llegó el día! Preséntate y avísanos si surge algún inconveniente.',
        estado: _estadoPaso(3, progreso),
      ),
      (
        titulo: 'Trabajo completado',
        descripcion:
            'Una vez realizado el trabajo aparecerá como completado automáticamente.',
        estado: _estadoPaso(4, progreso),
      ),
      (
        titulo: 'Pago en curso',
        descripcion:
            'Estamos procesando tu pago. Te avisaremos cuando esté listo.',
        estado: _estadoPaso(5, progreso),
      ),
      (
        titulo: 'Pago completado',
        descripcion: 'Tu pago fue depositado en tu cuenta registrada.',
        estado: _estadoPaso(6, progreso),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: _TrabajoHeaderImage(trabajo: trabajo),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trabajo['titulo'] ?? 'Trabajo sin título',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (empresa is String && empresa.isNotEmpty)
                      Text(
                        empresa,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF7B0997), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatearUbicacion(
                                trabajo['ubicacion'] as Map<String, dynamic>?),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.event,
                            color: Color(0xFF7B0997), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _formatearFecha(fechaTrabajo),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            color: Color(0xFF7B0997), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _formatearHora(horaInicio),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payments,
                            color: Color(0xFF7B0997), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '\$${trabajo['precio']?.toString() ?? 'N/D'} brutos',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _EstadoActualBanner(estadoActual: estadoActual, progreso: progreso),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Progreso de tu postulación',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < pasos.length; i++)
                _buildPaso(
                  context,
                  indice: i,
                  titulo: pasos[i].titulo,
                  descripcion: pasos[i].descripcion,
                  estado: pasos[i].estado,
                  esUltimo: i == pasos.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Color(0xFF7B0997), width: 1.5),
            foregroundColor: const Color(0xFF7B0997),
          ),
          icon: const Icon(Icons.search),
          label: const Text(
            'Seguir buscando trabajos',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _TrabajoHeaderImage extends StatelessWidget {
  final Map<String, dynamic> trabajo;

  const _TrabajoHeaderImage({required this.trabajo});

  @override
  Widget build(BuildContext context) {
    final portada = trabajo['imagenPortada'] ?? trabajo['imagen'];

    if (portada is String && portada.isNotEmpty) {
      return Image.network(
        portada,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _PlaceholderBanner(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    return const _PlaceholderBanner();
  }
}

class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.black87,
      alignment: Alignment.center,
      child: const Icon(
        Icons.business_center,
        color: Colors.white,
        size: 72,
      ),
    );
  }
}

class _EstadoActualBanner extends StatelessWidget {
  final String estadoActual;
  final int progreso;

  const _EstadoActualBanner({
    required this.estadoActual,
    required this.progreso,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String titulo;
    String descripcion;

    switch (estadoActual) {
      case 'confirmado':
        backgroundColor = const Color(0xFFE6F4EA);
        textColor = Colors.green.shade800;
        titulo = '¡Trabajo confirmado!';
        descripcion =
            'Recuerda asistir el día acordado. Te avisaremos cuando tu pago esté listo.';
        break;
      case 'aceptado':
        backgroundColor = const Color(0xFFE8E2F3);
        textColor = const Color(0xFF4A0A63);
        titulo = 'Postulación aceptada';
        descripcion =
            'Confirma tu asistencia lo antes posible para asegurar tu cupo.';
        break;
      case 'rechazado':
        backgroundColor = const Color(0xFFFDE7E9);
        textColor = Colors.red.shade800;
        titulo = 'Postulación rechazada';
        descripcion =
            'Esta oportunidad ya no está disponible para ti. Revisa otras ofertas.';
        break;
      default:
        if (progreso <= 0) {
          backgroundColor = const Color(0xFFE8F0FE);
          textColor = const Color(0xFF174EA6);
          titulo = 'Postulación en revisión';
          descripcion =
              'Te avisaremos cuando el administrador revise tu postulación.';
        } else {
          backgroundColor = const Color(0xFFE8F0FE);
          textColor = const Color(0xFF174EA6);
          titulo = 'Seguimos contigo';
          descripcion =
              'Mantente atento a las actualizaciones sobre tu postulación.';
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
