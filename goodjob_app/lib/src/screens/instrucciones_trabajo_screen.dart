import 'package:flutter/material.dart';
import 'package:goodjob_app/theme/app_colors.dart';

// Modelo de datos simple para una instrucción
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

class InstruccionesTrabajoScreen extends StatelessWidget {
  // Lista de instrucciones específicas para repartir flyers
  final List<Instruccion> _instrucciones = [
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
          'Confirma la zona de reparto (ej. Calles principales entre A y B). Prioriza áreas de alto tráfico peatonal para maximizar el alcance.',
    ),
    Instruccion(
      paso: 3,
      titulo: 'Método de Distribución',
      descripcion:
          'Reparte un flyer por persona o por buzón (si está permitido). Sé amable, sonríe y no fuerces la entrega. ¡La imagen es clave!',
    ),
    Instruccion(
      paso: 4,
      titulo: 'Reporte de Tarea y Geoubicación',
      descripcion:
          'Usa la función de "Check-in" al inicio y "Check-out" al finalizar. Documenta la cantidad de flyers restantes y cualquier incidente.',
    ),
    Instruccion(
      paso: 5,
      // Título ahora enfocado en la limpieza y legalidad
      titulo: '¡CRÍTICO! Reglas de Limpieza y Legalidad', 
      descripcion:
          '**Está estrictamente PROHIBIDO** dejar material en el suelo, pegar en mobiliario urbano o bloquear el paso. Mantén la zona limpia y respeta las normativas locales, ya que esto puede llevar a la terminación inmediata del contrato.',
    ),
  ];

  InstruccionesTrabajoScreen({super.key});

  // Color primario de la aplicación (asumido)
  static const Color _primaryColor = AppColors.primary;
  static const Color _alertColor = AppColors.alertColor; // Rojo para la alerta crítica
  static const Color _timelineColor = AppColors.timelineColor; // Púrpura más claro para la línea

  // Widget auxiliar para construir cada paso de la línea de tiempo
  Widget _buildInstruccionTimelineItem(
      BuildContext context, Instruccion instruccion, bool isLast) {
    final isCritical = instruccion.paso == 5;
    final color = isCritical ? _alertColor : _primaryColor;
    
    // Jerarquía de texto mejorada para la descripción crítica
    final descStyle = isCritical
        ? const TextStyle(
            fontSize: 14,
            color: Colors.black, // Color oscuro para mejor contraste
            fontWeight: FontWeight.w600, // Seminegrita para que se note
            height: 1.4,
          )
        : TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 1. Indicador de Paso (Círculo y Línea)
          Column(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${instruccion.paso}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              // Línea de conexión, oculta en el último paso
              if (!isLast)
                Container(
                  width: 3.0,
                  height: 60.0, // Altura fija para la línea
                  color: _timelineColor,
                ),
            ],
          ),
          const SizedBox(width: 16),

          // 2. Contenido de la Instrucción (Tarjeta)
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 20.0, top: 4.0),
              elevation: 4,
              color: Colors.white, // Fondo blanco para eliminar el gris opaco
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: isCritical
                    ? const BorderSide(color: _alertColor, width: 2) // Borde rojo
                    : BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      instruccion.titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Uso de Text.rich para poder hacer negrita solo ciertas palabras
                    Text.rich(
                      TextSpan(
                        children: [
                           // Usar un detector de negritas para el texto PROHIBIDO
                           ..._formatTextWithBold(instruccion.descripcion, descStyle),
                        ],
                      ),
                      style: descStyle, // Aplicar estilo general
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Función para detectar y formatear texto en negrita (ej. **PROHIBIDO**)
  List<TextSpan> _formatTextWithBold(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final Match match in exp.allMatches(text)) {
      // Agregar el texto normal antes de la negrita
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: baseStyle));
      }
      // Agregar el texto en negrita
      final boldText = match.group(1);
      if (boldText != null) {
        spans.add(TextSpan(text: boldText, style: baseStyle.copyWith(fontWeight: FontWeight.w900, color: _alertColor)));
      }
      lastMatchEnd = match.end;
    }
    // Agregar el texto normal después de la última negrita
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: baseStyle));
    }
    return spans;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instrucciones de Tarea'),
      ),
      body: Column(
        children: <Widget>[
          // Título y Resumen del Trabajo (en Card estilizada)
          Card(
            margin: const EdgeInsets.all(16.0),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: _primaryColor, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Campaña: Lanzamiento de Verano',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Detalles: 5,000 flyers | Horario: 9:00 - 14:00',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Lee atentamente cada paso antes de iniciar.',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de Instrucciones (Timeline)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 10.0, bottom: 20.0), // Se reduce el padding inferior
              itemCount: _instrucciones.length,
              itemBuilder: (context, index) {
                final instruccion = _instrucciones[index];
                final isLast = index == _instrucciones.length - 1;
                return _buildInstruccionTimelineItem(context, instruccion, isLast);
              },
            ),
          ),
        ],
      ),
    );
  }
}