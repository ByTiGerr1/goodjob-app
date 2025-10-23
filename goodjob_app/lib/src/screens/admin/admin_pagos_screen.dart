import 'package:flutter/material.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_por_pagar_screen.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_pagado_screen.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/providers/trabajo_provider.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';


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

  // Widget para trabajos pagados (historial)
  Widget _buildTrabajoPagadoCompact(BuildContext context, Trabajo trabajo) {
    final double precio = trabajo.precio;
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: successColor.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navegación a la pantalla de detalle de trabajo pagado
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminTrabajoPagadoScreen(
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
                    // Título del trabajo
                    Text(
                      trabajo.titulo,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    // Nombre del Trabajador
                    _buildWorkerName(trabajo.id),
                    const SizedBox(height: 6),
                    // Chip de Estado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: successColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pagado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: successColor,
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
                    // Monto Pagado
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'PAGADO',
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.formatCurrency(precio),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Ícono de Acción/Navegación
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 30,
                      color: successColor.withOpacity(0.7),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Pagos',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<TrabajoProvider>(
        builder: (context, trabajoProvider, child) {
          // Filtrar trabajos por pagar
          final trabajosPorPagar = trabajoProvider.trabajos
              .where((t) => t.estado == EstadoTrabajo.porPagar)
              .toList();

          // Filtrar trabajos pagados (finalizados con pagado = true)
          final trabajosPagados = trabajoProvider.trabajos
              .where((t) => t.estado == EstadoTrabajo.finalizado && t.pagado == true)
              .toList();

          // Mostrar loading si la lista principal está vacía
          if (trabajoProvider.trabajos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Si no hay trabajos por pagar ni pagados
          if (trabajosPorPagar.isEmpty && trabajosPagados.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay pagos registrados',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aún no hay trabajos pendientes de pago ni historial de pagos realizados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Sección de trabajos por pagar
              if (trabajosPorPagar.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    child: Text(
                      'Tareas pendientes: ${trabajosPorPagar.length}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trabajo = trabajosPorPagar[index];
                        return _buildTrabajoPagoCompact(context, trabajo);
                      },
                      childCount: trabajosPorPagar.length,
                    ),
                  ),
                ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: successColor, size: 40),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                '¡Todas las cuentas están al día!\nNo hay trabajos pendientes de pago.',
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Sección de historial de trabajos pagados
              if (trabajosPagados.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: successColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Historial de trabajos pagados',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: successColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                    child: Text(
                      '${trabajosPagados.length} trabajo${trabajosPagados.length != 1 ? 's' : ''} completado${trabajosPagados.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final trabajo = trabajosPagados[index];
                        return _buildTrabajoPagadoCompact(context, trabajo);
                      },
                      childCount: trabajosPagados.length,
                    ),
                  ),
                ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: Colors.grey[100],
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey, size: 40),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'No hay historial de pagos realizados aún.',
                                style: TextStyle(fontSize: 14, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Espacio al final
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          );
        },
      ),
    );
  }
}
