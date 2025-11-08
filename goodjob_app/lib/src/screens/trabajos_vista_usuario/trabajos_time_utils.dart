import 'package:cloud_firestore/cloud_firestore.dart';

Map<String, dynamic>? safeMapCast(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

DateTime? getTrabajoStartDateTime(Map<String, dynamic> trabajo) {
  final newStartTs = trabajo['fechaInicioTrabajo'] as Timestamp?;
  if (newStartTs != null) return newStartTs.toDate();

  final oldDateTs = trabajo['fechaTrabajo'] as Timestamp?;
  final oldHourMap = safeMapCast(trabajo['horaInicio']);

  if (oldDateTs != null && oldHourMap != null) {
    final date = oldDateTs.toDate();
    final h = oldHourMap['h'] as int? ?? 0;
    final m = oldHourMap['m'] as int? ?? 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  return null;
}

DateTime? getFechaLimite(Map<String, dynamic> trabajo) {
  final fechaLimiteTs = trabajo['fechaLimite'] as Timestamp? ??
      trabajo['fechaLimitePostulacion'] as Timestamp?;
  return fechaLimiteTs?.toDate();
}

DateTime? getTrabajoEndDateTime(Map<String, dynamic> trabajo) {
  final newEndTs = trabajo['fechaFinTrabajo'] as Timestamp?;
  if (newEndTs != null) return newEndTs.toDate();

  final oldDateTs = trabajo['fechaTrabajo'] as Timestamp?;
  final oldHourMap = safeMapCast(trabajo['horaFin']);

  if (oldDateTs != null && oldHourMap != null) {
    final date = oldDateTs.toDate();
    final h = oldHourMap['h'] as int? ?? 0;
    final m = oldHourMap['m'] as int? ?? 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  return null;
}

String formatFecha(DateTime? fecha) {
  if (fecha == null) return 'N/D';
  final day = fecha.day.toString().padLeft(2, '0');
  final month = fecha.month.toString().padLeft(2, '0');
  final year = (fecha.year % 100).toString().padLeft(2, '0');
  return '$day/$month/$year';
}