import 'package:flutter/material.dart';

/// Un widget genérico para mostrar un mensaje de estado con un ícono y color.
class WidgetMensajeInformativo extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final Color color;

  const WidgetMensajeInformativo({
    Key? key,
    required this.icono,
    required this.mensaje,
    this.color = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}