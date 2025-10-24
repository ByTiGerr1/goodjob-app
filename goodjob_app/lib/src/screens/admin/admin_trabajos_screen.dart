import 'package:flutter/material.dart';
import 'package:goodjob_app/src/screens/admin/detalle_trabajo_admin_screen.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/models/trabajo.dart'; // Asegurar que Trabajo y su extensión están importados
import 'package:goodjob_app/src/providers/trabajo_provider.dart';
import 'postulantes_trabajo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- IMPORTANTE: Asegúrate de tener este import

// =========================================================================
// WIDGET DE FILTROS: _FilterControls
// Mantiene la lógica de filtros de dos niveles (Categoría + Chips de Estado)
// =========================================================================
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
      null, // Añadido para poder deseleccionar un estado específico
      EstadoTrabajo.activo,
      EstadoTrabajo.porConfirmar,
      EstadoTrabajo.pendiente,
    ],
    'En Proceso': [
      null, // Añadido para poder deseleccionar un estado específico
      EstadoTrabajo.enCurso,
      EstadoTrabajo.porRevisar,
      EstadoTrabajo.porPagar,
    ],
    'Cerrados': [
      null, // Añadido para poder deseleccionar un estado específico
      EstadoTrabajo.finalizado,
      EstadoTrabajo.cancelado,
      EstadoTrabajo.rechazado,
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
      case EstadoTrabajo.activo:
        return Icons.bolt_rounded;
      case EstadoTrabajo.porConfirmar:
        return Icons.access_time_filled_rounded;
      case EstadoTrabajo.pendiente:
        return Icons.schedule_rounded;
      case EstadoTrabajo.enCurso:
        return Icons.directions_run_rounded;
      case EstadoTrabajo.porRevisar:
        return Icons.rate_review_rounded;
      case EstadoTrabajo.porPagar:
        return Icons.payments_rounded;
      case EstadoTrabajo.finalizado:
        return Icons.check_circle_outline_rounded;
      case EstadoTrabajo.cancelado:
        return Icons.cancel_rounded;
      case EstadoTrabajo.rechazado:
        return Icons.close_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    // Obtener la lista de estados base para el carrusel de chips actual
    final currentCategoryKey = _categories[_selectedCategoryIndex];

    // Lista mutable para la vista de chips
    List<EstadoTrabajo?> visibleFilterOptions = List.from(
      _categoryMap[currentCategoryKey]!,
    );

    return Consumer<TrabajoProvider>(
      builder: (context, trabajoProvider, child) {
        final selectedFilter = trabajoProvider.filtroEstado;

        // ** UX FIX: Asegurar que el filtro ACTIVO siempre sea visible **
        // Si hay un filtro activo Y ese filtro NO está en la categoría actual
        if (selectedFilter != null &&
            !visibleFilterOptions.contains(selectedFilter)) {
          // Insertar el filtro activo al principio, justo después del chip 'Todos' si existe.
          final indexToInsert = visibleFilterOptions.contains(null) ? 1 : 0;
          visibleFilterOptions.insert(indexToInsert, selectedFilter);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

                        // Lógica de UX: Reseteamos el filtro de estado al cambiar de categoría
                        if (selectedFilter != null) {
                          trabajoProvider.setFiltroEstado(null);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ), // Borde más grueso
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
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
                children: visibleFilterOptions.map((estado) {
                  // Usar la lista con el filtro activo insertado
                  // Simplificación UX: Obtener texto directamente del enum o hardcode 'Todos'
                  final texto = estado == null ? 'Todos' : estado.texto;
                  final isSelected = selectedFilter == estado;

                  // UX/UI: Uso de colores semánticos
                  final backgroundColor = isSelected
                      ? primaryColor
                      : (estado == null
                            ? Colors.grey.shade200
                            : estado.colorChip);
                  final foregroundColor = isSelected
                      ? Colors.white
                      : (estado == null ? primaryColor : estado.colorTextoChip);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(
                        texto,
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      avatar: Icon(
                        _getIconForEstado(estado),
                        size: 18,
                        color: foregroundColor,
                      ),
                      backgroundColor: backgroundColor,
                      side: isSelected
                          ? BorderSide.none
                          : BorderSide(
                              color: foregroundColor.withOpacity(0.4),
                              width: 1,
                            ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
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

  // --- ¡NUEVO MÉTODO DE NAVEGACIÓN! ---
  /// Navega a la pantalla de detalle obteniendo primero el ID del admin.
  void _navegarADetalle(BuildContext context, Trabajo trabajo) {
    // 1. Obtener el usuario actual de Firebase Auth
    final user = FirebaseAuth.instance.currentUser;

    // 2. Verificar que el usuario exista
    if (user != null) {
      final String adminId = user.uid; // ¡Aquí está el ID!

      // 3. Navegar pasando el adminId
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleTrabajoAdminScreen(
            trabajo: trabajo,
            adminId: adminId, // <-- ¡Argumento requerido añadido!
          ),
        ),
      );
    } else {
      // 4. Manejar error si no se encuentra el usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo identificar al administrador.'),
        ),
      );
    }
  }

  // --- WIDGETS DE LISTA ---

  // ... (Código anterior de _AdminTrabajosScreenState, incluyendo _navegarADetalle) ...

  Widget _buildTrabajoGestionCard(BuildContext context, Trabajo trabajo) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryTextColor =
        Colors.grey.shade600; // Color neutro para texto secundario

    // Formato de fechas para diferenciación rápida
    final String fechaInicio = FormatUtils.formatDate(
      trabajo.fechaInicioTrabajo,
    );
    final String fechaFin = FormatUtils.formatDate(trabajo.fechaFinTrabajo);
    final String fechaTexto = '$fechaInicio - $fechaFin';

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navegación a la vista de edición/detalle
          _navegarADetalle(context, trabajo);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título, Empresa y Estado
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(
                          trabajo.titulo,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 4),
                        // Empresa
                        Text(
                          trabajo.empresa,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        // Chip de Estado
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                  // Cantidad de Postulantes
                  FutureBuilder<int>(
                    future: postulacionService.contarPostulaciones(trabajo.id),
                    builder: (context, snapshot) {
                      final postulantes = snapshot.data ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                            else
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
                                fontWeight: FontWeight.w500,
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
                  // Fecha
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    fechaTexto,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Precio
                  Icon(
                    Icons.payments_rounded,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(trabajo.precio != null) ? FormatUtils.formatCurrency(trabajo.precio.toDouble()) : 'N/D'} CLP',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // // const Divider(
              // //   height: 24,
              // //   thickness: 1,
              // ), // Separador visual para las acciones
              // // Fila de Acciones
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.end,
              //   children: [
              //     // Botón para ver detalles del trabajo (Ícono para editar/ver)
              //     Tooltip(
              //       message: 'Ver/Editar Detalles del Trabajo',
              //       child: IconButton(
              //         icon: Icon(
              //           Icons.edit_note_rounded,
              //           size: 28,
              //           color: Colors.grey.shade600,
              //         ),
              //         onPressed: () {
              //           // --- CAMBIO ---
              //           // Usamos la nueva función de navegación
              //           _navegarADetalle(context, trabajo);
              //         },
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     // Botón principal: Gestionar Postulantes
              //     Expanded(
              //       child: ElevatedButton.icon(
              //         onPressed: () {
              //           Navigator.push(
              //             context,
              //             MaterialPageRoute(
              //               builder: (_) =>
              //                   PostulantesTrabajoScreen(trabajoId: trabajo.id),
              //             ),
              //           );
              //         },
              //         icon: const Icon(
              //           Icons.person_search_rounded,
              //           size: 20,
              //           color: Colors.white,
              //         ),
              //         label: const Text(
              //           'Gestionar Postulantes',
              //           style: TextStyle(
              //             color: Colors.white,
              //             fontWeight: FontWeight.bold,
              //           ),
              //         ),
              //         style: ElevatedButton.styleFrom(
              //           backgroundColor: primaryColor,
              //           padding: const EdgeInsets.symmetric(
              //             horizontal: 16,
              //             vertical: 12,
              //           ),
              //           shape: RoundedRectangleBorder(
              //             borderRadius: BorderRadius.circular(10),
              //           ),
              //           elevation: 3,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  } // Fin de _buildTrabajoGestionCard

  // Renombrado para que se ajuste mejor a ser el cuerpo (body) del Scaffold
  Widget _buildTrabajosListBody(BuildContext context) {
    return Consumer<TrabajoProvider>(
      builder: (context, trabajoProvider, child) {
        if (trabajoProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (trabajoProvider.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 60,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar trabajos: ${trabajoProvider.errorMessage}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.alertColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final trabajosFiltrados = trabajoProvider.trabajosFiltrados;
        final totalTrabajos = trabajoProvider.trabajos.length;

        // Ordenar por fecha de límite (más reciente primero)
        final trabajosOrdenados = List<Trabajo>.from(trabajosFiltrados)
          ..sort((a, b) {
            // Asumiendo que Trabajo tiene una propiedad `fechaLimite` y `sinFechaLimite` para la lógica de ordenamiento
            DateTime valorA = (a.sinFechaLimite || a.fechaLimite == null)
                ? DateTime(2100)
                : a.fechaLimite!;

            DateTime valorB = (b.sinFechaLimite || b.fechaLimite == null)
                ? DateTime(2100)
                : b.fechaLimite!;

            return valorB.compareTo(
              valorA,
            ); // Ordenar por fecha límite (descendente)
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controles de Filtro (UI/UX Mejorado: Chips Dinámicos Deslizables)
            _FilterControls(totalCount: totalTrabajos),

            // Título de la Lista (Ahora como un subtítulo de conteo de resultados filtrados)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Mostrando ${trabajosOrdenados.length} resultados filtrados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
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
                      ),
                    )
                  : ListView.builder(
                      // Padding inferior aumentado para no tapar por el FAB o el final del contenido
                      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
                      itemCount: trabajosOrdenados.length,
                      itemBuilder: (context, index) {
                        final trabajo = trabajosOrdenados[index];
                        return _buildTrabajoGestionCard(
                          context,
                          trabajo,
                        ); // Tarjeta UI/UX Mejorada
                      },
                    ),
            ),
          ],
        );
      },
    );
  } // Fin de _buildTrabajosListBody

  @override
  Widget build(BuildContext context) {
    // Implementación principal con Scaffold, AppBar y FAB.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Trabajos'),
        centerTitle: false,
        elevation: 2, // Añade una ligera sombra
        actions: [
          // Opción de búsqueda
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: Implementar funcionalidad de búsqueda
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidad de búsqueda no implementada'),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildTrabajosListBody(context),
      // Puedes agregar un FloatingActionButton aquí si necesitas crear trabajos
      /*
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        // TODO: Navegar a la pantalla de crear trabajo
      },
      label: const Text('Crear Trabajo'),
      icon: const Icon(Icons.add),
    ),
    */
    );
  } // Fin del build principal
} // Fin de _AdminTrabajosScreenState
