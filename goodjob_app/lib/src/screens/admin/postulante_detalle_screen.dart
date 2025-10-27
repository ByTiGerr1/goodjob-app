import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/widgets/postulante_avatar.dart';
import 'package:goodjob_app/theme/app_colors.dart';

// ====================================================================
// PANTALLA PRINCIPAL: PostulanteDetalleScreen
// ====================================================================

class PostulanteDetalleScreen extends StatefulWidget {
  final String usuarioId;
  final String trabajoId;

  const PostulanteDetalleScreen({
    super.key,
    required this.usuarioId,
    required this.trabajoId,
  });

  @override
  State<PostulanteDetalleScreen> createState() =>
      _PostulanteDetalleScreenState();
}

class _PostulanteDetalleScreenState extends State<PostulanteDetalleScreen> {
  final PostulacionService _postulacionService = PostulacionService();
  final PostulanteService _postulanteService = PostulanteService();
  final TrabajoService _trabajoService = TrabajoService();

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

  // Método para actualizar el estado de la postulación
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
        trabajoId: widget.trabajoId,
        postulanteId: widget.usuarioId,
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

  // --- WIDGET AUXILIAR: Ítem de Detalle ---
  Widget _buildDetailItem(
      BuildContext context, IconData icon, String title, String value) {
    // --- MODIFICACIÓN: Manejar valor vacío ---
    final displayValue = (value.isEmpty) ? 'No disponible' : value;

    return ListTile(
      leading:
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
      title: Text(
        title,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
      ),
      subtitle: Text(
        displayValue,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }

  // Widget auxiliar para crear tarjetas de sección
  Widget _buildSectionCard(BuildContext context,
      {required String title, required List<Widget> children}) {
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

  // --- NUEVO: Función para calcular la edad ---
  int? _calcularEdad(Timestamp? timestamp) {
    if (timestamp == null) return null;
    final birthDate = timestamp.toDate();
    final hoy = DateTime.now();
    int edad = hoy.year - birthDate.year;
    if (hoy.month < birthDate.month ||
        (hoy.month == birthDate.month && hoy.day < birthDate.day)) {
      edad--;
    }
    return edad;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Postulante'),
      ),
      body: _buildBody(context), // El body ahora es un método
    );
  }

  /// Construye el cuerpo de la pantalla basado en el estado de carga
  Widget _buildBody(BuildContext context) {
    // --- MANEJO DE ESTADOS DE CARGA ---
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
          child:
              Text('Error al cargar los datos del postulante o no encontrado.'));
    }
    // --- FIN MANEJO DE ESTADOS ---

    // Si todo está bien, extraemos los datos
    final usuarioData = _usuarioData!;
    final trabajoData = _trabajoData!;

    // --- MODIFICADO: Extracción de todos los datos ---
    final fotoUrl = usuarioData['fotoUrl'] as String?;
    final nombre = usuarioData['nombre'] ?? 'Sin nombre';
    final apellido = usuarioData['apellido'] ?? '';
    final nombreCompleto = '$nombre $apellido';
    final email = usuarioData['email'] ?? 'No disponible';
    final telefono = usuarioData['telefono'] ?? ''; // Vacío por defecto
    final descripcion = usuarioData['descripcion'] ?? ''; // Vacío por defecto

    // --- NUEVO: Extracción de datos personales ---
    final genero = usuarioData['genero'] ?? 'No especificado';
    final nacionalidad = usuarioData['nacionalidad'] ?? 'No especificada';
    final hasDisability = usuarioData['discapacidad'] as bool? ?? false;
    final birthDateTimestamp = usuarioData['fechaNacimiento'] as Timestamp?;
    final int? edad = _calcularEdad(birthDateTimestamp);

    // Extracción de campos de perfil
    final carrera = usuarioData['carrera'] ?? '';
    final ocupacion = usuarioData['ocupacion'] as String? ?? 'No especificada';
    final otraOcupacion = usuarioData['otraOcupacion'] as String? ?? '';
    final habilidades =
        (usuarioData['habilidades'] as List<dynamic>?)?.cast<String>() ?? [];
    final experiencias =
        (usuarioData['experiencias'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    final primaryColor = Theme.of(context).colorScheme.primary;
    final successColor = AppColors.success;
    final rejectColor = AppColors.rejectColor;

    // Lógica para el título principal
    String tituloPrincipal;
    if (ocupacion == 'Estudiante' && carrera.isNotEmpty) {
      tituloPrincipal = carrera;
    } else if (ocupacion == 'Otro' && otraOcupacion.isNotEmpty) {
      tituloPrincipal = otraOcupacion;
    } else {
      tituloPrincipal = ocupacion;
    }
    // --- FIN LÓGICA TÍTULO ---

    // Condición para mostrar botones
    final bool esActivo = trabajoData.estado == EstadoTrabajo.activo;
    final bool noAsignado = trabajoData.trabajadorAsignadoId == null ||
        trabajoData.trabajadorAsignadoId!.isEmpty;
    final bool mostrarBotones = esActivo && noAsignado;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16.0, 16.0, 16.0, mostrarBotones ? 120.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. ENCABEZADO Y DATOS PRINCIPALES ---
              Center(
                child: Column(
                  children: [
                    PostulanteAvatar(
                      nombre: nombre,
                      fotoUrl: fotoUrl,
                      radius: 70,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      nombreCompleto,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      tituloPrincipal,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor),
                      textAlign: TextAlign.center,
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
                  Text(
                    descripcion.isNotEmpty
                        ? descripcion
                        : 'No ha añadido una descripción.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: descripcion.isNotEmpty
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- NUEVO: 3. DATOS PERSONALES ---
              _buildSectionCard(
                context,
                title: 'Datos Personales',
                children: [
                  _buildDetailItem(context, Icons.cake_outlined, 'Edad',
                      edad != null ? '$edad años' : 'No disponible'),
                  const Divider(indent: 16, endIndent: 16),
                  _buildDetailItem(
                      context, Icons.person_search_outlined, 'Género', genero),
                  const Divider(indent: 16, endIndent: 16),
                  _buildDetailItem(context, Icons.flag_outlined, 'Nacionalidad',
                      nacionalidad),
                  const Divider(indent: 16, endIndent: 16),
                  _buildDetailItem(
                      context,
                      Icons.accessible_forward_outlined,
                      'Cuenta con discapacidad',
                      hasDisability ? 'Sí' : 'No'),
                ],
              ),
              const SizedBox(height: 16),

              // --- 4. HABILIDADES ---
              _buildSectionCard(
                context,
                title: 'Habilidades',
                children: [
                  if (habilidades.isEmpty)
                    Text(
                      'No ha añadido habilidades.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: habilidades.map((habilidad) {
                        return Chip(
                          label: Text(habilidad,
                              style: TextStyle(color: primaryColor)),
                          backgroundColor: primaryColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: primaryColor.withOpacity(0.3)),
                          ),
                        );
                      }).toList(),
                    )
                ],
              ),
              const SizedBox(height: 16),

              // --- 5. MI EXPERIENCIA ---
              _buildSectionCard(
                context,
                title: 'Mi Experiencia',
                children: [
                  if (experiencias.isEmpty)
                    Text(
                      'No ha añadido experiencia.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    // Usamos un Column en lugar de ListView
                    Column(
                      children: experiencias.map((exp) {
                        final rol = exp['rol'] ?? 'Sin rol';
                        final lugar = exp['lugarOProyecto'] ?? 'Sin lugar';
                        final desc = exp['descripcion'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.1),
                              foregroundColor: primaryColor,
                              child: const Icon(Icons.cases_outlined),
                            ),
                            title: Text(rol,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text("$lugar\n$desc"),
                            isThreeLine: desc.isNotEmpty,
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // --- 6. INFORMACIÓN DE CONTACTO ---
              _buildSectionCard(
                context,
                title: 'Información de contacto',
                children: [
                  _buildDetailItem(context, Icons.email_outlined,
                      'Correo electrónico', email),
                  const Divider(indent: 16, endIndent: 16),
                  _buildDetailItem(
                      context, Icons.phone_outlined, 'Teléfono', telefono),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // --- BOTONES CONDICIONALES ---
        if (mostrarBotones)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -5))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _actualizarEstadoPostulacion('aceptado', context),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Aceptar',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _actualizarEstadoPostulacion('rechazado', context),
                      icon: Icon(Icons.close, color: rejectColor),
                      label: Text('Rechazar',
                          style: TextStyle(color: rejectColor, fontSize: 18)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: rejectColor, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
