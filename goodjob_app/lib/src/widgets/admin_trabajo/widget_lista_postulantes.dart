import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
// ⚠️ 1. IMPORTAR LA PANTALLA DE DETALLE (ajusta esta ruta si es distinta)
import 'package:goodjob_app/src/screens/admin/postulante_detalle_screen.dart';
import '../../services/postulacion_service.dart';
import '../../services/postulante_service.dart';

// Constantes de Colores (puedes moverlas a tu archivo de tema)
const Color primaryColor = Color(0xFF7B0997);
const Color successColor = Color(0xFF4CAF50);
const Color alertColor = Color(0xFFD32F2F);

class WidgetListaPostulantes extends StatefulWidget {
  final Trabajo trabajo;
  final PostulacionService postulacionService;
  final PostulanteService postulanteService;

  const WidgetListaPostulantes({
    super.key, // Corrección: Usar super.key
    required this.trabajo,
    required this.postulacionService,
    required this.postulanteService,
  });

  @override
  State<WidgetListaPostulantes> createState() => _WidgetListaPostulantesState();
}

class _WidgetListaPostulantesState extends State<WidgetListaPostulantes> {
  bool _isLoading = false; // Para feedback visual durante la elección

  // --- Lógica para Elegir Postulante ---
  void _elegirPostulante(String postulanteId, String postulanteNombre) async {
    // 1. Mostrar diálogo de confirmación (YA IMPLEMENTADO)
    final bool? confirmar = await showDialog<bool>(
      // Especificar tipo <bool>
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Selección'),
        content: Text(
          '¿Estás seguro de que deseas elegir a $postulanteNombre para este trabajo? Esta acción no se puede deshacer.',
        ), // Mensaje más claro
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              foregroundColor: Colors.white,
            ), // Mejor estilo
            child: const Text('Confirmar Elección'),
          ),
        ],
      ),
    );

    if (confirmar != true) return; // Salir si el usuario cancela

    setState(() => _isLoading = true);

    try {
      // 2. Llamar al servicio para actualizar estado
      await widget.postulacionService.actualizarEstado(
        trabajoId: widget.trabajo.id,
        postulanteId: postulanteId,
        nuevoEstado: 'aceptado', // Estado que indica la elección
        trabajoTitulo: widget.trabajo.titulo,
        // El servicio también debería actualizar el estado del 'trabajo' a 'porConfirmar'
      );

      // 3. Mensaje de éxito (Opcional, pero buena UX)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$postulanteNombre ha sido elegido.'),
            backgroundColor: successColor,
          ),
        );
      }
      // NOTA: No necesitamos setState aquí porque el StreamBuilder
      // detectará el cambio en Firestore y reconstruirá la lista,
      // ocultando automáticamente los botones.
    } catch (e) {
      // 4. Manejar error
      if (mounted) {
        // Verificar si el widget sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al elegir postulante: $e'),
            backgroundColor: alertColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Build Principal ---
  @override
  Widget build(BuildContext context) {
    // Mostrar loading general si se está procesando la elección
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 16),
              Text('Procesando elección...'),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Postulantes',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // --- StreamBuilder para la Lista ---
        StreamBuilder<QuerySnapshot>(
          stream: widget.postulacionService.obtenerPostulacionesDeTrabajo(
            widget.trabajo.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error al cargar: ${snapshot.error}',
                  style: const TextStyle(color: alertColor),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }
            if (snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Text(
                    'Aún no hay postulantes.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              );
            }

            final postulaciones = snapshot.data!.docs;

            // --- LÓGICA CLAVE: Verificar si ya se eligió a alguien ---
            // Buscamos si *alguna* postulación tiene el estado 'aceptado'
            final bool yaSeEligio = postulaciones.any((doc) {
              final data = doc.data() as Map<String, dynamic>?; // Safe cast
              return data?['estado'] == 'aceptado';
            });
            // --------------------------------------------------------

            return ListView.builder(
              shrinkWrap: true, // Importante para Column
              physics:
                  const NeverScrollableScrollPhysics(), // Evita scroll anidado
              itemCount: postulaciones.length,
              itemBuilder: (context, index) {
                final postulacionDoc = postulaciones[index];
                final postulacionData =
                    postulacionDoc.data() as Map<String, dynamic>?; // Safe cast

                // Manejo defensivo por si falta el ID
                final String? usuarioId = postulacionData?['usuarioId'];
                if (usuarioId == null) {
                  return const ListTile(
                    title: Text('Error: Postulación sin ID de usuario.'),
                  );
                }

                // Pasamos el flag 'yaSeEligio' al Tile
                return _PostulanteInfoTile(
                  usuarioId: usuarioId,
                  trabajoId: widget.trabajo.id,
                  postulanteService: widget.postulanteService,
                  // Pasa la función de elegir
                  onElegir: (nombre) => _elegirPostulante(usuarioId, nombre),
                  // Pasa el flag para ocultar botón
                  mostrarBotonElegir: !yaSeEligio,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Widget interno que carga y muestra los datos de un postulante
class _PostulanteInfoTile extends StatelessWidget {
  final String usuarioId;
  final String trabajoId;
  final PostulanteService postulanteService;
  final Function(String nombre) onElegir;
  final bool mostrarBotonElegir; // Flag para mostrar/ocultar el botón

  const _PostulanteInfoTile({
    // No necesita key si es privado y usado solo aquí
    required this.usuarioId,
    required this.trabajoId,
    required this.postulanteService,
    required this.onElegir,
    required this.mostrarBotonElegir, // Recibe el flag
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: postulanteService.obtenerDatosUsuario(usuarioId),
      builder: (context, snapshot) {
        // --- Estados de Carga y Error ---
        Widget leadingWidget = const CircleAvatar(
          child: Icon(Icons.person),
        ); // Default
        String titleText = 'Cargando...';
        Widget? trailingWidget; // Será el botón o nulo

        if (snapshot.connectionState == ConnectionState.waiting) {
          leadingWidget = const CircleAvatar(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data == null) {
          titleText = 'Error al cargar usuario';
          leadingWidget = const CircleAvatar(
            child: Icon(Icons.error_outline, color: alertColor),
          );
        } else {
          // --- Datos Cargados ---
          final postulanteData = snapshot.data!;
          final String nombre = postulanteData['nombre'] ?? 'Sin nombre';
          final String apellido = postulanteData['apellido'] ?? '';
          final String nombreCompleto = '$nombre $apellido'.trim();
          final String fotoUrl = postulanteData['fotoUrl'] ?? '';

          titleText = nombreCompleto.isEmpty
              ? 'Usuario Anónimo'
              : nombreCompleto;

          leadingWidget = CircleAvatar(
            backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
            // Fallback con inicial si no hay foto
            child: fotoUrl.isEmpty
                ? Text(
                    nombreCompleto.isNotEmpty
                        ? nombreCompleto[0].toUpperCase()
                        : 'U',
                  )
                : null,
          );

          // --- LÓGICA CLAVE: Mostrar botón solo si el flag es true ---
          if (mostrarBotonElegir) {
            trailingWidget = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ), // Más compacto
              ),
              onPressed: () => onElegir(nombreCompleto),
              child: const Text('Elegir'),
            );
          } else {
            // Si no se muestra el botón, podríamos mostrar un check si este fue el elegido
            // (requiere saber si ESTE usuario fue el 'aceptado', no solo si *alguien* fue aceptado)
            // Por ahora, simplemente no mostramos nada.
            trailingWidget = null;
          }
          // -------------------------------------------------------------
        }

        // --- Construcción del ListTile ---
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1, // Más sutil
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.shade300,
              width: 0.5,
            ), // Borde ligero
          ),
          child: ListTile(
            leading: leadingWidget,
            title: Text(
              titleText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Toca para ver perfil'),
            trailing: trailingWidget, // El botón condicional
            onTap: () {
              // Navegación al detalle del postulante
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ), // Coherencia
          ),
        );
      },
    );
  }
}
