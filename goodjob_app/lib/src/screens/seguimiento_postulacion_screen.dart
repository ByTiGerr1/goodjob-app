import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/theme/app_colors.dart';

import 'instrucciones_trabajo_screen.dart';
import 'mapa_checkin_screen.dart'; // Importamos la nueva pantalla
import 'trabajo_en_curso_screen.dart';

// Definición de estados
enum _PasoEstado { completado, actual, pendiente }

// Colores consistentes
const Color _PRIMARY_COLOR = AppColors.primary; // Morado principal
const Color _ACCENT_COLOR = AppColors.accent; // AMARILLO BRILLANTE/DORADO
const Color _WARNING_COLOR = AppColors.warning; // Naranja para advertencias UX

class SeguimientoPostulacionScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const SeguimientoPostulacionScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<SeguimientoPostulacionScreen> createState() =>
      _SeguimientoPostulacionScreenState();
}

// Se define el tipo de función para el callback de iniciar tarea.
typedef IniciarTareaCallback = void Function(
    BuildContext context, Map<String, dynamic> trabajo,
    Map<String, dynamic> postulacion);

class _SeguimientoPostulacionScreenState
    extends State<SeguimientoPostulacionScreen>
    with SingleTickerProviderStateMixin {
  bool _instruccionesVistas = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _marcarInstruccionesVistas() {
    setState(() {
      _instruccionesVistas = true;
    });
    _animationController.stop();
  }

  // CORRECCIÓN CLAVE: Esta función debe recibir el BuildContext y el mapa de trabajo
  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void _iniciarTarea(BuildContext context, Map<String, dynamic> trabajo,
      Map<String, dynamic> postulacion) {
    final inicioTrabajo = _parseDateTime(
          postulacion['inicioTrabajoReal'] ?? trabajo['inicioTrabajoReal'],
        ) ??
        _parseDateTime(postulacion['inicioTrabajoLocal']);
    final finTrabajo = _parseDateTime(
      postulacion['finTrabajoReal'] ?? trabajo['finTrabajoReal'],
    );

    if (inicioTrabajo != null && finTrabajo == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrabajoEnCursoScreen(
            trabajoId: widget.trabajoId,
            trabajo: trabajo,
            startTime: inicioTrabajo,
          ),
        ),
      );
      return;
    }

    if (!_instruccionesVistas) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '¡Debes revisar las instrucciones primero!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _ACCENT_COLOR,
        ),
      );
      return;
    }

    // NAVEGACIÓN SOLICITADA: Navegar a la pantalla del mapa de Check-in
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MapaCheckinScreen(trabajoId: widget.trabajoId, trabajo: trabajo),
      ),
    );
  }

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
        .doc(widget.trabajoId)
        .snapshots();

    final trabajoStream = FirebaseFirestore.instance
        .collection('trabajos')
        .doc(widget.trabajoId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de Postulación'),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: postulacionStream,
        builder: (context, postulacionSnapshot) {
          if (postulacionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!postulacionSnapshot.hasData ||
              !postulacionSnapshot.data!.exists) {
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
                  trabajoSnapshot.data?.data() ??
                  Map<String, dynamic>.from(widget.trabajo);

              return _PostulacionContent(
                postulacion: postulacionData,
                trabajo: trabajoData,
                instruccionesVistas: _instruccionesVistas,
                onInstruccionesVistas: _marcarInstruccionesVistas,
                // CORRECCIÓN DE TIPO: Pasamos una función que encapsula la llamada con el BuildContext y el mapa
                onIniciarTarea: (c, t, p) => _iniciarTarea(c, t, p),
                animationController: _animationController,
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET PRINCIPAL DE CONTENIDO ---

class _PostulacionContent extends StatelessWidget {
  final Map<String, dynamic> postulacion;
  final Map<String, dynamic> trabajo;
  final bool instruccionesVistas;
  final VoidCallback onInstruccionesVistas;
  // CORRECCIÓN DE TIPO: Ahora espera el BuildContext y el mapa de trabajo
  final IniciarTareaCallback onIniciarTarea;
  final AnimationController animationController;

  const _PostulacionContent({
    required this.postulacion,
    required this.trabajo,
    required this.instruccionesVistas,
    required this.onInstruccionesVistas,
    required this.onIniciarTarea,
    required this.animationController,
  });

  // --- LÓGICA DE FORMATO Y ESTADO (Mantenida) ---

  // Lógica de lectura dual (Antiguo y Nuevo esquema)

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _getTrabajoStartDateTime(Map<String, dynamic> t) {
    Timestamp? ts = t['fechaInicioTrabajo'] as Timestamp?;
    ts ??= t['fechaTrabajo'] as Timestamp?;
    return ts?.toDate();
  }

  Map<String, dynamic>? _getHoraInicio(Map<String, dynamic> t) {
    if (t['horaInicio'] is Map<String, dynamic>) {
      return t['horaInicio'] as Map<String, dynamic>;
    }
    // Si la fecha de inicio es del esquema nuevo (DateTime), no hay hora map
    return null;
  }

  Map<String, dynamic>? _getHoraFin(Map<String, dynamic> t) {
    if (t['horaFin'] is Map<String, dynamic>) {
      return t['horaFin'] as Map<String, dynamic>;
    }
    return null;
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'Ubicación no disponible';
    final partes =
        [ubicacion['direccion'], ubicacion['ciudad'], ubicacion['pais']]
            .where(
              (elemento) =>
                  elemento != null && elemento.toString().trim().isNotEmpty,
            )
            .join(', ');
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
    final horaInicioDateTime = _getTrabajoStartDateTime(trabajo);

    if (horaMap == null && horaInicioDateTime != null) {
      // Intenta usar la hora del DateTime combinado si no hay mapa de hora
      final horaTexto = horaInicioDateTime.hour.toString().padLeft(2, '0');
      final minutoTexto = horaInicioDateTime.minute.toString().padLeft(2, '0');
      return '$horaTexto:$minutoTexto';
    }

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

  String _normalizarEstado(dynamic valor) {
    if (valor is String) {
      return valor.trim().toLowerCase();
    }
    return '';
  }

  bool _esEstadoAceptado(String estado) {
    switch (estado) {
      case 'aceptado':
      case 'aceptada':
      case 'asignado':
      case 'asignada':
      case 'seleccionado':
      case 'seleccionada':
      case 'confirmado':
      case 'confirmada':
        return true;
      default:
        return false;
    }
  }

  String _estadoPostulacionPrincipal(Map<String, dynamic> postulacion) {
    final candidatos = [
      postulacion['estado'],
      postulacion['estadoPostulacion'],
      postulacion['estadoAsignacion'],
    ];

    for (final candidato in candidatos) {
      final normalizado = _normalizarEstado(candidato);
      if (normalizado.isNotEmpty) {
        return normalizado;
      }
    }

    return '';
  }

  bool _tieneConfirmacionRegistrada(
    Map<String, dynamic> postulacion,
    Map<String, dynamic> trabajo,
    String estadoPrincipal,
  ) {
    if (estadoPrincipal == 'confirmado') return true;

    final estadoAsignacion = _normalizarEstado(postulacion['estadoAsignacion']);
    if (estadoAsignacion == 'confirmado') return true;

    final estadoAsignacionTrabajo = _normalizarEstado(
      trabajo['estadoAsignacion'],
    );
    if (estadoAsignacionTrabajo == 'confirmado') return true;

    if (postulacion['asistenciaConfirmada'] == true) return true;
    if (trabajo['asistenciaConfirmada'] == true) return true;
    if (postulacion['confirmadoEn'] != null) return true;
    if (trabajo['confirmadoEn'] != null) return true;

    return false;
  }

  int _indiceProgreso(
    Map<String, dynamic> postulacion,
    Map<String, dynamic> trabajo, {
    String? estadoPrincipal,
    bool? confirmacionRegistrada,
  }) {
    final estado = estadoPrincipal ?? _estadoPostulacionPrincipal(postulacion);
    final estadoAsignacion = _normalizarEstado(postulacion['estadoAsignacion']);
    final estadoTrabajo = _normalizarEstado(
      postulacion['estadoTrabajo'] ??
          trabajo['estadoTrabajo'] ??
          trabajo['estado'],
    );
    final estadoPago = _normalizarEstado(
      postulacion['estadoPago'] ??
          trabajo['estadoPago'] ??
          trabajo['pagoEstado'],
    );
    final confirmacion =
        confirmacionRegistrada ??
        _tieneConfirmacionRegistrada(postulacion, trabajo, estado);
    final aceptadoFlag =
        postulacion['aceptado'] == true ||
        postulacion['asignado'] == true ||
        trabajo['aceptado'] == true ||
        trabajo['asignado'] == true;

    final trabajoEnCurso =
        estadoTrabajo == 'en curso' ||
        estadoTrabajo == 'en_curso' ||
        estadoTrabajo == 'activo' ||
        estadoTrabajo == 'abierto' ||
        estadoTrabajo == 'ejecutando' ||
        estadoTrabajo == 'realizando';
    final trabajoCompletado =
        postulacion['trabajoCompletado'] == true ||
        estadoTrabajo == 'completado' ||
        estadoTrabajo == 'realizado' ||
        estadoTrabajo == 'finalizado' ||
        estadoTrabajo == 'pendiente_revision';
    final pagoEnCurso =
        estadoPago == 'en_curso' ||
        estadoPago == 'procesando' ||
        estadoPago == 'en proceso';
    final pagoCompletado = estadoPago == 'completado' || estadoPago == 'pagado';

    if (estado == 'rechazado' || estadoAsignacion == 'rechazado') return -1;

    final aceptado =
        aceptadoFlag ||
        _esEstadoAceptado(estado) ||
        _esEstadoAceptado(estadoAsignacion) ||
        confirmacion ||
        trabajoEnCurso ||
        trabajoCompletado ||
        pagoEnCurso ||
        pagoCompletado;

    final etapasCompletadas = <bool>[
      aceptado, // Etapa 0: Postulación enviada (implícita)
      aceptado, // Etapa 1: Postulación aceptada (Se evalúa con aceptado)
      confirmacion ||
          trabajoEnCurso ||
          trabajoCompletado ||
          pagoEnCurso ||
          pagoCompletado, // Etapa 2: Trabajo confirmado
      trabajoEnCurso ||
          trabajoCompletado ||
          pagoEnCurso ||
          pagoCompletado, // Etapa 3: Trabajo en curso
      trabajoCompletado ||
          pagoEnCurso ||
          pagoCompletado, // Etapa 4: Trabajo completado
      pagoEnCurso || pagoCompletado, // Etapa 5: Pago en curso
      pagoCompletado, // Etapa 6: Pago completado
    ];

    final siguientePendiente = etapasCompletadas.indexWhere(
      (completado) => !completado,
    );

    if (siguientePendiente == -1) {
      return etapasCompletadas.length;
    }

    return siguientePendiente;
  }

  _PasoEstado _estadoPaso(int paso, int indiceActual) {
    if (indiceActual < 0) return _PasoEstado.pendiente;
    if (indiceActual > paso) return _PasoEstado.completado;
    if (indiceActual == paso) return _PasoEstado.actual;
    return _PasoEstado.pendiente;
  }

  Color _colorPaso(_PasoEstado estado) {
    switch (estado) {
      case _PasoEstado.completado:
        return Colors.green.shade600;
      case _PasoEstado.actual:
        return _ACCENT_COLOR;
      case _PasoEstado.pendiente:
        return Colors.grey.shade400;
    }
  }

  // --- WIDGETS DE CONTENIDO ---

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. INDICADOR (Círculo y Línea)
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      estado == _PasoEstado.completado ||
                              estado == _PasoEstado.actual
                          ? color
                          : Colors.white,
                  border: Border.all(
                    color: color,
                    width: estado == _PasoEstado.pendiente ? 1 : 2,
                  ),
                ),
                alignment: Alignment.center,
                child: estado == _PasoEstado.completado
                    ? const Icon(Icons.check, size: 20, color: Colors.white)
                    : Text(
                        '${indice + 1}',
                        style: TextStyle(
                          color: estado == _PasoEstado.actual
                              ? (color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white)
                              : _PRIMARY_COLOR,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              if (!esUltimo)
                Container(
                  width: 2,
                  height: 48,
                  color: estado == _PasoEstado.completado
                      ? color.withOpacity(0.5)
                      : Colors.grey.shade300,
                ),
            ],
          ),
          const SizedBox(width: 16),
          // 2. TEXTO DE PASO
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textoColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {bool isPrimary = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isPrimary ? Colors.green.shade600 : _PRIMARY_COLOR,
          size: 20,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isPrimary ? Colors.green.shade700 : Colors.grey.shade700,
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  void _navegarAInstrucciones(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => InstruccionesTrabajoScreen())) // Añadido const
        .then((_) {
          // Marcar como vistas al regresar de la pantalla de instrucciones
          if (ModalRoute.of(context)?.isCurrent == true) {
            onInstruccionesVistas();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final fechaTrabajo = _getTrabajoStartDateTime(trabajo);
    final horaInicioMap = _getHoraInicio(trabajo);
    final empresa = trabajo['empresa'] ?? '';
    final estadoPrincipal = _estadoPostulacionPrincipal(postulacion);
    final confirmacionRegistrada = _tieneConfirmacionRegistrada(
      postulacion,
      trabajo,
      estadoPrincipal,
    );
    final estadoActual = confirmacionRegistrada
        ? 'confirmado'
        : estadoPrincipal;
    final progreso = _indiceProgreso(
      postulacion,
      trabajo,
      estadoPrincipal: estadoPrincipal,
      confirmacionRegistrada: confirmacionRegistrada,
    );

    // LÓGICA DE DÍA Y ESTADO DE TRABAJO
    final esTrabajoActivo = estadoActual == 'confirmado' && (progreso < 4);
    final isJobDay =
        fechaTrabajo != null &&
        (DateTime.now().isAfter(
              fechaTrabajo.subtract(const Duration(hours: 1)),
            ) &&
            DateTime.now().isBefore(fechaTrabajo.add(const Duration(days: 1))));

    final inicioTrabajoReal =
        _parseDate(postulacion['inicioTrabajoReal']) ??
            _parseDate(postulacion['inicioTrabajoLocal']) ??
            _parseDate(trabajo['inicioTrabajoReal']);
    final finTrabajoReal =
        _parseDate(postulacion['finTrabajoReal']) ??
            _parseDate(trabajo['finTrabajoReal']);
    final tieneCheckInActivo =
        inicioTrabajoReal != null && finTrabajoReal == null && esTrabajoActivo;

    final pasos = [
      (
        titulo: 'Postulación enviada',
        descripcion:
            'Tu solicitud ha sido registrada y está esperando ser revisada por el administrador.',
        estado: _estadoPaso(0, progreso),
      ),
      (
        titulo: 'Seleccionado/a (Aceptado)',
        descripcion:
            '¡Felicidades! Fuiste elegido/a. Debes confirmar tu asistencia en la pantalla anterior.',
        estado: _estadoPaso(1, progreso),
      ),
      (
        titulo: 'Asistencia confirmada',
        descripcion:
            'Has confirmado tu compromiso. Revisa las instrucciones antes del día de inicio.',
        estado: _estadoPaso(2, progreso),
      ),
      (
        titulo: 'Trabajo en curso (HOY)',
        descripcion:
            'Hoy es el día de la tarea. Haz Check-in al llegar y mantente en comunicación.',
        estado: _estadoPaso(3, progreso),
      ),
      (
        titulo: 'Tarea finalizada',
        descripcion:
            'El trabajo ha terminado. Ahora esperaremos la aprobación final del administrador.',
        estado: _estadoPaso(4, progreso),
      ),
      (
        titulo: 'Pago en proceso',
        descripcion:
            'Tu pago está siendo procesado y se depositará en tu cuenta registrada.',
        estado: _estadoPaso(5, progreso),
      ),
      (
        titulo: 'Pago completado',
        descripcion:
            '¡Tu pago ha sido realizado con éxito! Revisa tu cuenta bancaria.',
        estado: _estadoPaso(6, progreso),
      ),
    ];

    // Lógica para el botón principal
    Widget mainActionButton;
    if (tieneCheckInActivo) {
      mainActionButton = ElevatedButton.icon(
        onPressed: () => onIniciarTarea(context, trabajo, postulacion),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        icon: const Icon(Icons.play_circle_fill),
        label: const Text(
          'CONTINUAR TRABAJO',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (esTrabajoActivo) {
      if (!instruccionesVistas) {
        // Botón de Instrucciones (Obligatorio)
        mainActionButton = ElevatedButton.icon(
          onPressed: () => _navegarAInstrucciones(context),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _ACCENT_COLOR, // Fondo Amarillo Brillante
            foregroundColor: Colors.black, // Texto negro para contraste
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              // Borde de Advertencia Fijo
              side: const BorderSide(color: _WARNING_COLOR, width: 2.0),
            ),
            elevation: 4,
          ),
          icon: const Icon(Icons.list_alt, color: Colors.black),
          label: const Text(
            'VER INSTRUCCIONES',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        );
      } else {
        // Botón de Ir a Check-in (Instrucciones ya vistas)
        mainActionButton = ElevatedButton.icon(
          onPressed: () => onIniciarTarea(
            context,
            trabajo,
            postulacion,
          ), // Llamada con los argumentos corregidos
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: isJobDay ? Colors.green.shade600 : _PRIMARY_COLOR,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          // Ícono de Check-in para el día del trabajo
          icon: Icon(isJobDay ? Icons.fingerprint : Icons.task_alt),
          label: Text(
            isJobDay ? 'IR A CHECK-IN' : 'INICIAR TRABAJO',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }
    } else {
      // Placeholder para cuando no hay acción inmediata (por ejemplo, rechazado o completado)
      mainActionButton = const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tarjeta de información del trabajo (Mejorada visualmente)
        Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
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
                    const SizedBox(height: 4),
                    // Color de la empresa a Gris Oscuro
                    if (empresa is String && empresa.isNotEmpty)
                      Text(
                        empresa,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Fila de datos clave
                    Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: [
                        _buildInfoChip(
                          Icons.location_on,
                          _formatearUbicacion(
                            trabajo['ubicacion'] as Map<String, dynamic>?,
                          ),
                        ),
                        _buildInfoChip(
                          Icons.event,
                          _formatearFecha(fechaTrabajo),
                        ),
                        _buildInfoChip(
                          Icons.access_time,
                          _formatearHora(horaInicioMap),
                        ),
                        _buildInfoChip(
                          Icons.payments,
                          '${(trabajo['precio'] != null) ? FormatUtils.formatCurrency(trabajo['precio'].toDouble()) : 'N/D'} brutos',
                          isPrimary: true,
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

        // Banner de estado actual (centralizado)
        _EstadoActualBanner(estadoActual: estadoActual, progreso: progreso),

        const SizedBox(height: 24),

        // Timeline de progreso
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ruta del proceso (Tu progreso)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _PRIMARY_COLOR,
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
        ),

        const SizedBox(height: 32),

        // --- FILA DE BOTONES DE ACCIÓN (Lógica ajustada) ---
        Row(
          children: [
            // 1. Botón secundario/alternativo (Ver Instrucciones si está activo, Buscar Otros si no)
            if (esTrabajoActivo &&
                instruccionesVistas) // Solo mostrar si ya vió instrucciones o no es activo
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: _PRIMARY_COLOR, width: 1.5),
                    foregroundColor: _PRIMARY_COLOR,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Buscar otros',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else if (!esTrabajoActivo)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: _PRIMARY_COLOR, width: 1.5),
                    foregroundColor: _PRIMARY_COLOR,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                  label: const Text(
                    'Buscar otros',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else if (esTrabajoActivo && !instruccionesVistas)
              Expanded(
                child: mainActionButton, // Usa el botón de VER INSTRUCCIONES
              ),

            // 2. Espacio y Botón principal (solo si el trabajo está activo Y ya vio instrucciones)
            if (esTrabajoActivo && instruccionesVistas) ...[
              const SizedBox(width: 12),
              Expanded(child: mainActionButton),
            ],
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Componentes de la Interfaz (Mantenidos)
// -----------------------------------------------------------------------------

class _TrabajoHeaderImage extends StatelessWidget {
  final Map<String, dynamic> trabajo;

  const _TrabajoHeaderImage({required this.trabajo});

  @override
  Widget build(BuildContext context) {
    // Busca la nueva URL de la imagen principal, luego los fallbacks
    final imagenUrl = trabajo['imagenPrincipalUrl'] as String? ??
        trabajo['imagenPortada'] as String? ??
        trabajo['imagen'] as String?;
    const height = 200.0;

    if (imagenUrl != null && imagenUrl.isNotEmpty) {
      return Image.network(
        imagenUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PlaceholderBanner(height: height),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: height,
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

    return const _PlaceholderBanner(height: height);
  }
}

class _PlaceholderBanner extends StatelessWidget {
  final double height;
  const _PlaceholderBanner({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: _PRIMARY_COLOR.withOpacity(0.8),
      alignment: Alignment.center,
      child: const Icon(Icons.business_center, color: Colors.white, size: 72),
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
    IconData icon;

    // Colores base para los estados
    final Color blueBase = const Color(0xFF174EA6);
    final Color greenBase = Colors.green.shade800;
    final Color redBase = Colors.red.shade800;

    switch (estadoActual) {
      case 'confirmado':
        backgroundColor = const Color(0xFFE6F4EA);
        textColor = greenBase;
        icon = Icons.event_available;
        titulo = '¡Trabajo confirmado!';
        // Descripción con recordatorio de instrucciones
        descripcion =
            'Recuerda asistir el día acordado. Revisa las instrucciones antes de iniciar.';
        break;
      case 'aceptado':
        backgroundColor = const Color(0xFFF0E4F3); // Morado claro
        textColor = _PRIMARY_COLOR;
        icon = Icons.thumb_up_alt_outlined;
        titulo = 'Postulación aceptada';
        descripcion =
            'Confirma tu asistencia lo antes posible para asegurar tu cupo.';
        break;
      case 'rechazado':
        backgroundColor = const Color(0xFFFDE7E9);
        textColor = redBase;
        icon = Icons.cancel_outlined;
        titulo = 'Postulación rechazada';
        descripcion =
            'Esta oportunidad ya no está disponible para ti. Revisa otras ofertas.';
        break;
      default: // Pendiente o en proceso
        backgroundColor = const Color(0xFFE8F0FE);
        textColor = blueBase;
        icon = Icons.access_time_outlined;
        if (progreso <= 0) {
          titulo = 'Postulación en revisión';
          descripcion =
              'Te avisaremos cuando el administrador revise tu postulación.';
        } else {
          titulo = 'Seguimos procesando';
          descripcion =
              'Tu pago está siendo procesado o tu tarea está en revisión final.';
        }
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.3)), // Borde sutil
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 18, // Título un poco más grande
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.9),
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
