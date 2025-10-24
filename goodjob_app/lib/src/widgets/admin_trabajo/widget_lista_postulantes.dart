import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
// IMPORTAR LA PANTALLA DE DETALLE (ajusta esta ruta si es distinta)
import 'package:goodjob_app/src/screens/admin/postulante_detalle_screen.dart';
import '../../services/postulacion_service.dart';
import '../../services/postulante_service.dart';

// Constantes de Colores
const Color primaryColor = Color(0xFF7B0997);
const Color successColor = Color(0xFF4CAF50);
const Color alertColor = Color(0xFFD32F2F);

class WidgetListaPostulantes extends StatefulWidget {
  final Trabajo trabajo;
  final PostulacionService postulacionService;
  final PostulanteService postulanteService;

  const WidgetListaPostulantes({
    super.key,
    required this.trabajo,
    required this.postulacionService,
    required this.postulanteService,
  });

  @override
  State<WidgetListaPostulantes> createState() => _WidgetListaPostulantesState();
}

class _WidgetListaPostulantesState extends State<WidgetListaPostulantes> {
  bool _isLoading = false;

  // --- Lógica para Elegir Postulante ---
  void _elegirPostulante(String postulanteId, String postulanteNombre, Function(bool) setLocalElegido) async {
    // 1. Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Selección'),
        content: Text(
          '¿Estás seguro de que deseas elegir a $postulanteNombre para este trabajo? Esta acción no se puede deshacer.',
        ),
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
            ),
            child: const Text('Confirmar Elección'),
          ),
        ],
      ),
    );

    if (confirmar != true) return; // Salir si el usuario cancela

    // ⚠️ 1. FEEDBACK INMEDIATO: Marcar como elegido antes de llamar al servicio
    setLocalElegido(true); 
    setState(() => _isLoading = true); // Opcional: Mostrar loading global si afecta la UI de la pantalla padre

    try {
      // 2. Llamar al servicio para actualizar estado (esto disparará la reconstrucción por Stream)
      await widget.postulacionService.actualizarEstado(
        trabajoId: widget.trabajo.id,
        postulanteId: postulanteId,
        nuevoEstado: 'aceptado', // Estado que indica la elección
        trabajoTitulo: widget.trabajo.titulo,
      );

      // 3. Mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$postulanteNombre ha sido elegido. El trabajo está ahora Por Confirmar.'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      // 4. Manejar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al elegir postulante: $e'),
            backgroundColor: alertColor,
          ),
        );
        // Si hay error, revertir el feedback local
        setLocalElegido(false);
      }
    } finally {
      // Dejamos que el StreamBuilder maneje el estado final, pero quitamos el loading general
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Build Principal ---
  @override
  Widget build(BuildContext context) {
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
            fontWeight: FontWeight.bold, color: primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // --- StreamBuilder para la Lista ---
        StreamBuilder<QuerySnapshot>(
          stream: widget.postulacionService.obtenerPostulacionesDeTrabajo(widget.trabajo.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error al cargar: ${snapshot.error}', style: const TextStyle(color: alertColor)));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: primaryColor));
            if (snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32.0), child: Text('Aún no hay postulantes.', style: TextStyle(fontStyle: FontStyle.italic))));

            final postulaciones = snapshot.data!.docs;

            // LÓGICA CLAVE: Verificar si ya se eligió a alguien
            final bool yaSeEligio = postulaciones.any((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data?['estado'] == 'aceptado';
            });

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: postulaciones.length,
              itemBuilder: (context, index) {
                final postulacionDoc = postulaciones[index];
                final postulacionData = postulacionDoc.data() as Map<String, dynamic>?;
                
                final String usuarioId = postulacionData?['usuarioId'] ?? 'ID_NO_DISPONIBLE';

                if (usuarioId == 'ID_NO_DISPONIBLE') {
                  return const ListTile(title: Text('Error: Postulación sin ID de usuario.'));
                }

                // Pasamos la función de elegir con la lógica de cierre inmediato
                return _PostulanteInfoTile(
                  usuarioId: usuarioId,
                  trabajoId: widget.trabajo.id,
                  postulanteService: widget.postulanteService,
                  // ⚠️ PASAMOS LA REFERENCIA A LA FUNCIÓN DE ELECCIÓN GLOBAL
                  onElegirGlobal: (nombre, setLocalState) => _elegirPostulante(usuarioId, nombre, setLocalState),
                  // Ocultamos el botón si ALGUIEN ya fue elegido (ya sea este u otro)
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

// -------------------------------------------------------------------------
// ⚠️ WIDGET INTERNO MODIFICADO PARA MANEJAR ESTADO LOCAL DE CONFIRMACIÓN
// -------------------------------------------------------------------------
class _PostulanteInfoTile extends StatefulWidget {
  final String usuarioId;
  final String trabajoId;
  final PostulanteService postulanteService;
  // ⚠️ CAMBIO: Recibe la función global y un callback local (setLocalState)
  final Function(String nombre, Function(bool) setLocalState) onElegirGlobal;
  final bool mostrarBotonElegir;

  const _PostulanteInfoTile({
    required this.usuarioId,
    required this.trabajoId,
    required this.postulanteService,
    required this.onElegirGlobal,
    required this.mostrarBotonElegir,
  });

  @override
  State<_PostulanteInfoTile> createState() => _PostulanteInfoTileState();
}

class _PostulanteInfoTileState extends State<_PostulanteInfoTile> {
  // ⚠️ NUEVO ESTADO: Controla el feedback inmediato
  bool _localmenteElegido = false; 

  void _handleElegir(String nombre) {
    // Llama a la función global, pasándole el nombre y un callback
    // para que la función global pueda actualizar este estado local si hay éxito/error
    widget.onElegirGlobal(nombre, (isSuccess) {
      if (mounted) {
        setState(() {
          _localmenteElegido = isSuccess;
        });
      }
    });
  }

  void _navigateToProfile(BuildContext context) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostulanteDetalleScreen(
              usuarioId: widget.usuarioId,
              trabajoId: widget.trabajoId,
            ),
          ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Si ya fue elegido y el StreamBuilder no se ha reconstruido aún,
    // usamos el estado local para mostrar el feedback.
    final bool showElectedFeedback = _localmenteElegido;
    final bool showElegirButton = widget.mostrarBotonElegir && !_localmenteElegido;


    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.postulanteService.obtenerDatosUsuario(widget.usuarioId),
      builder: (context, snapshot) {
        // --- Declaraciones de UI ---
        Widget leadingWidget = const CircleAvatar(child: Icon(Icons.person));
        String titleText = 'Cargando...';
        String subtitleText = 'Toca para ver perfil';
        Widget? trailingWidget;
        bool isInteractive = false;
        
        Color cardColor = Colors.white;

        // --- Lógica de Estado ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          leadingWidget = const CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2));
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          titleText = 'Error al cargar usuario';
          subtitleText = 'Detalles de carga fallida';
          leadingWidget = const CircleAvatar(child: Icon(Icons.error_outline, color: alertColor));
        } else {
          // --- Datos Cargados ---
          final postulanteData = snapshot.data!;
          final String nombre = postulanteData['nombre'] ?? 'Sin nombre';
          final String apellido = postulanteData['apellido'] ?? '';
          final String nombreCompleto = '$nombre $apellido'.trim().isEmpty ? 'Usuario Anónimo' : '$nombre $apellido'.trim();
          final String fotoUrl = postulanteData['fotoUrl'] ?? '';

          titleText = nombreCompleto;
          leadingWidget = CircleAvatar(
            backgroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
            child: fotoUrl.isEmpty ? Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U') : null,
          );
          
          isInteractive = true;

          // ⚠️ LÓGICA DE FEEDBACK INMEDIATO
          if (showElectedFeedback) {
             // ⚠️ MENSAJE DE CONFIRMACIÓN INMEDIATO
             trailingWidget = const Icon(Icons.check_circle, color: successColor);
             subtitleText = '¡Elegido! Esperando confirmación.';
             cardColor = successColor.withOpacity(0.1);
          } else if (showElegirButton) {
            trailingWidget = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // ⚠️ LLAMA AL HANDLER LOCAL
              onPressed: () => _handleElegir(nombreCompleto),
              child: const Text('Elegir'),
            );
          }
        }

        // --- Construcción del ListTile ---
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: showElectedFeedback ? successColor : Colors.grey.shade300, // Borde de éxito si fue elegido
              width: showElectedFeedback ? 1.5 : 0.5,
            ),
          ),
          child: ListTile(
            leading: leadingWidget,
            title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitleText),
            trailing: trailingWidget,
            onTap: isInteractive ? () => _navigateToProfile(context) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}