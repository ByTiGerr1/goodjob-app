import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/postulacion_service.dart';

// Pantalla que muestra el perfil detallado de un postulante
class PostulanteDetalleScreen extends StatelessWidget {
  final String usuarioId;
  final String trabajoId;
  static final PostulacionService _postulacionService = PostulacionService();

  const PostulanteDetalleScreen({
    super.key,
    required this.usuarioId,
    required this.trabajoId,
  });

  // Método para obtener los datos completos del usuario de Firestore
  Future<Map<String, dynamic>?> _obtenerDatosUsuario() async {
    try {
      final docSnapshot =
          await FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get();
      return docSnapshot.data();
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
      return null;
    }
  }

  // Método para actualizar el estado de la postulación en Firestore
  Future<void> _actualizarEstadoPostulacion(
      String estado, BuildContext context) async {
    final nuevoEstado = estado.toLowerCase();
    
    // --- Lógica de Loader con AlertDialog (Mantenida) ---
    final mensaje = nuevoEstado == "aceptado"
        ? "Aceptando postulación..."
        : "Rechazando postulación...";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      await _postulacionService.actualizarEstado(
        trabajoId: trabajoId,
        postulanteId: usuarioId,
        nuevoEstado: nuevoEstado,
      );

      if (!context.mounted) return;

      // Cerrar loader
      Navigator.of(context).pop();

      final estadoCapitalizado = nuevoEstado.isEmpty
          ? nuevoEstado
          : '${nuevoEstado[0].toUpperCase()}${nuevoEstado.substring(1)}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Postulación $estadoCapitalizado con éxito'),
          backgroundColor: nuevoEstado == "aceptado" ? Colors.green : Colors.red,
        ),
      );

      // Opcional: volver a la pantalla anterior
      Navigator.of(context).pop();
    } catch (e) {
      print('Error al actualizar el estado: $e');
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Cerrar loader si hubo error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el estado.')),
      );
    }
  }

  // --- WIDGET AUXILIAR: Ítem de Detalle (Jerarquía mejorada) ---
  Widget _buildDetailItem(BuildContext context, IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el Builder para acceder al Context y pasar las acciones al contenido
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Postulante'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _obtenerDatosUsuario(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: Text('Error al cargar los datos del postulante.'));
          }

          final usuarioData = snapshot.data!;
          final nombre = usuarioData['nombre'] ?? 'Sin nombre';
          final apellido = usuarioData['apellido'] ?? '';
          final nombreCompleto = '$nombre $apellido';
          final carrera = usuarioData['carrera'] ?? 'No disponible';
          final email = usuarioData['email'] ?? 'No disponible';
          final telefono = usuarioData['telefono'] ?? 'No disponible';
          final descripcion = usuarioData['descripcion'] ?? 'Sin descripción.';
          final primaryColor = Theme.of(context).colorScheme.primary;
          final successColor = Colors.green.shade600;
          final rejectColor = Colors.red.shade600;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0), // Padding extra para el CTA fijo
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. ENCABEZADO Y DATOS PRINCIPALES ---
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            child: Text(
                              nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            nombreCompleto,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            carrera,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // --- 2. ACERCA DE MÍ (DESCRIPCIÓN) ---
                    _buildSectionCard(
                      context,
                      title: 'Acerca de mí',
                      children: [
                        Text(descripcion, style: const TextStyle(fontSize: 15, height: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- 3. INFORMACIÓN DE CONTACTO ---
                    _buildSectionCard(
                      context,
                      title: 'Información de contacto',
                      children: [
                        _buildDetailItem(context, Icons.email_outlined, 'Correo electrónico', email),
                        const Divider(indent: 16, endIndent: 16),
                        _buildDetailItem(context, Icons.phone_outlined, 'Teléfono', telefono),
                        // Aquí podrías añadir más datos relevantes como Experiencia, Habilidades, etc.
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // --- 4. ACCIÓN RÁPIDA (CONTACTAR) ---
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Simulando chat/llamada con $nombre...')),
                          );
                          // Lógica para abrir chat o hacer llamada
                        },
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        label: const Text('Abrir Chat/Contactar', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- BOTONES DE ACCIÓN FIJOS EN EL BOTTOM (UX CRÍTICA) ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstadoPostulacion('aceptado', context),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Aceptar', style: TextStyle(color: Colors.white, fontSize: 18)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: successColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _actualizarEstadoPostulacion('rechazado', context),
                          icon: Icon(Icons.close, color: rejectColor),
                          label: Text('Rechazar', style: TextStyle(color: rejectColor, fontSize: 18)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: rejectColor, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // Widget auxiliar para crear tarjetas de sección
  Widget _buildSectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}