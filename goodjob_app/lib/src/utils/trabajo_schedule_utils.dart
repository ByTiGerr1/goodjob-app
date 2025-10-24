import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

DateTime? extractTrabajoStart(Map<String, dynamic> trabajo) {
  final fechaInicio = _parseDateTime(trabajo['fechaInicioTrabajo']);
  if (fechaInicio != null) {
    return fechaInicio;
  }

  final fechaTrabajo = _parseDateTime(trabajo['fechaTrabajo']);
  final horaInicio = _timeOfDayFromData(trabajo['horaInicio']);

  if (fechaTrabajo != null && horaInicio != null) {
    return DateTime(
      fechaTrabajo.year,
      fechaTrabajo.month,
      fechaTrabajo.day,
      horaInicio.hour,
      horaInicio.minute,
    );
  }

  return fechaTrabajo;
}

DateTime? extractTrabajoEnd(Map<String, dynamic> trabajo) {
  final fechaFin = _parseDateTime(trabajo['fechaFinTrabajo']);
  if (fechaFin != null) {
    return fechaFin;
  }

  final fechaTrabajo = _parseDateTime(trabajo['fechaTrabajo']);
  final horaFin = _timeOfDayFromData(trabajo['horaFin']);

  if (fechaTrabajo != null && horaFin != null) {
    return DateTime(
      fechaTrabajo.year,
      fechaTrabajo.month,
      fechaTrabajo.day,
      horaFin.hour,
      horaFin.minute,
    );
  }

  return fechaFin;
}

Duration? calculateCheckInDelay({
  required DateTime actualCheckIn,
  DateTime? scheduledStart,
}) {
  if (scheduledStart == null) {
    return null;
  }

  if (!actualCheckIn.isAfter(scheduledStart)) {
    return Duration.zero;
  }

  return actualCheckIn.difference(scheduledStart);
}