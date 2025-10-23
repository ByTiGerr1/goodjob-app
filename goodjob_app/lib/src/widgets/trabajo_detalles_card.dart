import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart'; // Asumido para FormatUtils
// Nota: La clase DatoTrabajo (anteriormente _DatoTrabajo) debe estar definida en este scope
// o importada. Por simplicidad, la definiremos internamente como un widget auxiliar.


class TrabajoDetallesCard extends StatelessWidget {
  final Map<String, dynamic> trabajo;
  final Color primaryColor;

  const TrabajoDetallesCard({
    super.key,
    required this.trabajo,
    required this.primaryColor,
  });

  // --- UTILIDADES Y HELPERS DE FORMATO ---
  // Integradas dentro del componente para que sea autocontenido

  DateTime? _getTrabajoStartDateTime() {
    final startTs = trabajo['fechaInicioTrabajo'] as Timestamp?;
    return startTs?.toDate();
  }

  DateTime? _getTrabajoEndDateTime() {
    final endTs = trabajo['fechaFinTrabajo'] as Timestamp?;
    return endTs?.toDate();
  }

  Map<String, dynamic>? _safeMapCast(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String _formatDate(DateTime? fecha) => fecha != null ? FormatUtils.formatDate(fecha) : 'N/A';
  String _formatCurrency(double? precio) => precio != null ? FormatUtils.formatCurrency(precio) : 'N/A';
  
  String _formatTimeOfDay(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'N/A';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes.isEmpty ? 'N/A' : partes;
  }

  // --- WIDGET AUXILIAR (DatoTrabajo) ---
  
  Widget _DatoTrabajo({
    required IconData icon,
    required String title,
    required String value,
    Color iconColor = Colors.black54,
  }) {
    // Patrón de Fila de Hechos con Contenedor de Valor
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100, // Fondo sutil para el valor
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BUILD PRINCIPAL DE LA TARJETA ---

  @override
  Widget build(BuildContext context) {
    final fechaInicio = _getTrabajoStartDateTime();
    final fechaFin = _getTrabajoEndDateTime();
    final ubicacion = _safeMapCast(trabajo['ubicacion']);
    final precio = (trabajo['precio'] as num?)?.toDouble() ?? 0.0;
    
    // Asumimos que el color del estado activo se pasa o se calcula si es necesario
    final activoTextColor = primaryColor; 

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Detalles del Trabajo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
            Divider(height: 24, color: primaryColor),
            
            // Título y Empresa (no listados, sino con mayor prominencia)
            Text(
              trabajo['titulo'] as String? ?? 'N/A',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              trabajo['empresa'] as String? ?? 'N/A',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            
            // Detalles usando el nuevo patrón _DatoTrabajo
            _DatoTrabajo(
              icon: Icons.calendar_month,
              title: 'Fecha Inicio',
              value: _formatDate(fechaInicio),
              iconColor: primaryColor,
            ),
            _DatoTrabajo(
              icon: Icons.schedule,
              title: 'Horario',
              value: fechaInicio != null && fechaFin != null 
                     ? '${_formatTimeOfDay(fechaInicio)} - ${_formatTimeOfDay(fechaFin)} hrs'
                     : 'N/A',
              iconColor: primaryColor,
            ),
            _DatoTrabajo(
              icon: Icons.attach_money,
              title: 'Monto Total',
              value: _formatCurrency(precio),
              iconColor: activoTextColor, 
            ),
            _DatoTrabajo(
              icon: Icons.location_on,
              title: 'Ubicación',
              value: _formatearUbicacion(ubicacion),
              iconColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}