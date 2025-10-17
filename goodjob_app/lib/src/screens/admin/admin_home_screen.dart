import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../services/trabajo_service.dart';
import '../../services/postulacion_service.dart'; // Importamos el servicio de postulacion
import 'admin_pagos_screen.dart';
import 'admin_trabajo_detalle_screen.dart';
import 'postulantes_trabajo_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final Auth auth = Auth();
  final TrabajoService servicio = TrabajoService();
  final PostulacionService postulacionService = PostulacionService(); // Instanciamos el servicio

  // Colores de estado
  static const Color _ACTIVE_COLOR = Color(0xFF00897B); // Verde Azulado
  static const Color _CLOSED_COLOR = Color(0xFF9E9E9E); // Gris para completado/cerrado

  // --- WIDGETS DE DASHBOARD ---

  Widget _buildCardResumen(
      BuildContext context, String titulo, int cantidad, IconData icono, Color color) {
    final colorForIconAndNumber = color;
    
    final usePrimaryForIcon = color == _CLOSED_COLOR;
    final finalColor = usePrimaryForIcon ? Theme.of(context).colorScheme.primary : colorForIconAndNumber;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white, // Fondo blanco para todas las tarjetas
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

  // Widget para mostrar la tarjeta de gestión, usando FutureBuilder para la cuenta de postulantes
  Widget _buildTrabajoGestionCard(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> data, String estado) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final esActivo = estado == 'Activo';
    final estadoColor = esActivo ? _ACTIVE_COLOR : _CLOSED_COLOR;
    final estadoTexto = esActivo ? 'Activo' : 'Cerrado';
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminTrabajoDetalleScreen(
                trabajoId: doc.id,
                trabajo: data,
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
                          data['titulo'] ?? 'Trabajo sin título',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        // Chip de Estado
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: estadoColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(estadoTexto,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold, color: estadoColor))),
                      ],
                    ),
                  ),
                  
                  // Cantidad de Postulantes (Usando FutureBuilder)
                  FutureBuilder<int>(
                    future: postulacionService.contarPostulaciones(doc.id),
                    builder: (context, snapshot) {
                      final postulantes = snapshot.data ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (snapshot.connectionState == ConnectionState.waiting)
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                            )
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminTrabajoDetalleScreen(trabajoId: doc.id, trabajo: data)));
                    },
                  ),
                  const SizedBox(width: 8),
                  // Botón principal: Ver postulantes
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostulantesTrabajoScreen(trabajoId: doc.id),
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
    return StreamBuilder<QuerySnapshot>(
      stream: servicio.obtenerTrabajos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar los trabajos.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay trabajos publicados.'));
        }

        final primaryColor = Theme.of(context).colorScheme.primary;
        final secondaryColor = Theme.of(context).colorScheme.secondary;
        
        final trabajos = snapshot.data!.docs;
        final ahora = DateTime.now();

        final trabajosActivos = trabajos.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final fechaLimite = (data['fechaLimite'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 1)); 
          return fechaLimite.isAfter(ahora);
        }).toList();

        final trabajosCompletados = trabajos.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final fechaLimite = (data['fechaLimite'] as Timestamp?)?.toDate() ?? DateTime.now().subtract(const Duration(days: 1)); 
          return fechaLimite.isBefore(ahora);
        }).toList();
        
        // Finalizamos la remoción de la variable dummy

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard de Métricas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCardResumen(
                      context,
                      'Trabajos Activos',
                      trabajosActivos.length,
                      Icons.work_history,
                      _ACTIVE_COLOR, // Verde Azulado
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardResumen(
                      context,
                      'Trabajos Cerrados',
                      trabajosCompletados.length,
                      Icons.done_all,
                      primaryColor, // Usamos Primary para Cerrados
                    ),
                  ),
                ],
              ),
            ),
            
            // CTA Principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, 'crear_trabajo'),
                  icon: const Icon(Icons.add_circle, color: Colors.black),
                  label: const Text(
                    'Crear Nuevo Trabajo',
                    style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor, // CTA en color de acento (Amarillo)
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                ),
              ),
            ),
            
            // Título de la Lista
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Todas las ofertas (${trabajos.length})',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),

            // Lista de Trabajos 
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: trabajos.length,
                itemBuilder: (context, index) {
                  final doc = trabajos[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final fechaLimite = (data['fechaLimite'] as Timestamp?)?.toDate() ?? DateTime.now().subtract(const Duration(days: 1));
                  final estado = fechaLimite.isAfter(ahora) ? 'Activo' : 'Cerrado';
                  
                  // Pasamos el documento y datos al nuevo widget constructor
                  return _buildTrabajoGestionCard(context, doc, data, estado);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- BUILD PRINCIPAL DE LA VISTA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          ? _buildTrabajosPublicados()
          : const AdminPagosScreen(), // Asegúrate que esta vista existe
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.secondary, // Amarillo Brillante
        unselectedItemColor: Colors.white, // Blanco para no seleccionados
        backgroundColor: Theme.of(context).colorScheme.primary, // Morado
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Trabajos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Pagos'),
        ],
      ),
    );
  }
}
