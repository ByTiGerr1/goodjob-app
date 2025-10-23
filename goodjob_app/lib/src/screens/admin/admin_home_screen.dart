import 'package:goodjob_app/theme/app_colors.dart';

import 'pagos_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/providers/trabajo_provider.dart';
import 'admin_trabajos_screen.dart';

// Definición de una función de logout para ser pasada al widget
void handleLogout(BuildContext context) async {
  // Aquí iría tu lógica real de cierre de sesión
  await Future.delayed(const Duration(milliseconds: 100));
  if (context.mounted) {
    Navigator.pushReplacementNamed(context, 'login');
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final TrabajoService servicio = TrabajoService(); 
  

  static const Color _ACTIVE_COLOR = AppColors.activo; // Verde Azulado para Activo/Abierto
  static const Color _PENDING_PAYMENT_COLOR = AppColors.warning; // Ámbar/Naranja para Pago Pendiente

  // --- WIDGET: Tarjeta de Métrica Refinada ---

  Widget _buildCardResumenRefinado(
      BuildContext context, 
      String titulo, 
      int cantidad, 
      IconData icono, 
      Color color, 
      Function() onTap) {
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 3, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
              )
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
                  fontWeight: FontWeight.w400
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
          return const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: CircularProgressIndicator()));
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
            final estado = sinFechaLimite || fechaLimite == null || fechaLimite.isAfter(ahora)
                ? 'Abierto'
                : 'porPagar'; // REEMPLAZADO 'Cerrado' por 'PorPagar'
            return {'estado': estado};
        }).toList();

        final trabajosAbiertos = trabajosConEstado.where((t) => t['estado'] == 'Abierto').toList();
        final trabajosPorPagar = trabajosConEstado.where((t) => t['estado'] == 'porPagar').toList();


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
                      () => setState(() => _currentIndex = 2), // Navega a la pestaña de PAGOS (índice 2)
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
              const SizedBox(height: 8),
              const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Últimas postulaciones y pagos aquí...', style: TextStyle(color: Colors.black54)),
              )),
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
        children: [
          _buildHomeHeader(context),
          _buildDashboardMetrics(), 
        ],
      ),
    );
  }

  // --- BUILD PRINCIPAL DE LA VISTA (Sin cambios) ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;
    
    return ChangeNotifierProvider(
      create: (_) => TrabajoProvider(servicio),
      child: Scaffold(
        
        body: IndexedStack( 
          index: _currentIndex,
          children: [
            _buildHomeDashboard(), 
              AdminTrabajosScreen(),
              PagosScreen(),
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
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Trabajos'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Pagos'),
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