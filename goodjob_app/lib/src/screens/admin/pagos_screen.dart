import 'package:flutter/material.dart';
import 'package:goodjob_app/src/screens/admin/detalle_trabajo_admin_screen.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/providers/trabajo_provider.dart'; // Asumido
import 'package:goodjob_app/src/utils/format_utils.dart'; // Asumido para FormatUtils
import 'package:firebase_auth/firebase_auth.dart'; // <-- AÑADIDO: Importa Firebase Auth

class _PagosFilterControls extends StatefulWidget {
  // Ya no necesita totalCount

  const _PagosFilterControls();

  @override
  State<_PagosFilterControls> createState() => _PagosFilterControlsState();
}

class _PagosFilterControlsState extends State<_PagosFilterControls> {
  final ScrollController _scrollController = ScrollController();

  // Definición de la lista fija de chips de pago

  final List<EstadoTrabajo?> _filterOptions = [
    null, // 'Todos' (muestra Por Pagar y Pagado)

    EstadoTrabajo.porPagar, // 'Pendiente'

    EstadoTrabajo.finalizado, // 'Pagado'
  ];

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  // Función auxiliar para obtener el ícono según el estado

  IconData _getIconForEstado(EstadoTrabajo? e) {
    if (e == null) return Icons.select_all_rounded;

    switch (e) {
      case EstadoTrabajo.porPagar:
        return Icons.warning_amber_rounded;

      case EstadoTrabajo.finalizado:
        return Icons.check_circle_outline_rounded;

      default:
        return Icons
            .dashboard; // Solo para asegurar que todos los casos están cubiertos
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos los colores del tema para la estética

    final primaryColor = AppColors.primary;

    return Consumer<TrabajoProvider>(
      builder: (context, trabajoProvider, child) {
        // En Pagos, el filtro de estado SÓLO debe ser de tipo porPagar o finalizado

        final selectedFilter =
            (trabajoProvider.filtroEstado == EstadoTrabajo.porPagar ||
                trabajoProvider.filtroEstado == EstadoTrabajo.finalizado)
            ? trabajoProvider.filtroEstado
            : null; // Si es otro estado o null, lo tratamos como 'Todos'

        // Fila de Chips Deslizables (Es el único elemento de control que queda)

        return Padding(
          padding: const EdgeInsets.only(
            top: 16.0,
            bottom: 12.0,
          ), // Padding superior para separar del AppBar

          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,

            padding: const EdgeInsets.symmetric(horizontal: 16.0),

            child: Row(
              children: _filterOptions.map((estado) {
                // Modificación: La etiqueta 'Todos' debe ser la primera

                final texto = estado == null ? 'Todos los Pagos' : estado.texto;

                final isSelected = selectedFilter == estado;

                // Usar colores semánticos

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
                      if (selectedFilter != estado) {
                        // Establecer el filtro de estado

                        trabajoProvider.setFiltroEstado(estado);
                      }
                    },

                    elevation: isSelected ? 4 : 0,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// WIDGET PRINCIPAL RENOMBRADO: PagosScreen
// (Esta clase no necesita cambios)
// =========================================================================
class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

// =========================================================================
// ESTADO: _PagosScreenState
// (AQUÍ ES DONDE HACEMOS LOS CAMBIOS)
// =========================================================================
class _PagosScreenState extends State<PagosScreen> {
  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = Color(0xFF7B0997);
  static const Color successColor = Color(0xFF4CAF50);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
            adminId: adminId, // <-- Argumento requerido añadido
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

  Widget _buildWorkerName(String trabajoId) {
    return FutureBuilder<String>(
      future: _fetchConfirmedWorkerName(trabajoId),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'Cargando trabajador...',
            style: TextStyle(fontSize: 13, color: Colors.black45),
          );
        }

        final name = snapshot.data ?? 'Trabajador no encontrado';

        return Row(
          children: [
            const Icon(Icons.person, size: 16, color: primaryColor),

            const SizedBox(width: 4),

            Expanded(
              child: Text(
                name,

                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),

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
        final usuarioId =
            postulacionesSnapshot.docs.first.data()['usuarioId'] as String?;

        if (usuarioId != null) {
          final usuarioDoc = await _firestore
              .collection('usuarios')
              .doc(usuarioId)
              .get();

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

  // Tarjeta de trabajo de Pago (Compacta y optimizada para la lista)
  Widget _buildTrabajoPagoCompact(BuildContext context, Trabajo trabajo) {
    final double precio = trabajo.precio;
    final Color estadoTextColor = trabajo.estado.colorTextoChip;
    final Color estadoBackgroundColor = trabajo.estado.colorChip;
    final String actionTitle = trabajo.estado == EstadoTrabajo.porPagar
        ? 'PAGAR'
        : 'PAGADO';
    final Color actionColor = trabajo.estado == EstadoTrabajo.porPagar
        ? primaryColor
        : successColor;

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: estadoBackgroundColor.withOpacity(0.8),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // --- ¡CAMBIO AQUÍ! ---
          // Navegación a la pantalla de detalle de pago usando el nuevo método
          _navegarADetalle(context, trabajo);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 6),
                    // Nombre del Trabajador
                    _buildWorkerName(trabajo.id),
                    const SizedBox(height: 10),
                    // Chip de Estado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: estadoBackgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trabajo.estado.texto,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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
                    // Monto/Acción a Pagar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          actionTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: actionColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.formatCurrency(precio),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: estadoTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Ícono de Acción/Navegación
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 36,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } // Fin de _buildTrabajoPagoCompact

  // Cuerpo principal que contiene los filtros y la lista
  Widget _buildPagosListBody(BuildContext context) {
    return Consumer<TrabajoProvider>(
      builder: (context, trabajoProvider, child) {
        if (trabajoProvider.trabajos.isEmpty &&
            !trabajoProvider.hasError &&
            trabajoProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (trabajoProvider.hasError) {
          return Center(child: Text('Error: ${trabajoProvider.errorMessage}'));
        }

        // 1. Obtener la lista base de trabajos relevantes (Por Pagar o Finalizado)
        final List<Trabajo> trabajosDePago = trabajoProvider.trabajos
            .where(
              (t) =>
                  t.estado == EstadoTrabajo.porPagar ||
                  t.estado == EstadoTrabajo.finalizado,
            )
            .toList();

        // 2. Aplicar el filtro de estado ACTIVO del provider
        final trabajosFiltrados = trabajosDePago.where((t) {
          // El filtro puede ser null, porPagar o finalizado
          final filtroActual = trabajoProvider.filtroEstado;
          if (filtroActual == null ||
              (filtroActual != EstadoTrabajo.porPagar &&
                  filtroActual != EstadoTrabajo.finalizado)) {
            // Si el filtro no es relevante para pagos, mostramos todos
            return true;
          }
          // Si hay un filtro relevante, mostramos solo los que coinciden
          return t.estado == filtroActual;
        }).toList();

        // Ordenar por fecha de fin (más reciente primero)
        final trabajosOrdenados = List<Trabajo>.from(trabajosFiltrados)
          ..sort((a, b) {
            // Usamos fecha de fin de trabajo para ordenar la liquidación
            DateTime valorA = a.fechaFinTrabajo;
            DateTime valorB = b.fechaFinTrabajo;
            return valorB.compareTo(
              valorA,
            ); // Ordenar por fecha de fin (descendente)
          });

        final hayTrabajos = trabajosOrdenados.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controles de Filtro (SOLO CHIPS)
            const _PagosFilterControls(), // Ya no requiere argumento
            // Título de la Lista (Conteo de resultados filtrados)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                'Mostrando ${trabajosOrdenados.length} resultados de pago',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),

            if (!hayTrabajos)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: successColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '¡Excelente! No hay trabajos pendientes de liquidación en este filtro.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Todos los trabajos de este estado han sido liquidados o no existen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
                  itemCount: trabajosOrdenados.length,
                  itemBuilder: (context, index) {
                    final trabajo = trabajosOrdenados[index];
                    return _buildTrabajoPagoCompact(context, trabajo);
                  },
                ),
              ),
          ],
        );
      },
    );
  } // Fin de _buildPagosListBody

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    // Aquí asumimos que el TrabajoProvider nos da la lista filtrada de trabajos
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Liquidación de Pagos',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        // Se mantiene el icono de búsqueda
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: Implementar funcionalidad de búsqueda en Pagos
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Búsqueda de pagos no implementada'),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildPagosListBody(context),
    );
  } // Fin del build principal
} // Fin de _PagosScreenState
