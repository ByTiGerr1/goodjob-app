import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/services/firebase_service.dart';
import 'package:goodjob_app/src/services/postulacion_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'admin_pagos_screen.dart';
import 'postulantes_trabajo_screen.dart';
import 'admin_trabajo_router.dart';

// Opciones de filtrado para la lista
enum TrabajoFilter { all, active, closed }

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final Auth auth = Auth();
  final TrabajoService servicio = TrabajoService();
  final PostulacionService postulacionService = PostulacionService();

  // Variable de estado para el filtro
  TrabajoFilter _selectedFilter = TrabajoFilter.active;

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
  
  // --- WIDGETS DE FILTRO ---

  Widget _buildFilterControls(BuildContext context, int totalCount) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final filterOptions = [
      {'enum': TrabajoFilter.active, 'text': 'Activos'},
      {'enum': TrabajoFilter.closed, 'text': 'Cerrados'},
      {'enum': TrabajoFilter.all, 'text': 'Todos ($totalCount)'},
    ];

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 8.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: filterOptions.map((option) {
            final isSelected = _selectedFilter == option['enum'];
            final color = isSelected ? primaryColor : Colors.transparent;
            final textColor = isSelected ? Colors.white : Colors.black87;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedFilter = option['enum'] as TrabajoFilter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      option['text'] as String,
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
    );
  }

  // --- WIDGETS DE LISTA ---

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
              builder: (_) => getAdminTrabajoView(
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
                          if (postulacionesSnapshot.connectionState == ConnectionState.waiting)
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => getAdminTrabajoView(trabajoId: doc.id, trabajo: data)));
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

        // 1. Clasificación
        final trabajosConEstado = trabajos.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fechaLimite = (data['fechaLimite'] as Timestamp?)?.toDate() ?? DateTime.now().subtract(const Duration(days: 1));
            final estado = fechaLimite.isAfter(ahora) ? 'Activo' : 'Cerrado';
            return {'doc': doc, 'data': data, 'estado': estado, 'id': doc.id};
        }).toList();

        final trabajosActivos = trabajosConEstado.where((t) => t['estado'] == 'Activo').toList();
        final trabajosCerrados = trabajosConEstado.where((t) => t['estado'] == 'Cerrado').toList();
        
        // 2. Aplicar filtro de estado
        List<Map<String, dynamic>> trabajosFiltrados;
        switch (_selectedFilter) {
          case TrabajoFilter.active:
            trabajosFiltrados = trabajosActivos;
            break;
          case TrabajoFilter.closed:
            trabajosFiltrados = trabajosCerrados;
            break;
          case TrabajoFilter.all:
          default:
            trabajosFiltrados = [...trabajosActivos, ...trabajosCerrados];
            break;
        }
        
        // 3. Ordenar
        trabajosFiltrados.sort((a, b) {
            // Actualmente solo ordena por fecha de creación descendente (más reciente primero)
            final aTime = (a['data']!['creadoEn'] as Timestamp?)?.toDate();
            final bTime = (b['data']!['creadoEn'] as Timestamp?)?.toDate();
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); 
        });

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
            ),
            
            // Controles de Filtro
            _buildFilterControls(context, trabajos.length),
            
            // Título de la Lista
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Resultados: (${trabajosFiltrados.length})',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),

            // Lista de Trabajos Filtrada
            Expanded(
              child: ListView.builder(
                // Padding inferior aumentado para no tapar por el FAB
                padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 80.0), 
                itemCount: trabajosFiltrados.length,
                itemBuilder: (context, index) {
                  final item = trabajosFiltrados[index];
                  final doc = item['doc'] as DocumentSnapshot;
                  final data = item['data'] as Map<String, dynamic>;
                  final estado = item['estado'] as String;
                  
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
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    
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
          : const AdminPagosScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: secondaryColor,
        unselectedItemColor: Colors.white,
        backgroundColor: Theme.of(context).colorScheme.primary,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Trabajos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Pagos'),
        ],
      ),
      
      // ✅ IMPLEMENTACIÓN DEL BOTÓN FLOTANTE
      floatingActionButton: FloatingActionButton(
        heroTag: 'createJobFAB',
        backgroundColor: secondaryColor,
        onPressed: () => Navigator.pushNamed(context, 'crear_trabajo'),
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
      // El FAB debe estar visible solo en la pestaña de Trabajos
      floatingActionButtonLocation: _currentIndex == 0 
          ? FloatingActionButtonLocation.endFloat 
          : null,
    );
  }
}