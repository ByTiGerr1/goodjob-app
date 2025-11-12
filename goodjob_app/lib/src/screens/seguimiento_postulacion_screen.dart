import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/utils/trabajo_schedule_utils.dart';
import 'package:goodjob_app/theme/app_colors.dart';

import 'instrucciones_trabajo_screen.dart';
import 'trabajo_en_curso/mapa_checkin_screen.dart'; // Importamos la nueva pantalla
import 'trabajo_en_curso/trabajo_en_curso_screen.dart';

// =============================================================================
// LÓGICA DE ESTADOS DEL TRABAJO Y SEGUIMIENTO
// =============================================================================
// Esta pantalla muestra el progreso de una postulación basándose en el ESTADO
// DEL TRABAJO (campo 'estado' en Firestore) según el modelo EstadoTrabajo:
//
// MAPEO DE ESTADOS DEL TRABAJO -> PASOS DE PROGRESO:
// ┌─────────────────────────────────────────────────────────────────────────┐
// │ Estado Trabajo │ Paso │ Título del Paso           │ Descripción         │
// ├────────────────┼──────┼───────────────────────────┼─────────────────────┤
// │ (sin aceptar)  │  0   │ Postulación enviada       │ Esperando revisión  │
// │ activo         │  1   │ Postulación enviada       │ Con postulación     │
// │ porConfirmar   │  2   │ Seleccionado/a            │ Debe confirmar      │
// │ pendiente      │  3   │ Asistencia confirmada     │ Listo para trabajar │
// │ enCurso        │  4   │ Trabajo en curso          │ Realizando trabajo  │
// │ porRevisar     │  5   │ Tarea finalizada          │ En revisión         │
// │ porPagar       │  6   │ Pago en proceso           │ Procesando pago     │
// │ finalizado     │  7   │ Pago completado           │ Trabajo terminado   │
// │ rechazado      │ -1   │ Postulación rechazada     │ No seleccionado     │
// └────────────────┴──────┴───────────────────────────┴─────────────────────┘
//
// NOTA: El estado 'finalizado' con 'pagado: true' indica paso 7 (completado)
// =============================================================================

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
    final inicioProgramado =  extractTrabajoStart(trabajo);

    if (inicioTrabajo != null && finTrabajo == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrabajoEnCursoScreen(
            trabajoId: widget.trabajoId,
            trabajo: trabajo,
            startTime: inicioTrabajo,
            scheduledStartTime: inicioProgramado,
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
    return extractTrabajoStart(t);
  }

  DateTime? _getTrabajoEndDateTime(Map<String, dynamic> t) {
    return extractTrabajoEnd(t);
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

  String _formatearHora(DateTime? inicioProgramado,
      {String fallback = 'Horario por confirmar'}) {
    if (inicioProgramado == null) return fallback;

    final horaTexto = inicioProgramado.hour.toString().padLeft(2, '0');
    final minutoTexto = inicioProgramado.minute.toString().padLeft(2, '0');
    return '$horaTexto:$minutoTexto';
  }

  String _normalizarEstado(dynamic valor) {
    if (valor is String) {
      return valor.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    }
    return '';
  }

  /// Verifica si el usuario tiene una postulación aceptada para este trabajo
  bool _tienePostulacionAceptada(Map<String, dynamic> postulacion) {
    final estadoPostulacion = _normalizarEstado(postulacion['estado']);
    final estadoAsignacion = _normalizarEstado(postulacion['estadoAsignacion']);
    
    // Verificar estados que indican aceptación
    const estadosAceptados = {
      'aceptado',
      'aceptada',
      'confirmado',
      'confirmada',
      'asignado',
      'asignada',
      'seleccionado',
      'seleccionada'
    };
    
    return estadosAceptados.contains(estadoPostulacion) ||
           estadosAceptados.contains(estadoAsignacion) ||
           postulacion['aceptado'] == true ||
           postulacion['confirmadoEn'] != null;
  }

  /// Determina el progreso basado en el estado del TRABAJO (no de la postulación)
  /// Retorna un índice de 0 a 7 que representa cada paso del proceso:
  /// 0: Postulación enviada (esperando revisión)
  /// 1: Postulación enviada pero con postulación aceptada (estado activo del trabajo)
  /// 2: Seleccionado (porConfirmar) 
  /// 3: Asistencia confirmada (pendiente)
  /// 4: Trabajo en curso (enCurso)
  /// 5: Tarea finalizada (porRevisar)
  /// 6: Pago en proceso (porPagar)
  /// 7: Pago completado (finalizado + pagado)
  /// Retorna -1 si la postulación fue rechazada
  int _indiceProgreso(
    Map<String, dynamic> postulacion,
    Map<String, dynamic> trabajo,
  ) {
    // Verificar si la postulación fue rechazada
    final estadoPostulacion = _normalizarEstado(postulacion['estado']);
    final estadoAsignacion = _normalizarEstado(postulacion['estadoAsignacion']);
    
    if (estadoPostulacion == 'rechazado' || 
        estadoPostulacion == 'rechazada' ||
        estadoAsignacion == 'rechazado' ||
        estadoAsignacion == 'rechazada') {
      return -1; // Rechazado
    }

    // Verificar si el usuario tiene postulación aceptada
    final tienePostulacion = _tienePostulacionAceptada(postulacion);
    
    // Obtener el estado del trabajo normalizado
    final estadoTrabajo = _normalizarEstado(trabajo['estado']);
    final pagado = trabajo['pagado'] == true;

    // Mapeo de estados según el modelo EstadoTrabajo:
    switch (estadoTrabajo) {
      case 'activo':
      case 'abierto':
        // Si tiene postulación aceptada, está en paso 1, sino en paso 0
        return tienePostulacion ? 1 : 0;
      
      case 'porconfirmar':
        return 2; // Seleccionado/Aceptado
      
      case 'pendiente':
        return 3; // Asistencia confirmada
      
      case 'encurso':
        return 4; // Trabajo en curso
      
      case 'porrevisar':
        return 5; // Tarea finalizada
      
      case 'porpagar':
        return 6; // Pago en proceso
      
      case 'finalizado':
        return pagado ? 7 : 6; // Pago completado si pagado=true, sino pago en proceso
      
      case 'cancelado':
      case 'rechazado':
        return -1; // Cancelado/Rechazado
      
      default:
        // Si no coincide con ningún estado conocido, inferir por otros campos
        if (pagado) return 7;
        if (postulacion['trabajoCompletado'] == true) return 5;
        if (postulacion['inicioTrabajoReal'] != null) return 4;
        if (postulacion['confirmadoEn'] != null) return 3;
        if (tienePostulacion) return 1;
        return 0; // Por defecto, postulación enviada esperando revisión
    }
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
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isPrimary ? Colors.green.shade700 : Colors.grey.shade700,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  void _navegarAInstrucciones(BuildContext context) {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            builder: (ctx) => InstruccionesTrabajoScreen(),
          ),
        )
        .then((iniciarTrabajo) {
          // Marcar como vistas al regresar de la pantalla de instrucciones
          if (ModalRoute.of(context)?.isCurrent == true) {
            onInstruccionesVistas();

            if (iniciarTrabajo == true) {
              onIniciarTarea(context, trabajo, postulacion);
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final fechaTrabajo = _getTrabajoStartDateTime(trabajo);
    final fechaFinProgramada = _getTrabajoEndDateTime(trabajo);
    final empresa = trabajo['empresa'] ?? '';
    
    // Calcular progreso basado en el estado del trabajo
    final progreso = _indiceProgreso(postulacion, trabajo);
    
    // Determinar estado actual para mostrar
    String estadoActual;
    if (progreso == -1) {
      estadoActual = 'rechazado';
    } else if (progreso >= 7) {
      estadoActual = 'pagado';
    } else if (progreso >= 6) {
      estadoActual = 'pago_en_proceso';
    } else if (progreso >= 5) {
      estadoActual = 'tarea_finalizada';
    } else if (progreso >= 4) {
      estadoActual = 'en_curso';
    } else if (progreso >= 3) {
      estadoActual = 'confirmado';
    } else if (progreso >= 2) {
      estadoActual = 'aceptado';
    } else if (progreso >= 1) {
      estadoActual = 'enviado_aceptado'; // Postulación enviada pero ya aceptada
    } else {
      estadoActual = 'pendiente'; // Esperando revisión
    }

    // LÓGICA DE DÍA Y ESTADO DE TRABAJO
    final esTrabajoActivo = progreso >= 2 && progreso < 5; // Desde aceptado hasta antes de finalizado
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
    final fechaReferencia =
        fechaTrabajo ?? fechaFinProgramada ?? inicioTrabajoReal ?? finTrabajoReal;
    final horarioInicio = inicioTrabajoReal ?? fechaTrabajo;
    final horarioFin = finTrabajoReal ?? fechaFinProgramada;
    final tieneCheckInActivo =
        inicioTrabajoReal != null && finTrabajoReal == null && progreso == 4; // Solo en estado "en curso"

    final pasos = [
      (
        titulo: 'Postulación enviada',
        descripcion:
            'Tu solicitud ha sido registrada y está esperando ser revisada por el administrador.',
        estado: _estadoPaso(0, progreso),
      ),
      (
        titulo: 'Seleccionado/a',
        descripcion:
            '¡Felicidades! Fuiste elegido/a. Debes confirmar tu asistencia.',
        estado: _estadoPaso(1, progreso),
      ),
      (
        titulo: 'Asistencia confirmada',
        descripcion:
            'Has confirmado tu compromiso. Revisa las instrucciones antes del día de inicio.',
        estado: _estadoPaso(2, progreso),
      ),
      (
        titulo: 'Trabajo en curso',
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoChip(
                          Icons.location_on,
                          _formatearUbicacion(
                            trabajo['ubicacion'] as Map<String, dynamic>?,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildInfoChip(
                          Icons.event,
                          _formatearFecha(fechaReferencia),
                        ),
                        const SizedBox(height: 10),
                        _buildInfoChip(
                          Icons.access_time,
                          '${_formatearHora(horarioInicio, fallback: 'Por confirmar')} - ${_formatearHora(horarioFin, fallback: 'Por confirmar')}',
                        ),
                        const SizedBox(height: 10),
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
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      'home',
                      (route) => false,
                      arguments: const {'initialIndex': 0},
                    );
                  },
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
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      'home',
                      (route) => false,
                      arguments: const {'initialIndex': 0},
                    );
                  },
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
      case 'pagado':
        backgroundColor = const Color(0xFFE6F4EA);
        textColor = greenBase;
        icon = Icons.payments_outlined;
        titulo = '¡Pago completado!';
        descripcion = 'Tu pago ha sido realizado con éxito. Revisa tu cuenta bancaria.';
        break;
      case 'pago_en_proceso':
        backgroundColor = const Color(0xFFF0E4F3);
        textColor = _PRIMARY_COLOR;
        icon = Icons.account_balance_wallet_outlined;
        titulo = 'Pago en proceso';
        descripcion = 'Tu pago está siendo procesado y se depositará en tu cuenta registrada.';
        break;
      case 'tarea_finalizada':
        backgroundColor = const Color(0xFFE8F0FE);
        textColor = blueBase;
        icon = Icons.task_alt;
        titulo = 'Tarea finalizada';
        descripcion = 'El trabajo ha terminado. Esperando aprobación del administrador.';
        break;
      case 'en_curso':
        backgroundColor = const Color(0xFFFFF8E1);
        textColor = Colors.orange.shade800;
        icon = Icons.work_outline;
        titulo = 'Trabajo en curso';
        descripcion = 'El trabajo está en progreso. Completa todas las tareas asignadas.';
        break;
      case 'confirmado':
        backgroundColor = const Color(0xFFE6F4EA);
        textColor = greenBase;
        icon = Icons.event_available;
        titulo = '¡Trabajo confirmado!';
        descripcion = 'Recuerda asistir el día acordado. Revisa las instrucciones antes de iniciar.';
        break;
      case 'aceptado':
        backgroundColor = const Color(0xFFF0E4F3);
        textColor = _PRIMARY_COLOR;
        icon = Icons.thumb_up_alt_outlined;
        titulo = 'Postulación aceptada';
        descripcion = 'Confirma tu asistencia lo antes posible para asegurar tu cupo.';
        break;
      case 'enviado_aceptado':
        backgroundColor = const Color(0xFFE8F0FE);
        textColor = blueBase;
        icon = Icons.check_circle_outline;
        titulo = 'Postulación aceptada';
        descripcion = 'Tu postulación fue aceptada. Esperando que el administrador confirme la asignación.';
        break;
      case 'rechazado':
        backgroundColor = const Color(0xFFFDE7E9);
        textColor = redBase;
        icon = Icons.cancel_outlined;
        titulo = 'Postulación rechazada';
        descripcion = 'Esta oportunidad ya no está disponible para ti. Revisa otras ofertas.';
        break;
      default: // Pendiente
        backgroundColor = const Color(0xFFE8F0FE);
        textColor = blueBase;
        icon = Icons.access_time_outlined;
        titulo = 'Postulación en revisión';
        descripcion = 'Te avisaremos cuando el administrador revise tu postulación.';
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
