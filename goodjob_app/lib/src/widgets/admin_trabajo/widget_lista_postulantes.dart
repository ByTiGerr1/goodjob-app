import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
// ⚠️ 1. IMPORTAR LA PANTALLA DE DETALLE (ajusta esta ruta si es distinta)
import 'package:goodjob_app/src/screens/admin/postulante_detalle_screen.dart'; 
import '../../services/postulacion_service.dart';
import '../../services/postulante_service.dart';

class WidgetListaPostulantes extends StatefulWidget {
  final Trabajo trabajo;
  final PostulacionService postulacionService;
  final PostulanteService postulanteService;

  const WidgetListaPostulantes({
    Key? key,
    required this.trabajo,
    required this.postulacionService,
    required this.postulanteService,
  }) : super(key: key);

  @override
  State<WidgetListaPostulantes> createState() => _WidgetListaPostulantesState();
}

class _WidgetListaPostulantesState extends State<WidgetListaPostulantes> {
  // ... (toda la lógica de _isLoading y _elegirPostulante se mantiene igual) ...
  bool _isLoading = false;

  void _elegirPostulante(String postulanteId, String postulanteNombre) async {
    // 1. Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Selección'),
        content: Text('¿Estás seguro de que deseas elegir a $postulanteNombre para este trabajo?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Elegir')),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      // 2. ¡CONECTADO A TU SERVICIO!
      await widget.postulacionService.actualizarEstado(
        trabajoId: widget.trabajo.id,
        postulanteId: postulanteId,
        nuevoEstado: 'aceptado', // Tu servicio maneja esto
        trabajoTitulo: widget.trabajo.titulo,
      );
      // No necesitas hacer nada más, el Stream principal de la pantalla
      // (que escucha al 'trabajo') debería detectar el cambio de estado
      // y reconstruir la UI al estado 'porConfirmar'.

    } catch (e) {
      // 3. Manejar error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al elegir postulante: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Postulantes',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // ¡CONECTADO A TU SERVICIO!
        StreamBuilder<QuerySnapshot>(
          stream: widget.postulacionService.obtenerPostulacionesDeTrabajo(widget.trabajo.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error al cargar: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Aún no hay postulantes.'));
            }

            final postulaciones = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: postulaciones.length,
              itemBuilder: (context, index) {
                final postulacionDoc = postulaciones[index];
                final String usuarioId = postulacionDoc['usuarioId']; // Dato real

                // Usamos un widget interno para cargar los datos del usuario
                return _PostulanteInfoTile(
                  usuarioId: usuarioId,
                  // ⚠️ 2. PASAR EL ID DEL TRABAJO
                  trabajoId: widget.trabajo.id, 
                  postulanteService: widget.postulanteService,
                  onElegir: (nombre) => _elegirPostulante(usuarioId, nombre),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Widget interno que carga los datos de un usuario por su ID
class _PostulanteInfoTile extends StatelessWidget {
  final String usuarioId;
  final String trabajoId; // ⚠️ AÑADIDO
  final PostulanteService postulanteService;
  final Function(String nombre) onElegir;

  const _PostulanteInfoTile({
    required this.usuarioId,
    required this.trabajoId, // ⚠️ AÑADIDO
    required this.postulanteService,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    // ¡CONECTADO A TU SERVICIO!
    return FutureBuilder<Map<String, dynamic>?>(
      future: postulanteService.obtenerDatosUsuario(usuarioId),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(title: Text('Cargando...'));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return ListTile(title: Text('Error al cargar usuario $usuarioId'));
        }

        final postulanteData = snapshot.data!;
        final String nombre = postulanteData['nombre'] ?? 'Sin nombre';
        final String fotoUrl = postulanteData['fotoUrl'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
              child: fotoUrl.isEmpty ? Text(nombre.isNotEmpty ? nombre[0] : 'U') : null,
            ),
            title: Text(nombre), // Dato real
            subtitle: const Text('Toca para ver perfil'), // ⚠️ UI MEJORADA
            trailing: ElevatedButton(
              child: const Text('Elegir'),
              onPressed: () => onElegir(nombre), // Acción real
            ),
            // ⚠️ 3. IMPLEMENTAR NAVEGACIÓN
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostulanteDetalleScreen(
                    usuarioId: usuarioId,
                    trabajoId: trabajoId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}