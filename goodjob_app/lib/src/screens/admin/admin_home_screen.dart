import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/screens/admin/detalle_trabajo_admin_screen.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import 'package:intl/intl.dart';

import 'pagos_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:goodjob_app/src/services/firebase_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/providers/trabajo_provider.dart';
import 'package:goodjob_app/src/widgets/logout_confirmation_dialog.dart';
import 'admin_trabajos_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- IMPORTANTE: Asegúrate de tener este import


// Definición de una función de logout para ser pasada al widget
void handleLogout(BuildContext context) async {
  final shouldLogout = await showLogoutConfirmationDialog(context);
  if (!shouldLogout) return;

  await Auth().logout();
  if (!context.mounted) return;

  Navigator.pushReplacementNamed(context, 'login');
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final TrabajoService servicio = TrabajoService();
  final TrabajoService _trabajoService = TrabajoService();
  late final TrabajoProvider _trabajoProvider;

  @override
  void initState() {
    super.initState();
    _trabajoProvider = TrabajoProvider(servicio);
  }

  @override
  void dispose() {
    _trabajoProvider.dispose();
    super.dispose();
  }

  static const Color _ACTIVE_COLOR =
      AppColors.activo; // Verde Azulado para Activo/Abierto
  static const Color _PENDING_PAYMENT_COLOR =
      AppColors.warning; // Ámbar/Naranja para Pago Pendiente

  // --- WIDGET GENÉRICO PARA LISTA DE ACTIVIDAD ---
  Widget _buildActivityList({
    required Stream<QuerySnapshot> stream,
    required Widget Function(QueryDocumentSnapshot doc) tileBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar la actividad.'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'No hay actividad reciente.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            final docs = snapshot.data!.docs;

            // Usamos ListView.separated para añadir divisores
            return ListView.separated(
              itemCount: docs.length,
              shrinkWrap: true, // Importante dentro de un SingleChildScrollView
              physics:
                  const NeverScrollableScrollPhysics(), // Deshabilita scroll anidado
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                return tileBuilder(docs[index]);
              },
            );
          },
        ),
      ],
    );
  }


// --- ⚠️ AÑADIDO: WIDGET PARA ITEM DE TRABAJO TERMINADO ---
  Widget _buildTrabajoTerminadoTile(QueryDocumentSnapshot doc) {
    // Usamos el Modelo Trabajo que ya tienes
    final trabajo = Trabajo.fromFirestore(doc);
    final fecha = trabajo.actualizadoEn; // Esta es la fecha en que se finalizó

    // Formato simple de fecha
    String fechaStr = 'N/A';
    if (fecha != null) {
      fechaStr = DateFormat('dd/MM \'a las\' HH:mm', 'es_ES').format(fecha);
    }

    return ListTile(
      leading: const Icon(Icons.access_time_outlined, color: Color.fromARGB(255, 109, 110, 109)),
      title: Text(
        trabajo.titulo,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        'Finalizado el $fechaStr por trabajador. Actualmente en espera de revisión.',
        style: const TextStyle(fontSize: 13, color: Colors.black54),
      ),
      dense: true,
      onTap: () {
          // Navegación a la vista de edición/detalle
          _navegarADetalle(context, trabajo);
        },
    );
  }

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

  // --- WIDGET: Tarjeta de Métrica Refinada ---
  Widget _buildCardResumenRefinado(
    BuildContext context,
    String titulo,
    int cantidad,
    IconData icono,
    Color color,
    Function() onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título (Aseguramos multilínea y legibilidad)
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Icono
                  Icon(icono, size: 28, color: color.withOpacity(0.9)),
                ],
              ),
              const SizedBox(height: 16),
              // Cantidad
              Text(
                '$cantidad',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              // Indicador de acción
              Row(
                children: [
                  Text(
                    'Ver detalles',
                    style: TextStyle(
                      fontSize: 13,
                      color: color.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: color.withOpacity(0.8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: Encabezado de Bienvenida (Sin cambios) ---

  Widget _buildHomeHeader(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 24),
      decoration: BoxDecoration(
        color: primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panel de Administración',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Hola, Administrador 👋',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 28),
            onPressed: () => handleLogout(context),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Métricas de Dashboard (Lógica y Texto Actualizados) ---

  Widget _buildDashboardMetrics() {
    return StreamBuilder<QuerySnapshot>(
      stream: servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 50),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar los trabajos.'));
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final trabajos = snapshot.data!.docs;
        final ahora = DateTime.now();

        final trabajosConEstado = trabajos.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sinFechaLimite = data['sinFechaLimite'] == true;
          final fechaLimite = (data['fechaLimite'] as Timestamp?)?.toDate();
          final estado =
              sinFechaLimite ||
                  fechaLimite == null ||
                  fechaLimite.isAfter(ahora)
              ? 'Abierto'
              : 'porPagar'; // REEMPLAZADO 'Cerrado' por 'PorPagar'
          return {'estado': estado};
        }).toList();

        final trabajosAbiertos = trabajosConEstado
            .where((t) => t['estado'] == 'Abierto')
            .toList();
        final trabajosPorPagar = trabajosConEstado
            .where((t) => t['estado'] == 'porPagar')
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen de Empleos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCardResumenRefinado(
                      context,
                      'Trabajos Abiertos',
                      trabajosAbiertos.length,
                      Icons.work_history_outlined,
                      _ACTIVE_COLOR,
                      () => setState(() => _currentIndex = 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardResumenRefinado(
                      context,
                      'Trabajos por Pagar', // ¡NUEVO TEXTO!
                      trabajosPorPagar.length,
                      Icons.payment, // Nuevo icono relacionado con pago
                      _PENDING_PAYMENT_COLOR, // ¡NUEVO COLOR!
                      () => setState(
                        () => _currentIndex = 2,
                      ), // Navega a la pestaña de PAGOS (índice 2)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 16),
              Text(
                'Actividad Reciente',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
              Column(
                children: [
                  _buildActivityList(
                    stream: _trabajoService.obtenerTrabajosTerminadosRecientes(limite: 5), // Límite de 5
                    tileBuilder: _buildTrabajoTerminadoTile, // Usamos el nuevo Tile
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET: Home Dashboard Principal (Sin cambios) ---

  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildHomeHeader(context), _buildDashboardMetrics()],
      ),
    );
  }

  // --- BUILD PRINCIPAL DE LA VISTA (Sin cambios) ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return ChangeNotifierProvider<TrabajoProvider>.value(
      value: _trabajoProvider,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeDashboard(),
            const AdminTrabajosScreen(),
            const PagosScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: secondaryColor,
          unselectedItemColor: Colors.white70,
          backgroundColor: primaryColor,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              label: 'Trabajos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Pagos',
            ),
          ],
        ),
        floatingActionButton: _currentIndex == 1
            ? FloatingActionButton(
                heroTag: 'createJobFAB',
                backgroundColor: secondaryColor,
                onPressed: () => Navigator.pushNamed(context, 'crear_trabajo'),
                child: const Icon(Icons.add, color: Colors.black, size: 30),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
