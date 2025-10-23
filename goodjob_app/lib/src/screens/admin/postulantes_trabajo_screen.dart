import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import 'postulante_detalle_screen.dart'; // Asegúrate de que esta importación sea correcta

// ====================================================================
// WIDGET AUXILIAR: Tarjeta de Postulante
// ====================================================================

class _PostulanteCard extends StatelessWidget {
  final String usuarioId;
  final String trabajoId;
  final Map<String, dynamic> postulacionData;
  // La firma del Future es importante: Future<Map<String, dynamic>>
  final Future<Map<String, dynamic>> Function(String) obtenerDatosUsuario;
  
// Colores de estado
  final Color primaryColor;
  final Color successColor = AppColors.success;
  final Color rejectColor = AppColors.rejectColor;
  final Color pendingColor = Colors.orange.shade800; 

  _PostulanteCard({
    required this.usuarioId,
    required this.trabajoId,
    required this.postulacionData,
    required this.obtenerDatosUsuario,
    required this.primaryColor,
    required Color secondaryColor, // Secondary Color se ignora en este widget
  });

  // Mapeo de estado a colores y texto
  Map<String, dynamic> _getEstadoInfo() {
    final estado = (postulacionData['estado'] ?? 'pendiente').toString().toLowerCase();

    switch (estado) {
      case 'aceptado':
        return {'color': successColor, 'icono': Icons.check_circle_outline, 'texto': 'Aceptado'};
      case 'rechazado':
        return {'color': rejectColor, 'icono': Icons.cancel_outlined, 'texto': 'Rechazado'};
      case 'confirmado':
        return {'color': primaryColor, 'icono': Icons.task_alt, 'texto': 'Confirmado'};
      default:
        return {'color': pendingColor, 'icono': Icons.hourglass_bottom, 'texto': 'Pendiente'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoInfo = _getEstadoInfo();
    final estadoColor = estadoInfo['color'] as Color;
    final estadoIcono = estadoInfo['icono'] as IconData;
    final estadoTexto = estadoInfo['texto'] as String;

    return FutureBuilder<Map<String, dynamic>>(
      future: obtenerDatosUsuario(usuarioId),
      builder: (context, usuarioSnapshot) {
        if (usuarioSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 1,
            child: ListTile(title: Text('Cargando postulante...')),
          );
        }
        
        // Manejo de datos del usuario
        final usuarioData = usuarioSnapshot.data ?? {};
        final nombre = usuarioData['nombre'] ?? 'Nombre N/D';
        final carrera = usuarioData['carrera'] ?? 'Carrera N/D';
        
        // ⬅️ NUEVO: Obtener la URL de la foto de perfil
        final fotoUrl = usuarioData['fotoUrl'] as String?; 
        final hasPhoto = fotoUrl != null && fotoUrl.isNotEmpty;

        final inicial = nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              // Navega a la pantalla de detalle (asumiendo que está definida en el import)
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PostulanteDetalleScreen(
                    usuarioId: usuarioId,
                    trabajoId: trabajoId,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ⬅️ CAMBIO CLAVE: Lógica para mostrar la foto o la inicial
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: primaryColor.withOpacity(0.15),
                    // Usar NetworkImage si la URL existe, sino dejar null
                    backgroundImage: hasPhoto ? NetworkImage(fotoUrl) : null,
                    child: hasPhoto
                        ? null // Si hay foto, el child es null
                        : Text( // Si no hay foto, mostrar la inicial
                            inicial,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Información Principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          carrera,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Chip de Estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcono, size: 16, color: estadoColor),
                        const SizedBox(width: 6),
                        Text(
                          estadoTexto,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ====================================================================
// PANTALLA PRINCIPAL: PostulantesTrabajoScreen
// ====================================================================

class PostulantesTrabajoScreen extends StatelessWidget {
  final String trabajoId;

  const PostulantesTrabajoScreen({super.key, required this.trabajoId});

  /// Método de obtención de datos del usuario, modificado para ser más robusto
  /// e incluir todos los datos, incluida la 'fotoUrl'.
  Future<Map<String, dynamic>> _obtenerDatosUsuario(String usuarioId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get();
      // ⬅️ Retorna los datos que deben incluir la 'fotoUrl' si existe.
      return docSnapshot.data() ?? {};
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    // Acceso a los colores del tema
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Postulantes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trabajos')
            .doc(trabajoId)
            .collection('postulaciones')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar postulantes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'Aún no hay postulantes para este trabajo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comparte la oferta para recibir más solicitudes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          // Ordenar por estado
          final postulaciones = snapshot.data!.docs.toList();
          postulaciones.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final estadoA = (aData['estado'] ?? 'pendiente').toString().toLowerCase();
            final estadoB = (bData['estado'] ?? 'pendiente').toString().toLowerCase();

            const order = ['pendiente', 'aceptado', 'confirmado', 'rechazado'];
            return order.indexOf(estadoA).compareTo(order.indexOf(estadoB));
          });


          return ListView.builder(
            itemCount: postulaciones.length,
            itemBuilder: (context, index) {
              final postulacionDoc = postulaciones[index];
              final postulacionData = postulacionDoc.data() as Map<String, dynamic>;
              // El ID del documento de postulación es el usuarioId
              final usuarioId = postulacionData['usuarioId']; 

              if (usuarioId == null || usuarioId.isEmpty) {
                return const SizedBox.shrink(); 
              }

              return _PostulanteCard(
                usuarioId: usuarioId,
                trabajoId: trabajoId,
                postulacionData: postulacionData,
                obtenerDatosUsuario: _obtenerDatosUsuario,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
              );
            },
          );
        },
      ),
    );
  }
}