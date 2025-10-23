import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/models/trabajo.dart'; // Asegurar que Trabajo y su extensión están importados
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
  // Estado local para manejar la categoría de la pestaña seleccionada
  int _selectedCategoryIndex = 0; 
  final ScrollController _scrollController = ScrollController(); 

  // Definición de las 4 categorías principales para el Nivel 1 (Tab Bar)
  final List<String> _categories = [
    'Todos',
    'Publicados', 
    'En Proceso', 
    'Cerrados',    
  ];

  // Mapeo de categorías a los estados que deben mostrarse en el Nivel 2 (Chips)
  final Map<String, List<EstadoTrabajo?>> _categoryMap = {
    'Todos': [null, ...EstadoTrabajo.values],
    'Publicados': [
      EstadoTrabajo.activo,
      EstadoTrabajo.porConfirmar,
      EstadoTrabajo.pendiente,
    ],
    'En Proceso': [
      EstadoTrabajo.enCurso,
      EstadoTrabajo.porRevisar,
      EstadoTrabajo.porPagar,
    ],
    'Cerrados': [
      EstadoTrabajo.finalizado,
      EstadoTrabajo.cancelado,
      EstadoTrabajo.rechazado, // Corregido el error tipográfico
    ],
  };

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Función auxiliar para obtener el ícono según el estado
  IconData _getIconForEstado(EstadoTrabajo? e) {
      if (e == null) return Icons.select_all_rounded;
      switch (e) {
          case EstadoTrabajo.activo: return Icons.bolt_rounded;
          case EstadoTrabajo.porConfirmar: return Icons.access_time_filled_rounded;
          case EstadoTrabajo.pendiente: return Icons.schedule_rounded;
          case EstadoTrabajo.enCurso: return Icons.directions_run_rounded;
          case EstadoTrabajo.porRevisar: return Icons.rate_review_rounded;
          case EstadoTrabajo.porPagar: return Icons.payments_rounded;
          case EstadoTrabajo.finalizado: return Icons.check_circle_outline_rounded;
          case EstadoTrabajo.cancelado: return Icons.cancel_rounded;
          case EstadoTrabajo.rechazado: return Icons.close_rounded;
          default: return Icons.dashboard;
      }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Obtener la lista de estados base para el carrusel de chips actual
    final currentCategoryKey = _categories[_selectedCategoryIndex];
    
    // Lista mutable para la vista de chips
    List<EstadoTrabajo?> visibleFilterOptions = List.from(_categoryMap[currentCategoryKey]!);
    
    return Consumer<TrabajoProvider>(
      builder: (context, trabajoProvider, child) {
        final selectedFilter = trabajoProvider.filtroEstado;

        // ** UX FIX: Asegurar que el filtro ACTIVO siempre sea visible **
        // Si hay un filtro activo Y ese filtro NO está en la categoría actual (ej: filtro "Cancelado" pero pestaña "Publicados")
        if (selectedFilter != null && !visibleFilterOptions.contains(selectedFilter)) {
          // Insertar el filtro activo al principio de la lista de chips visibles
          visibleFilterOptions.insert(0, selectedFilter); 
        }
        // Fin del UX FIX

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Contenedor de Conteo Total (Estilo pill-shape limpio)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: primaryColor.withOpacity(0.1), // Color del tema para un look más integrado
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Ajustar al contenido
                  children: [
                    Icon(Icons.layers_rounded, size: 18, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Total de Trabajos: ${widget.totalCount}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),

            // Nivel 1: Barra de Categorías (Tab Bar UX)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    final isSelected = _selectedCategoryIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryIndex = index;
                        });
                        
                        // Lógica de UX: Si la nueva categoría no contiene el filtro activo, lo reseteamos
                        final nextCategoryOptions = _categoryMap[category]!;
                        if (selectedFilter != null && !nextCategoryOptions.contains(selectedFilter)) {
                           // Reseteamos a "Todos" (null) para no mostrar una lista vacía
                           trabajoProvider.setFiltroEstado(null); 
                        } else if (index == 0 && selectedFilter != null) {
                           // Si seleccionamos "Todos" y había un filtro aplicado, lo quitamos para ver realmente 'todos'
                           trabajoProvider.setFiltroEstado(null);
                        }
                      },
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            const SizedBox(height: 12),

            // Nivel 2: Fila de Chips Deslizables (Filtrados por Categoría)
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: visibleFilterOptions.map((estado) { // Usar la lista con el filtro activo insertado
                  // Simplificación UX: Obtener texto directamente del enum o hardcode 'Todos'
                  final texto = estado == null ? 'Todos' : estado.texto;
                  final isSelected = selectedFilter == estado;
                  
                  // UX/UI: Uso de colores semánticos
                  final backgroundColor = isSelected 
                      ? primaryColor 
                      : (estado == null ? Colors.grey.shade200 : estado.colorChip);
                  final foregroundColor = isSelected 
                      ? Colors.white 
                      : (estado == null ? primaryColor : estado.colorTextoChip);
                  

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(texto, style: TextStyle(
                        color: foregroundColor, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 14,
                      )),
                      avatar: Icon(_getIconForEstado(estado), size: 18, color: foregroundColor),
                      backgroundColor: backgroundColor,
                      side: isSelected ? BorderSide.none : BorderSide(color: foregroundColor.withOpacity(0.4), width: 1), 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      onPressed: () {
                        // Solo actualizar el filtro de la lista si es un cambio
                        if (selectedFilter != estado) {
                           trabajoProvider.setFiltroEstado(estado);
                        }
                      },
                      elevation: isSelected ? 4 : 0,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
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
  
  // Helper simple para formatear fechas (DD/MM)
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  Widget _buildTrabajoGestionCard(BuildContext context, Trabajo trabajo) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryTextColor = Colors.grey.shade600; // Color neutro para texto secundario

    // Formato de fechas para diferenciación rápida
    final String fechaInicio = _formatDate(trabajo.fechaInicioTrabajo);
    final String fechaFin = _formatDate(trabajo.fechaFinTrabajo);
    final String fechaTexto = '$fechaInicio - $fechaFin';
        
    return Card(
      // UI: Mayor elevación y bordes más redondos
      elevation: 6, 
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navegación a la vista de edición/detalle
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
                crossAxisAlignment: CrossAxisAlignment.start, // Alineación superior
                children: [
                  // Título, Empresa y Estado
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Título (Más líneas para evitar corte)
                        Text(
                          trabajo.titulo,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), 
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3, // Aumentado a 3 líneas (UX)
                        ),
                        const SizedBox(height: 4),

                        // 2. Empresa/Cliente (Menos negrita para reducir peso visual)
                        Text(
                          trabajo.empresa,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: secondaryTextColor), // Menos peso visual
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),

                        // 3. Chip de Estado (Contexto Visual Semántico)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: trabajo.estado.colorChip, 
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trabajo.estado.texto,
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.bold,
                              color: trabajo.estado.colorTextoChip, 
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Cantidad de Postulantes (KPI clave, se mantiene prominente)
                  FutureBuilder<int>(
                    future: postulacionService.contarPostulaciones(trabajo.id),
                    builder: (context, snapshot) {
                      final postulantes = snapshot.data ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (snapshot.connectionState == ConnectionState.waiting)
                              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))
                            else
                              // UI: Número grande, clave para el admin
                              Text(
                                '$postulantes', 
                                style: TextStyle(
                                  fontSize: 32, 
                                  fontWeight: FontWeight.bold, 
                                  color: primaryColor,
                                ),
                              ), 
                            const Text(
                              'Postulantes', 
                              style: TextStyle(
                                fontSize: 12, 
                                color: Colors.black87, 
                                fontWeight: FontWeight.w500
                              ),
                            ), 
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Fila de Contexto Rápido (Precio y Fechas)
              Row(
                children: [
                  // UX: Iconos en color neutro (secondaryTextColor) para reducir el ruido
                  Icon(Icons.calendar_month_rounded, size: 18, color: secondaryTextColor), 
                  const SizedBox(width: 6),
                  Text(fechaTexto, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: secondaryTextColor)),
                  
                  const SizedBox(width: 20),
                  
                  // UX: Iconos en color neutro
                  Icon(Icons.payments_rounded, size: 18, color: secondaryTextColor), 
                  const SizedBox(width: 6),
                  // Formato de precio, mantenido en negrita para énfasis financiero
                  Text('\$${trabajo.precio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              
              const Divider(height: 24, thickness: 1), // Separador visual para las acciones
              
              // Fila de Acciones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón para ver detalles del trabajo (Ícono para editar/ver)
                  Tooltip(
                    message: 'Ver/Editar Detalles del Trabajo',
                    child: IconButton(
                      icon: Icon(Icons.edit_note_rounded, size: 28, color: Colors.grey.shade600),
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => getAdminTrabajoView(trabajoId: trabajo.id, trabajoData: trabajo.toMap())));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón principal: Gestionar Postulantes
                  Expanded( 
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostulantesTrabajoScreen(trabajoId: trabajo.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_search_rounded, size: 20, color: Colors.white),
                      label: const Text('Gestionar Postulantes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), // UX: Mensaje más claro y orientado a la acción
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Mayor área de toque (Touch Target)
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                      ),
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

            return valorB.compareTo(valorA); // Ordenar por fecha límite (descendente)
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controles de Filtro (UI/UX Mejorado: Chips Dinámicos Deslizables)
            _FilterControls(totalCount: totalTrabajos),
            
            // Título de la Lista (Ahora como un subtítulo de conteo de resultados filtrados)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Mostrando ${trabajosOrdenados.length} resultados filtrados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
            ),

            // Lista de Trabajos Filtrada
            Expanded(
              child: trabajosOrdenados.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No se encontraron trabajos que coincidan con el filtro seleccionado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                      ))
                  : ListView.builder(
                      // Padding inferior aumentado para no tapar por el FAB o el final del contenido
                      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
                      itemCount: trabajosOrdenados.length,
                      itemBuilder: (context, index) {
                        final trabajo = trabajosOrdenados[index];
                        return _buildTrabajoGestionCard(context, trabajo); // Tarjeta UI/UX Mejorada
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
