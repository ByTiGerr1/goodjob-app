import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import '../../services/postulante_service.dart';
import 'widget_mensaje_informativo.dart';

class WidgetInfoPostulante extends StatelessWidget {
  final Trabajo trabajo;
  final String mensaje;
  final PostulanteService postulanteService;

  const WidgetInfoPostulante({
    Key? key,
    required this.trabajo,
    required this.mensaje,
    required this.postulanteService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Postulante Seleccionado',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // ¡CONECTADO A TU SERVICIO!
        FutureBuilder<Map<String, dynamic>?>(
          future: postulanteService.obtenerDatosUsuario(trabajo.trabajadorAsignadoId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return const Text('No se pudieron cargar los datos del postulante.');
            }

            final postulanteData = snapshot.data!;
            final String nombre = postulanteData['nombre'] ?? 'Sin nombre';
            final String telefono = postulanteData['telefono'] ?? 'No disponible';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(child: Text(nombre.isNotEmpty ? nombre[0] : 'U')),
                title: Text(nombre), // Dato real
                subtitle: Text('Contacto: $telefono'), // Dato real
                trailing: IconButton(
                  icon: const Icon(Icons.message_outlined),
                  onPressed: () {
                    // TODO: Abrir chat con el postulante
                  },
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),
        WidgetMensajeInformativo(
          icono: Icons.calendar_today_outlined,
          mensaje: mensaje,
          color: trabajo.estado.colorTextoChip,
        ),
      ],
    );
  }
}