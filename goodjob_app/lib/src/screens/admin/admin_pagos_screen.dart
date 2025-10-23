import 'package:flutter/material.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_por_pagar_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/providers/trabajo_provider.dart'; // Asumido
import 'package:goodjob_app/src/utils/format_utils.dart'; // Asumido para FormatUtils
// Se asume que esta es la pantalla detallada de pago que ya hemos mejorado


class AdminPagosScreen extends StatefulWidget {
  const AdminPagosScreen({super.key});

  @override
  State<AdminPagosScreen> createState() => _AdminPagosScreenState();
}

class _AdminPagosScreenState extends State<AdminPagosScreen> {
  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = Color(0xFF7B0997);
  static const Color successColor = Color(0xFF4CAF50);
  // Eliminamos warningColor, ya que el color de "Por Pagar" se obtiene del modelo (Púrpura).

  // Asumimos un servicio para obtener el nombre del trabajador confirmado
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Widget para obtener el nombre del trabajador (crucial para contexto de pago)
  Widget _buildWorkerName(String trabajoId) {
    return FutureBuilder<String>(
      // Buscar el nombre del usuario confirmado en la postulación
      future: _fetchConfirmedWorkerName(trabajoId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Cargando trabajador...', style: TextStyle(fontSize: 13, color: Colors.black45));
        }
        final name = snapshot.data ?? 'Trabajador no encontrado';
        return Row(
          children: [
            const Icon(Icons.person, size: 16, color: primaryColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _fetchConfirmedWorkerName(String trabajoId) async {
    try {
      final postulacionesSnapshot = await _firestore
          .collection('trabajos')
          .doc(trabajoId)
          .collection('postulaciones')
          .where('estado', isEqualTo: 'confirmado')
          .limit(1)
          .get();

      if (postulacionesSnapshot.docs.isNotEmpty) {
        final usuarioId = postulacionesSnapshot.docs.first.data()['usuarioId'] as String?;
        if (usuarioId != null) {
          final usuarioDoc = await _firestore.collection('usuarios').doc(usuarioId).get();
          if (usuarioDoc.exists) {
            final data = usuarioDoc.data();
            final nombre = data?['nombre'] ?? '';
            final apellido = data?['apellido'] ?? '';
            return '$nombre $apellido'.trim();
          }
        }
      }
      return 'N/A';
    } catch (e) {
      debugPrint('Error fetching worker name: $e');
      return 'Error al cargar';
    }
  }

  // Se refactoriza para un diseño compacto y escaneable
  Widget _buildTrabajoPagoCompact(BuildContext context, Trabajo trabajo) {
    final double precio = trabajo.precio;
    
    // *** USO DE COLORES DEL MODELO: Se obtiene el color específico de 'Por Pagar' ***
    final Color estadoTextColor = trabajo.estado.colorTextoChip;
    final Color estadoBackgroundColor = trabajo.estado.colorChip;
    // ******************************************************************************

    return Card(
      elevation: 1, // Menos elevación para ser más ligero
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        // UX: Borde de advertencia visual utilizando el color de fondo del estado
        side: BorderSide(color: estadoBackgroundColor.withOpacity(0.8), width: 1), 
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navegación a la pantalla de detalle de pago (el Canvas anterior)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminTrabajoPorPagarScreen(
                trabajoId: trabajo.id,
                trabajo: trabajo.toMap(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Izquierda: Contenido (Título, Trabajador, Estado)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título del trabajo (Más grande)
                    Text(
                      trabajo.titulo,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    // Nombre del Trabajador (Contexto)
                    _buildWorkerName(trabajo.id),
                    const SizedBox(height: 6),
                    // Chip de Estado (Pequeño recordatorio)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        // Usar el color de fondo del estado del modelo
                        color: estadoBackgroundColor, 
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trabajo.estado.texto, // 'Por Pagar'
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          // Usar el color de texto del estado del modelo
                          color: estadoTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Derecha: Monto y Acción
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Monto a Pagar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'PAGAR',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.formatCurrency(precio),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            // Usar el color de texto del estado del modelo
                            color: estadoTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Ícono de Acción/Navegación
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 30,
                      color: primaryColor.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    // Aquí asumimos que el TrabajoProvider nos da la lista filtrada de trabajos por pagar
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trabajos Pendientes de Pago',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<TrabajoProvider>(
        builder: (context, trabajoProvider, child) {
          // Asumimos que el proveedor tiene un getter para trabajos filtrados por 'porPagar'
          final trabajosPorPagar = trabajoProvider.trabajos.where((t) => t.estado == EstadoTrabajo.porPagar).toList();

          // FIX: Se reemplaza el chequeo `trabajoProvider.isLoading` (que causa error) 
          // por un chequeo directo de si la lista de trabajos principal está vacía.
          // Esto asume que si la lista está vacía, el proveedor está en proceso de carga inicial.
          if (trabajoProvider.trabajos.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }
          
          if (trabajosPorPagar.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 80, color: successColor.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      '¡Todas las cuentas están al día!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No hay trabajos pendientes de pago en este momento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  'Tareas pendientes: ${trabajosPorPagar.length}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: trabajosPorPagar.length,
                  itemBuilder: (context, index) {
                    final trabajo = trabajosPorPagar[index];
                    return _buildTrabajoPagoCompact(context, trabajo);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
