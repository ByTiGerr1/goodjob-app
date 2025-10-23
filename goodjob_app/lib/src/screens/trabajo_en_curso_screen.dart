import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:goodjob_app/src/utils/location_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/postulacion_service.dart';
import '../services/storage_service.dart';

// --- CONSTANTES GLOBALES (MOVIDAS AQUI PARA ACCESO EN EL MODAL) ---
const Color _PRIMARY_COLOR = Color(0xFF7B0997);
const Color _ACCENT_COLOR = Color(0xFFFFD900);
const Color _SUCCESS_COLOR = Color(0xFF4CAF50); // Verde
// --- FIN CONSTANTES GLOBALES ---

enum EvidenceStage { inicio, medio, finalizacion }

extension EvidenceStageX on EvidenceStage {
  String get id {
    switch (this) {
      case EvidenceStage.inicio:
        return 'inicio';
      case EvidenceStage.medio:
        return 'medio';
      case EvidenceStage.finalizacion:
        return 'final';
    }
  }

  String get label {
    switch (this) {
      case EvidenceStage.inicio:
        return 'Inicio';
      case EvidenceStage.medio:
        return '50% del trabajo';
      case EvidenceStage.finalizacion:
        return 'Finalización';
    }
  }

  String get description {
    switch (this) {
      case EvidenceStage.inicio:
        return 'Foto al comenzar el trabajo.';
      case EvidenceStage.medio:
        return 'Foto cuando alcanzas el 50% del tiempo estimado.';
      case EvidenceStage.finalizacion:
        return 'Foto al terminar el trabajo.';
    }
  }
}

// --- MODELO DE DATOS PARA INSTRUCCIONES ---
class Instruccion {
  final int paso;
  final String titulo;
  final String descripcion;

  Instruccion({
    required this.paso,
    required this.titulo,
    required this.descripcion,
  });
}
// --- FIN MODELO DE DATOS ---

// Simulación de la pantalla de instrucciones (debe ser reemplazada por tu implementacion real)
// Ya no la navegamos, la mostramos en un modal.
// import 'instrucciones_trabajo_screen.dart';

class TrabajoEnCursoScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;
  final DateTime startTime;

  const TrabajoEnCursoScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
    required this.startTime,
  });

  @override
  State<TrabajoEnCursoScreen> createState() => _TrabajoEnCursoScreenState();
}

class _TrabajoEnCursoScreenState extends State<TrabajoEnCursoScreen> {
  late LatLng _trabajoCoords;
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _evidenciasSubscription;

  final StorageService _storageService = StorageService();
  final PostulacionService _postulacionService = PostulacionService();
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _evidencias = [];
  final Set<EvidenceStage> _skippedStages = <EvidenceStage>{};
  bool _isUploadingEvidence = false;
  bool _isSendingEvidences = false;
  EvidenceStage? _uploadingStage;

  DateTime? _scheduledStartTime;
  DateTime? _scheduledEndTime;
  Duration? _expectedDuration;
  Timer? _nowTimer;
  DateTime _now = DateTime.now();

  // --- CONFIGURACION DE LA ZONA DELIMITADA ---
  static const double _CHECKIN_RADIUS_METERS = 50.0;
  static const Duration _EVIDENCE_WINDOW = Duration(minutes: 5);
  // Las constantes de color se eliminaron de aqui

  @override
  void initState() {
    super.initState();
    _parseTrabajoCoords();
    _initializeSchedule();
    _startLocationUpdates();
    _subscribeToEvidencias();
    _startNowTimer();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _evidenciasSubscription?.cancel();
    _nowTimer?.cancel();
    super.dispose();
  }

  void _parseTrabajoCoords() {
    final ubicacion = widget.trabajo['ubicacion'] as Map<String, dynamic>?;
    final coords = extractLatLngFromUbicacion(ubicacion);

    _trabajoCoords = coords ?? const LatLng(-33.447487, -70.673676);
  }

  void _initializeSchedule() {
    _scheduledStartTime = _extractStartDateTime(widget.trabajo);
    _scheduledEndTime = _extractEndDateTime(widget.trabajo);

    if (_scheduledEndTime != null) {
      final baseStart = _scheduledStartTime ?? widget.startTime;
      final tentativeDuration = _scheduledEndTime!.difference(baseStart);
      if (!tentativeDuration.isNegative && tentativeDuration.inMinutes > 0) {
        _expectedDuration = tentativeDuration;
        return;
      }

      if (_scheduledStartTime != null) {
        final fallbackDuration =
            _scheduledEndTime!.difference(_scheduledStartTime!);
        if (!fallbackDuration.isNegative && fallbackDuration.inMinutes > 0) {
          _expectedDuration = fallbackDuration;
        }
      }
    }
  }

  void _subscribeToEvidencias() {
    _evidenciasSubscription = _storageService
        .mostrarEvidencias(widget.trabajoId)
        .listen((data) {
      if (!mounted) return;
      final capturedNow = data
          .map((e) => _stageFromString(e['etapa'] as String?))
          .whereType<EvidenceStage>()
          .toSet();
      setState(() {
        _evidencias = data;
        _skippedStages.removeWhere(capturedNow.contains);
        _skipExpiredStagesInternal();
      });
    });
  }

  void _startNowTimer() {
    _nowTimer?.cancel();
    void handleTick() {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _skipExpiredStagesInternal();
      });
    }

    _nowTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      handleTick();
    });
    handleTick();
  }

  DateTime? _extractStartDateTime(Map<String, dynamic> trabajo) {
    final fechaInicio = _parseDateTime(trabajo['fechaInicioTrabajo']);
    if (fechaInicio != null) {
      return fechaInicio;
    }

    final fechaTrabajo = _parseDateTime(trabajo['fechaTrabajo']);
    final horaInicio = _timeOfDayFromData(trabajo['horaInicio']);

    if (fechaTrabajo != null && horaInicio != null) {
      return DateTime(fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day,
          horaInicio.hour, horaInicio.minute);
    }

    return fechaTrabajo;
  }

  DateTime? _extractEndDateTime(Map<String, dynamic> trabajo) {
    final fechaFin = _parseDateTime(trabajo['fechaFinTrabajo']);
    if (fechaFin != null) {
      return fechaFin;
    }

    final fechaTrabajo = _parseDateTime(trabajo['fechaTrabajo']);
    final horaFin = _timeOfDayFromData(trabajo['horaFin']);

    if (fechaTrabajo != null && horaFin != null) {
      return DateTime(fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day,
          horaFin.hour, horaFin.minute);
    }

    return fechaFin;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  TimeOfDay? _timeOfDayFromData(dynamic value) {
    if (value is Map) {
      final hour = value['hour'] ?? value['h'];
      final minute = value['minute'] ?? value['m'];
      if (hour is num && minute is num) {
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
      }
    } else if (value is List && value.length >= 2) {
      final hour = value[0];
      final minute = value[1];
      if (hour is num && minute is num) {
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
      }
    } else if (value is String && value.contains(':')) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
    return null;
  }

  EvidenceStage? _stageFromString(String? value) {
    switch (value) {
      case 'inicio':
        return EvidenceStage.inicio;
      case 'medio':
        return EvidenceStage.medio;
      case 'final':
        return EvidenceStage.finalizacion;
    }
    return null;
  }

  Set<EvidenceStage> get _capturedStages {
    return _evidencias
        .map((e) => _stageFromString(e['etapa'] as String?))
        .whereType<EvidenceStage>()
        .toSet();
  }

  EvidenceStage? _nextPendingStage() {
    final captured = _capturedStages;
    for (final stage in EvidenceStage.values) {
      if (_skippedStages.contains(stage)) {
        continue;
      }
      if (!captured.contains(stage)) {
        return stage;
      }
    }
    return null;
  }

  bool get _hasAllEvidences =>
      _capturedStages.length == EvidenceStage.values.length;

  void _skipExpiredStagesInternal() {
    while (true) {
      final stage = _nextPendingStage();
      if (stage == null) {
        break;
      }
      if (_skippedStages.contains(stage)) {
        break;
      }
      if (!_hasReachedStageThreshold(stage)) {
        break;
      }
      final remaining = _windowRemainingForStage(stage);
      if (remaining == null || remaining.inMilliseconds > 0) {
        break;
      }
      _skippedStages.add(stage);
    }
  }

  bool _hasReachedStageThreshold(EvidenceStage stage) {
    final now = _now;
    switch (stage) {
      case EvidenceStage.inicio:
        return !now.isBefore(widget.startTime);
      case EvidenceStage.medio:
        return _hasReachedHalfTime(now);
      case EvidenceStage.finalizacion:
        return _hasReachedFinalStageWindow(now);
    }
  }

  bool _hasReachedHalfTime(DateTime now) {
    if (_expectedDuration != null && _expectedDuration! > Duration.zero) {
      final elapsed = now.difference(widget.startTime);
      return elapsed >= _expectedDuration! ~/ 2;
    }

    if (_scheduledStartTime != null && _scheduledEndTime != null) {
      final midpoint = _scheduledStartTime!
          .add((_scheduledEndTime!.difference(_scheduledStartTime!) ~/ 2));
      return !now.isBefore(midpoint);
    }

    return true;
  }

  bool _hasReachedFinalStageWindow(DateTime now) {
    final availabilityStart = _finalStageAvailabilityStart();
    return !now.isBefore(availabilityStart);
  }

  DateTime _finalStageTargetEnd() {
    if (_expectedDuration != null && _expectedDuration! > Duration.zero) {
      return widget.startTime.add(_expectedDuration!);
    }

    if (_scheduledEndTime != null &&
        !_scheduledEndTime!.isBefore(widget.startTime)) {
      return _scheduledEndTime!;
    }

    // Si no hay referencia tomamos 1 hora como estimación mínima
    return widget.startTime.add(const Duration(hours: 1));
  }

  DateTime _finalStageAvailabilityStart() {
    final target = _finalStageTargetEnd();
    final candidate = target.subtract(_EVIDENCE_WINDOW);
    if (candidate.isBefore(widget.startTime)) {
      return widget.startTime;
    }
    return candidate;
  }

  DateTime? _stageBaseTime(EvidenceStage stage) {
    switch (stage) {
      case EvidenceStage.inicio:
        return widget.startTime;
      case EvidenceStage.medio:
        if (_expectedDuration != null && _expectedDuration! > Duration.zero) {
          return widget.startTime.add(_expectedDuration! ~/ 2);
        }
        if (_scheduledStartTime != null && _scheduledEndTime != null) {
          final total = _scheduledEndTime!.difference(_scheduledStartTime!);
          return _scheduledStartTime!.add(total ~/ 2);
        }
        if (_scheduledEndTime != null) {
          final tentative = _scheduledEndTime!.difference(widget.startTime);
          if (!tentative.isNegative) {
            return widget.startTime.add(tentative ~/ 2);
          }
        }
        return widget.startTime;
      case EvidenceStage.finalizacion:
        return _finalStageAvailabilityStart();
    }
  }

  Duration? _windowRemainingForStage(EvidenceStage stage) {
    final baseTime = _stageBaseTime(stage);
    if (baseTime == null) {
      return null;
    }
    if (_now.isBefore(baseTime)) {
      return null;
    }
    final deadline = _stageDeadline(stage, baseTime);
    if (deadline == null) {
      return null;
    }
    final remaining = deadline.difference(_now);
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  DateTime? _stageDeadline(EvidenceStage stage, DateTime baseTime) {
    switch (stage) {
      case EvidenceStage.inicio:
      case EvidenceStage.medio:
        return baseTime.add(_EVIDENCE_WINDOW);
      case EvidenceStage.finalizacion:
        final targetEnd = _finalStageTargetEnd();
        if (targetEnd.isBefore(baseTime)) {
          return baseTime.add(_EVIDENCE_WINDOW);
        }
        final deadline = baseTime.add(_EVIDENCE_WINDOW);
        return deadline.isBefore(targetEnd) ? deadline : targetEnd;
    }
  }

  bool _isWindowActive(EvidenceStage stage) {
    final remaining = _windowRemainingForStage(stage);
    return remaining != null && remaining.inMilliseconds > 0;
  }

  bool _isWindowExpired(EvidenceStage stage) {
    if (!_hasReachedStageThreshold(stage)) {
      return false;
    }
    final remaining = _windowRemainingForStage(stage);
    return remaining != null && remaining.inMilliseconds <= 0;
  }

  String? _formattedWindowCountdown(EvidenceStage stage) {
    final remaining = _windowRemainingForStage(stage);
    if (remaining == null || remaining.inMilliseconds <= 0) {
      return null;
    }
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _canUploadEvidenceNow {
    final stage = _nextPendingStage();
    if (stage == null) return false;
    if (!_hasReachedStageThreshold(stage)) return false;
    final remaining = _windowRemainingForStage(stage);
    return remaining != null && remaining.inMilliseconds > 0;
  }

  String? get _currentUploadCountdown {
    final stage = _nextPendingStage();
    if (stage == null) {
      return null;
    }
    return _formattedWindowCountdown(stage);
  }

  bool get _hasCurrentStageExpired {
    final stage = _nextPendingStage();
    if (stage == null) {
      return false;
    }
    if (!_hasReachedStageThreshold(stage)) {
      return false;
    }
    final remaining = _windowRemainingForStage(stage);
    return remaining != null && remaining.inMilliseconds <= 0;
  }

  String _thresholdMessage(EvidenceStage stage) {
    switch (stage) {
      case EvidenceStage.inicio:
        return 'Puedes registrar la primera evidencia al comenzar el trabajo.';
      case EvidenceStage.medio:
        return 'Aún no alcanzas el 50% del tiempo estimado del trabajo.';
      case EvidenceStage.finalizacion:
        return 'La evidencia final se habilita en los últimos 5 minutos del trabajo.';
    }
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.black87,
      ),
    );
  }

  Map<String, dynamic>? _evidenciaForStage(EvidenceStage stage) {
    for (final evidencia in _evidencias) {
      final etapa = _stageFromString(evidencia['etapa'] as String?);
      if (etapa == stage) {
        return evidencia;
      }
    }
    return null;
  }

  DateTime? _timestampFromEvidence(Map<String, dynamic>? evidencia) {
    if (evidencia == null) return null;
    final raw = evidencia['capturadaEn'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final formatter = DateFormat('dd/MM HH:mm');
    return formatter.format(dateTime.toLocal());
  }

  Widget _buildCountdownChip(String countdown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        countdown,
        style: TextStyle(
          color: Colors.orange.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCountdownBanner(String countdown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.orange.shade600, size: 18),
          const SizedBox(width: 8),
          Text(
            'Tiempo restante: $countdown',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Text(
            'Tiempo agotado para la evidencia',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidencePanel() {
    final nextStage = _nextPendingStage();
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Evidencias requeridas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _PRIMARY_COLOR,
              ),
            ),
            const SizedBox(height: 12),
            ...EvidenceStage.values.map((stage) {
              final evidencia = _evidenciaForStage(stage);
              final completed = evidencia != null;
              final timestamp = _formatTimestamp(
                _timestampFromEvidence(evidencia),
              );
              final isNext = stage == nextStage;
              final stageThresholdReached = _hasReachedStageThreshold(stage);
              final windowActive = _isWindowActive(stage);
              final windowExpired = _isWindowExpired(stage);
              final skipped = _skippedStages.contains(stage);
              final countdownText =
                  windowActive ? _formattedWindowCountdown(stage) : null;

              final leadingIcon = completed
                  ? Icons.check_circle
                  : isNext
                      ? Icons.photo_camera_front
                      : skipped
                          ? Icons.block
                          : Icons.camera_alt_outlined;
              final leadingColor = completed
                  ? Colors.green.shade600
                  : isNext
                      ? _PRIMARY_COLOR
                      : skipped
                          ? Colors.redAccent
                          : Colors.grey.shade500;

              final subtitleText = completed
                  ? (timestamp.isNotEmpty
                      ? 'Registrada $timestamp'
                      : 'Registrada')
                  : stage.description;

              Widget trailingWidget;
              if (completed) {
                trailingWidget = const Icon(Icons.check, color: Colors.green);
              } else if (skipped) {
                trailingWidget = const Text(
                  'Expirado',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                );
              } else if (isNext) {
                if (!stageThresholdReached) {
                  trailingWidget = const Text(
                    'Pendiente',
                    style: TextStyle(
                      color: _PRIMARY_COLOR,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                } else if (windowActive) {
                  trailingWidget = _buildCountdownChip(countdownText!);
                } else if (windowExpired) {
                  trailingWidget = const Text(
                    'Expirado',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                } else {
                  trailingWidget = const Text(
                    'No disponible',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }
              } else {
                trailingWidget = const Text(
                  'Esperando',
                  style: TextStyle(color: Colors.black54),
                );
              }

              final countdownStyleBase =
                  subtitleStyle ?? const TextStyle(fontSize: 12);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(leadingIcon, color: leadingColor, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: subtitleStyle,
                          ),
                          if (!completed && isNext && !stageThresholdReached)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _thresholdMessage(stage),
                                style: countdownStyleBase.copyWith(
                                  color: Colors.blueGrey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (!completed && isNext && stageThresholdReached &&
                              windowActive)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Tiempo restante: $countdownText',
                                style: countdownStyleBase.copyWith(
                                  color: Colors.deepOrange.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (!completed && isNext && stageThresholdReached &&
                              windowExpired)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Tiempo agotado para subir esta evidencia.',
                                style: countdownStyleBase.copyWith(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    trailingWidget,
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              _hasAllEvidences
                  ? '¡Listo! Puedes enviar las evidencias para revisión.'
                  : 'Recuerda subir las tres evidencias solicitadas antes de enviar.',
              style: TextStyle(
                fontSize: 13,
                color: _hasAllEvidences
                    ? Colors.green.shade700
                    : Colors.grey.shade700,
                fontWeight:
                    _hasAllEvidences ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Obtener una posición inicial para centrar el mapa
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
      _mapController.move(_currentPosition ?? _trabajoCoords, 17.0);
    } catch (_) {
      _mapController.move(_trabajoCoords, 17.0);
    }

    // Escuchar cambios de ubicación en tiempo real
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5, // Actualizar cada 5 metros
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentPosition = LatLng(position.latitude, position.longitude);
            });
          }
        });
  }

  // --- LOGICA DE ACCIONES ---

  Future<void> _enviarEvidencias() async {
    if (_isSendingEvidences) return;

    if (!_hasAllEvidences) {
      _showSnack(
        'Debes subir las evidencias de inicio, 50% y finalización antes de enviar.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Debes iniciar sesión para actualizar el estado del trabajo.');
      return;
    }

    setState(() {
      _isSendingEvidences = true;
    });

    try {
      await _postulacionService.marcarTrabajoPendienteRevision(
        trabajoId: widget.trabajoId,
        usuarioId: user.uid,
      );

      _showSnack(
        'Trabajo enviado para revisión. El administrador revisará tus evidencias.',
        backgroundColor: Colors.green.shade600,
      );
    } catch (e) {
      _showSnack('No pudimos actualizar el estado del trabajo. Intenta nuevamente.');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingEvidences = false;
        });
      }
    }
  }

  Future<void> _contactViaWhatsapp() async {
    final contacto = widget.trabajo['contacto'] as Map<String, dynamic>?;
    final numero = contacto?['numero'] as String?;

    if (numero == null || numero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numero de contacto no disponible.')),
      );
      return;
    }

    final cleanedNumber = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse('whatsapp://send?phone=$cleanedNumber');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir WhatsApp. Asegurese de tener la aplicacion instalada.',
          ),
        ),
      );
    }
  }

  Future<void> _uploadPhotoEvidence() async {
    if (_isUploadingEvidence) return;

    final stage = _nextPendingStage();
    if (stage == null) {
      _showSnack('Ya registraste las tres evidencias requeridas.');
      return;
    }

    if (!_hasReachedStageThreshold(stage)) {
      _showSnack(_thresholdMessage(stage));
      return;
    }

    if (_isWindowExpired(stage)) {
      _showSnack('El tiempo para subir la evidencia expiró.');
      return;
    }

    if (!_isWindowActive(stage)) {
      _showSnack('Aún no está habilitado subir esta evidencia.');
      return;
    }

    XFile? capture;
    try {
      capture = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );
    } catch (_) {
      capture = null;
    }

    if (capture == null) {
      return;
    }

    if (_isWindowExpired(stage)) {
      _showSnack('El tiempo para subir la evidencia expiró.');
      return;
    }

    if (!_isWindowActive(stage)) {
      _showSnack('Aún no está habilitado subir esta evidencia.');
      return;
    }

    setState(() {
      _isUploadingEvidence = true;
      _uploadingStage = stage;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('Debes iniciar sesión para subir evidencias.');
        return;
      }

      final capturedAt = DateTime.now();
      final file = File(capture.path);

      final imageUrl = await _storageService.subirEvidencia(
        trabajoId: widget.trabajoId,
        imagen: file,
        usuarioId: user.uid,
        etapa: stage.id,
        latitud: position.latitude,
        longitud: position.longitude,
        capturadaEn: capturedAt,
      );

      if (imageUrl == null) {
        _showSnack(
          'No pudimos subir la evidencia. Intenta nuevamente.',
        );
        return;
      }

      _showSnack(
        'Evidencia de ${stage.label.toLowerCase()} registrada correctamente.',
        backgroundColor: Colors.green.shade600,
      );
    } catch (e) {
      _showSnack('Ocurrió un error al registrar la evidencia.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingEvidence = false;
          _uploadingStage = null;
        });
      }
    }
  }

  // FUNCION ACTUALIZADA: Muestra las instrucciones en un modal
  void _showInstructions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que ocupe mas espacio vertical
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, // Ocupa el 80% de la pantalla inicialmente
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return _InstructionsModalContent(
              trabajo: widget.trabajo,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  // --- WIDGET PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final screenSize = MediaQuery.of(context).size;
    final countdownLabel = _currentUploadCountdown;
    final isUploadEnabled = _canUploadEvidenceNow && !_isUploadingEvidence;
    final stageExpired = _hasCurrentStageExpired;

    return Scaffold(
      // Usamos la pantalla completa sin AppBar
      body: Stack(
        children: [
          // 1. MAPA DE PANTALLA COMPLETA
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _trabajoCoords,
                initialZoom: 17.0,
                maxZoom: 19.0,
                minZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.goodjob.app',
                ),

                // ZONA DELIMITADA (Geovalla - Geofence)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _trabajoCoords,
                      radius: _CHECKIN_RADIUS_METERS,
                      color: _PRIMARY_COLOR.withOpacity(0.15),
                      borderColor: _PRIMARY_COLOR.withOpacity(0.8),
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),

                // MARCADOR DEL TRABAJO
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: _trabajoCoords,
                      child: const Icon(
                        Icons.work,
                        color: _PRIMARY_COLOR,
                        size: 40,
                      ),
                    ),
                  ],
                ),

                // MARCADOR DE LA UBICACION DEL USUARIO (Tiempo real)
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40,
                        height: 40,
                        point: _currentPosition!,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. BOTONES SUPERIORES (Completar / Volver / Instrucciones)

          // Botón Volver/Home (Top-Left, mas pequeño)
          Positioned(
            top: 40,
            left: 70, // Ajuste para dejar espacio al botón 'Volver'
            child: FloatingActionButton.extended(
              heroTag: 'completeJob',
              onPressed: _isSendingEvidences ? null : _enviarEvidencias,
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
              label: Text(
                _isSendingEvidences ? 'Enviando...' : 'Enviar evidencias',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor:
                  _isSendingEvidences ? Colors.grey : _SUCCESS_COLOR,
            ),
          ),

          // Botón Instrucciones (Top-Right, pequeño)
          Positioned(
            top: 40,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'showInstructions',
              onPressed: _showInstructions, // Llama a la nueva función modal
              backgroundColor: _ACCENT_COLOR,
              child: const Icon(Icons.list_alt, color: Colors.black),
            ),
          ),

          // 4. BOTONES INFERIORES (Subir Foto / WhatsApp / Centrar)

          Positioned(
            left: 16,
            right: 16,
            bottom: 130,
            child: _buildEvidencePanel(),
          ),

          // Botón Subir Foto (Inferior Izquierda)
          if (countdownLabel != null)
            Positioned(
              bottom: 110,
              left: 16,
              child: _buildCountdownBanner(countdownLabel),
            ),
          if (countdownLabel == null && stageExpired)
            Positioned(
              bottom: 110,
              left: 16,
              child: _buildExpiredBanner(),
            ),
          Positioned(
            bottom: 40,
            left: 16,
            child: FloatingActionButton(
              heroTag: 'uploadPhoto',
              onPressed: isUploadEnabled ? _uploadPhotoEvidence : null,
              backgroundColor:
                  isUploadEnabled ? _ACCENT_COLOR : Colors.grey.shade400,
              tooltip: isUploadEnabled
                  ? 'Registrar evidencia'
                  : stageExpired
                      ? 'Tiempo agotado para subir la evidencia'
                      : countdownLabel != null
                          ? 'Tiempo restante: $countdownLabel'
                          : 'Aún no disponible',
              child: _isUploadingEvidence
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.black87),
                      ),
                    )
                  : const Icon(
                      Icons.photo_camera,
                      color: Colors.black,
                      size: 30,
                    ),
            ),
          ),

          // Botón WhatsApp (Inferior Derecha)
          Positioned(
            bottom: 40,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'contactWhatsapp',
              onPressed: _contactViaWhatsapp,
              backgroundColor: _SUCCESS_COLOR,
              child: const Icon(
                Icons.wechat_sharp,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          // Botón para centrar en el usuario (Inferior Central - Opcional)
          Positioned(
            bottom: 40,
            right:
                (screenSize.width / 2) -
                30, // Posiciona en el centro (ajustado por el tamaño del FAB)
            child: FloatingActionButton(
              heroTag: 'centerUser',
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 17.0);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ubicacion no disponible aun.'),
                    ),
                  );
                }
              },
              backgroundColor: _PRIMARY_COLOR,
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// WIDGET PARA CONTENIDO DEL MODAL DE INSTRUCCIONES
// -----------------------------------------------------------

class _InstructionsModalContent extends StatelessWidget {
  final Map<String, dynamic> trabajo;
  final ScrollController scrollController;

  const _InstructionsModalContent({
    required this.trabajo,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Definición de las instrucciones solicitadas
    final List<Instruccion> instrucciones = [
      Instruccion(
        paso: 1,
        titulo: 'Contar y Confirmar Stock',
        descripcion:
            'Verifica que la cantidad de flyers a repartir coincida con el registro. Reporta cualquier discrepancia antes de salir.',
      ),
      Instruccion(
        paso: 2,
        titulo: 'Establecer Ruta y Zona',
        descripcion:
            'Confirma la zona de reparto (ej. Calles principales entre A y B). Prioriza areas de alto trafico peatonal para maximizar el alcance.',
      ),
      Instruccion(
        paso: 3,
        titulo: 'Metodo de Distribucion',
        descripcion:
            'Reparte un flyer por persona o por buzon (si esta permitido). Se amable, sonrie y no fuerces la entrega. La imagen es clave!',
      ),
      Instruccion(
        paso: 4,
        titulo: 'Reporte de Tarea y Geoubicacion',
        descripcion:
            'Usa la funcion de "Check-in" al inicio y "Check-out" al finalizar. Documenta la cantidad de flyers restantes y cualquier incidente.',
      ),
      Instruccion(
        paso: 5,
        titulo: 'CRITICO! Reglas de Limpieza y Legalidad',
        descripcion:
            'Esta estrictamente PROHIBIDO dejar material en el suelo, pegar en mobiliario urbano o bloquear el paso. Manten la zona limpia y respeta las normativas locales, ya que esto puede llevar a la terminacion inmediata del contrato.',
      ),
    ];

    // Extracción de datos de trabajo para la sección de requisitos (SE ELIMINA ESTA LOGICA)
    // final String instruccionesGenerales = trabajo['instrucciones'] as String? ?? 'No se especificaron requisitos generales.';
    // final bool requiereUniforme = trabajo['requiereUniforme'] as bool? ?? false;
    // final List<String> implementosUniforme =
    //   (trabajo['implementosUniforme'] as List<dynamic>?)
    //  ?.map((e) => e.toString())
    //  .toList() ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        controller: scrollController,
        children: [
          const Center(
            child: Text(
              'INSTRUCCIONES DEL TRABAJO',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _PRIMARY_COLOR,
              ),
            ),
          ),
          const Divider(height: 30),

          // Sección de Pasos Detallados (La nueva lista solicitada)
          const Text(
            'Pasos Detallados del Reparto',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _PRIMARY_COLOR,
            ),
          ),
          const SizedBox(height: 16),
          ...instrucciones.map(
            (inst) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _PRIMARY_COLOR,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${inst.paso}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          inst.titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 34.0, top: 4.0),
                    child: Text(
                      inst.descripcion,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SECCIONES ELIMINADAS: Requisitos Generales, Uniforme, Pago
          const SizedBox(height: 30),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CERRAR INSTRUCCIONES',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
