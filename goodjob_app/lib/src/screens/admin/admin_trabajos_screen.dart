import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/providers/trabajo_provider.dart';
import 'postulantes_trabajo_screen.dart';
import 'admin_trabajo_router.dart';

// Widget separado para los filtros que mantiene su estado
class _FilterControls extends StatefulWidget {
  final int totalCount;

  const _FilterControls({required this.totalCount});

  @override
  State<_FilterControls> createState() => _FilterControlsState();
}

class _FilterControlsState extends State<_FilterControls> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Crear lista con "Todos" primero y luego todos los estados
    final List<MapEntry<EstadoTrabajo?, String>> filterOptions = [
      const MapEntry(null, 'Todos'),
      ...EstadoTrabajo.values.map((e) => MapEntry(e, e.texto)),
    ];

    return Consumer<TrabajoProvider>(
      builder: (context, trabajoProvider, child) {
        final selectedFilter = trabajoProvider.filtroEstado;

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 8.0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterOptions.map((entry) {
                  final estado = entry.key;
                  final texto = entry.value;
                  final isSelected = selectedFilter == estado;
                  final color = isSelected ? primaryColor : Colors.transparent;
                  final textColor = isSelected ? Colors.white : Colors.black87;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () {
                        // Usar el provider para cambiar el filtro (no rebuild del widget)
                        trabajoProvider.setFiltroEstado(estado);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            texto,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminTrabajosScreen extends StatefulWidget {
  const AdminTrabajosScreen({super.key});

  @override
  State<AdminTrabajosScreen> createState() => _AdminTrabajosScreenState();
}

class _AdminTrabajosScreenState extends State<AdminTrabajosScreen> {
  final PostulacionService postulacionService = PostulacionService();

  // --- WIDGETS DE LISTA ---

  Widget _buildTrabajoGestionCard(BuildContext context, Trabajo trabajo) {
    final primaryColor = Theme.of(context).colorScheme.primary;
        
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => getAdminTrabajoView(
                trabajoId: trabajo.id,
                trabajoData: trabajo.toMap(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Título y Estado
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trabajo.titulo,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        // Chip de Estado
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(trabajo.estado.texto,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  
                  // Cantidad de Postulantes (Usando FutureBuilder)
                  FutureBuilder<int>(
                    future: postulacionService.contarPostulaciones(trabajo.id),
                    builder: (context, snapshot) {
                      final postulantes = snapshot.data ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            Text('$postulantes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                          const Text('Postulantes', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Fila de Acciones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón para ver detalles del trabajo
                  IconButton(
                    icon: const Icon(Icons.edit_note, size: 24),
                    color: primaryColor,
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => getAdminTrabajoView(trabajoId: trabajo.id, trabajoData: trabajo.toMap())));
                    },
                  ),
                  const SizedBox(width: 8),
                  // Botón principal: Ver postulantes
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostulantesTrabajoScreen(trabajoId: trabajo.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.group, size: 20, color: Colors.white),
                    label: const Text('Ver postulantes', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrabajosPublicados() {
    return Consumer<TrabajoProvider>(
      builder: (context, trabajoProvider, child) {
        final trabajosFiltrados = trabajoProvider.trabajosFiltrados;
        final totalTrabajos = trabajoProvider.trabajos.length;

        // Ordenar por fecha de creación (más reciente primero)
        final trabajosOrdenados = List<Trabajo>.from(trabajosFiltrados)
          ..sort((a, b) {
            DateTime valorA;
            if (a.sinFechaLimite || a.fechaLimite == null) {
              valorA = DateTime(2100);
            } else {
              valorA = a.fechaLimite!;
            }

            DateTime valorB;
            if (b.sinFechaLimite || b.fechaLimite == null) {
              valorB = DateTime(2100);
            } else {
              valorB = b.fechaLimite!;
            }

            return valorB.compareTo(valorA);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controles de Filtro
            _FilterControls(totalCount: totalTrabajos),
            
            // Título de la Lista
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Resultados: (${trabajosOrdenados.length})',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),

            // Lista de Trabajos Filtrada
            Expanded(
              child: trabajosOrdenados.isEmpty
                  ? const Center(child: Text('No hay trabajos que coincidan con el filtro.'))
                  : ListView.builder(
                      // Padding inferior aumentado para no tapar por el FAB
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0),
                      itemCount: trabajosOrdenados.length,
                      itemBuilder: (context, index) {
                        final trabajo = trabajosOrdenados[index];
                        return _buildTrabajoGestionCard(context, trabajo);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildTrabajosPublicados();
  }
}
