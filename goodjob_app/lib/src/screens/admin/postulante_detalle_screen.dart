import 'package:flutter/material.dart';
// Importaciones de tus servicios
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
// --- ⚠️ IMPORTS AÑADIDOS ---
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/models/trabajo.dart'; // Necesitamos el modelo
// ---
import 'package:goodjob_app/theme/app_colors.dart';

// ====================================================================
// WIDGET AUXILIAR: Avatar (Sin cambios)
// ====================================================================
class _PostulanteAvatar extends StatelessWidget {
  const _PostulanteAvatar({
    required this.nombre,
    required this.fotoUrl,
    required this.primaryColor,
  });

  final String nombre;
  final String? fotoUrl;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    final initials = nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?';

    return CircleAvatar(
      radius: 60,
      backgroundColor: primaryColor.withOpacity(0.1),
      backgroundImage: hasPhoto ? NetworkImage(fotoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              initials,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
    );
  }
}


// ====================================================================
// PANTALLA PRINCIPAL: PostulanteDetalleScreen (AHORA STATEFUL)
// ====================================================================

class PostulanteDetalleScreen extends StatefulWidget { // <-- CAMBIO
  final String usuarioId;
  final String trabajoId;
  
  const PostulanteDetalleScreen({
    super.key,
    required this.usuarioId,
    required this.trabajoId,
  });

  @override
  State<PostulanteDetalleScreen> createState() => _PostulanteDetalleScreenState();
}

class _PostulanteDetalleScreenState extends State<PostulanteDetalleScreen> { // <-- CAMBIO
  
  // --- ⚠️ LÓGICA DE ESTADO AÑADIDA ---
  final PostulacionService _postulacionService = PostulacionService();
  final PostulanteService _postulanteService = PostulanteService();
  final TrabajoService _trabajoService = TrabajoService(); // <-- AÑADIDO

  // Variables para guardar los datos y estados
  Map<String, dynamic>? _usuarioData;
  Trabajo? _trabajoData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  /// Carga los datos del usuario y del trabajo en paralelo.
  Future<void> _loadAllData() async {
    try {
      // Ejecutamos ambas peticiones al mismo tiempo
      final results = await Future.wait([
        _postulanteService.obtenerDatosUsuario(widget.usuarioId),
        _trabajoService.obtenerDatosTrabajo(widget.trabajoId),
      ]);

      // Asignamos los resultados
      _usuarioData = results[0] as Map<String, dynamic>?;
      _trabajoData = results[1] as Trabajo?;

      // Verificamos si alguno falló
      if (_usuarioData == null) {
        _error = 'No se pudieron cargar los datos del postulante.';
      } else if (_trabajoData == null) {
        _error = 'No se pudieron cargar los datos del trabajo.';
      }

    } catch (e) {
      _error = 'Error al cargar datos: $e';
    } finally {
      // Actualizamos la UI
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- FIN LÓGICA DE ESTADO ---


  // Método para actualizar el estado de la postulación (Sin cambios)
  Future<void> _actualizarEstadoPostulacion(
      String estado, BuildContext context) async {
    final nuevoEstado = estado.toLowerCase();
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
            Text(mensaje, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );

    try {
      await _postulacionService.actualizarEstado(
        trabajoId: widget.trabajoId, // <-- Usa widget.
        postulanteId: widget.usuarioId, // <-- Usa widget.
        nuevoEstado: nuevoEstado,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Cerrar loader

      final estadoCapitalizado = nuevoEstado.isEmpty
          ? nuevoEstado
          : '${nuevoEstado[0].toUpperCase()}${nuevoEstado.substring(1)}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Postulación $estadoCapitalizado con éxito'),
          backgroundColor: nuevoEstado == "aceptado" ? Colors.green : Colors.red,
        ),
      );
      Navigator.of(context).pop(); // Volver a la pantalla anterior
    } catch (e) {
      print('Error al actualizar el estado: $e');
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Cerrar loader si hubo error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el estado: $e')),
      );
    }
  }

  // --- WIDGET AUXILIAR: Ítem de Detalle (Sin cambios) ---
  Widget _buildDetailItem(
      BuildContext context, IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
      title: Text(
        title,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }

  // Widget auxiliar para crear tarjetas de sección (Sin cambios)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Postulante'),
      ),
      body: _buildBody(context), // <-- CAMBIO: El body ahora es un método
    );
  }

  /// Construye el cuerpo de la pantalla basado en el estado de carga
  Widget _buildBody(BuildContext context) {
    // --- ⚠️ MANEJO DE ESTADOS DE CARGA ---
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_usuarioData == null || _trabajoData == null) {
      return const Center(
          child: Text('Error al cargar los datos del postulante o no encontrado.'));
    }
    // --- FIN MANEJO DE ESTADOS ---

    // Si todo está bien, extraemos los datos
    final usuarioData = _usuarioData!;
    final trabajoData = _trabajoData!; // <-- YA TENEMOS LOS DATOS DEL TRABAJO

    // Extracción de datos del usuario (como antes)
    final fotoUrl = usuarioData['fotoUrl'] as String?;
    final nombre = usuarioData['nombre'] ?? 'Sin nombre';
    final apellido = usuarioData['apellido'] ?? '';
    final nombreCompleto = '$nombre $apellido';
    final carrera = usuarioData['carrera'] ?? 'No disponible';
    final email = usuarioData['email'] ?? 'No disponible';
    final telefono = usuarioData['telefono'] ?? 'No disponible';
    final descripcion = usuarioData['descripcion'] ?? 'Sin descripción.';
    final primaryColor = Theme.of(context).colorScheme.primary;
    final successColor = AppColors.success;
    final rejectColor = AppColors.rejectColor;

    // --- ⚠️ LA CONDICIÓN QUE PEDISTE ---
    // 1. El trabajo debe estar 'activo' (tu enum 'activo' o el string 'abierto')
    final bool esActivo = trabajoData.estado == EstadoTrabajo.activo;
    // 2. El trabajo no debe tener un trabajador asignado
    final bool noAsignado = trabajoData.trabajadorAsignadoId == null ||
                            trabajoData.trabajadorAsignadoId!.isEmpty;
    // Condición final
    final bool mostrarBotones = esActivo && noAsignado;
    // --- FIN DE LA CONDICIÓN ---

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, mostrarBotones ? 120.0 : 16.0), // <-- Padding dinámico
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. ENCABEZADO Y DATOS PRINCIPALES ---
              Center(
                child: Column(
                  children: [
                    _PostulanteAvatar(
                      nombre: nombre,
                      fotoUrl: fotoUrl,
                      primaryColor: primaryColor,
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
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // --- ⚠️ BOTONES CONDICIONALES ---
        // Solo muestra los botones si 'mostrarBotones' es true
        if (mostrarBotones)
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
        // --- FIN BOTONES CONDICIONALES ---
      ],
    );
  }
}
