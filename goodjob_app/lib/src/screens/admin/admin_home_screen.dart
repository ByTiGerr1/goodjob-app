import 'admin_pagos_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:goodjob_app/src/services/firebase_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/providers/trabajo_provider.dart';
import 'admin_trabajos_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final Auth auth = Auth();
  final TrabajoService servicio = TrabajoService();

  // Colores de estado
  static const Color _ACTIVE_COLOR = Color(0xFF00897B); // Verde Azulado
  static const Color _CLOSED_COLOR = Color(0xFF9E9E9E); // Gris para completado/cerrado

  // --- WIDGETS DE DASHBOARD ---

  Widget _buildCardResumen(
      BuildContext context, String titulo, int cantidad, IconData icono, Color color) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final colorForIconAndNumber = color;
    
    final usePrimaryForIcon = color == _CLOSED_COLOR;
    final finalColor = usePrimaryForIcon ? primaryColor : colorForIconAndNumber;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icono, size: 36, color: finalColor),
            const SizedBox(height: 8),
            Text(
              '$cantidad',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: finalColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
  
  // --- WIDGETS PARA DASHBOARD DE HOME ---

  Widget _buildDashboardMetrics() {
    return StreamBuilder<QuerySnapshot>(
      stream: servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar los trabajos.'));
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final primaryColor = Theme.of(context).colorScheme.primary;
        final trabajos = snapshot.data!.docs;
        final ahora = DateTime.now();

        // Clasificación de trabajos
        final trabajosConEstado = trabajos.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final sinFechaLimite = data['sinFechaLimite'] == true;
            final fechaLimite = (data['fechaLimite'] as Timestamp?)?.toDate();
            final estado = sinFechaLimite || fechaLimite == null || fechaLimite.isAfter(ahora)
                ? 'Abierto'
                : 'Cerrado';
            return {'estado': estado};
        }).toList();

        final trabajosAbiertos = trabajosConEstado.where((t) => t['estado'] == 'Abierto').toList();
        final trabajosCerrados = trabajosConEstado.where((t) => t['estado'] == 'Cerrado').toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen de Trabajos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildCardResumen(
                      context,
                      'Trabajos Abiertos',
                      trabajosAbiertos.length,
                      Icons.work_history,
                      _ACTIVE_COLOR,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardResumen(
                      context,
                      'Trabajos Cerrados',
                      trabajosCerrados.length,
                      Icons.done_all,
                      primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- BUILD PRINCIPAL DE LA VISTA ---

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    
    return ChangeNotifierProvider(
      create: (_) => TrabajoProvider(servicio),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard de Administración', style: TextStyle(color: Colors.white),),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await auth.logout();
                if (mounted) {
                  // Asumiendo 'login' es la ruta de inicio de sesión
                  Navigator.pushReplacementNamed(context, 'login'); 
                }
              },
            ),
          ],
        ),
        body: _currentIndex == 0
            ? _buildHomeDashboard()
            : _currentIndex == 1
                ? const AdminTrabajosScreen()
                : const AdminPagosScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: secondaryColor,
        unselectedItemColor: Colors.white,
        backgroundColor: Theme.of(context).colorScheme.primary,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Trabajos'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Pagos'),
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
      floatingActionButtonLocation: _currentIndex == 1 
          ? FloatingActionButtonLocation.endFloat 
          : null,
      ),
    );
  }

  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardMetrics(),
          // Aquí puedes agregar más widgets de dashboard en el futuro
        ],
      ),
    );
  }
}