import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/screens/admin_pagos_screen.dart';
import 'package:goodjob_app/src/screens/admin_trabajo_detalle_screen.dart';
import 'package:goodjob_app/src/widgets/trabajo_card.dart';
import '../services/firebase_service.dart';
import '../services/trabajo_service.dart';
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

  Widget _buildCardResumen(String titulo, int cantidad, IconData icono, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icono, size: 36, color: color),
            const SizedBox(height: 8),
            Text(
              '$cantidad',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
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

        final trabajos = snapshot.data!.docs;
        final ahora = DateTime.now();

        final trabajosActivos = trabajos.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final fechaLimite = (data['fechaLimite'] as Timestamp).toDate();
          return fechaLimite.isAfter(ahora);
        }).toList();

        final trabajosCompletados = trabajos.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final fechaLimite = (data['fechaLimite'] as Timestamp).toDate();
          return fechaLimite.isBefore(ahora);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCardResumen(
                      'Trabajos Activos',
                      trabajosActivos.length,
                      Icons.work,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardResumen(
                      'Trabajos Completados',
                      trabajosCompletados.length,
                      Icons.assignment_turned_in,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, 'crear_trabajo'),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Crear nuevo trabajo',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Lista de Trabajos',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const Divider(height: 10),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trabajos.length,
                itemBuilder: (context, index) {
                  final doc = trabajos[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final fechaLimite = (data['fechaLimite'] as Timestamp).toDate();
                  final estado = fechaLimite.isAfter(ahora) ? 'Activo' : 'Cerrado';

                  return FutureBuilder<int>(
                    future: servicio.contarPostulaciones(doc.id),
                    builder: (context, postulacionesSnapshot) {
                      final postulantes = postulacionesSnapshot.data ?? 0;
                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context).colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.cancel, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              title: Text(
                                'Confirmar cancelación',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface),
                              ),
                              content: Text(
                                '¿Estás seguro de que quieres cancelar este trabajo?',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text('No',
                                      style:
                                          Theme.of(context).textTheme.bodyMedium),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text('Sí',
                                      style:
                                          Theme.of(context).textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          servicio.cancelarTrabajo(doc.id).then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trabajo cancelado')),
                            );
                          }).catchError((e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al cancelar: $e')),
                            );
                          });
                        },
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['titulo'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$estado',
                                        style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        // 👇 Lógica de color condicional
                        color: estado == 'Activo'
                            ? const Color.fromARGB(255, 0, 0, 0)
                            : const Color.fromARGB(255, 134, 134, 134), 
                      ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Postulantes: $postulantes',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            '',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w500),
                                          ),
                                          TiempoRestante(fechaLimite: fechaLimite),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Botón de Edición
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AdminTrabajoDetalleScreen(
                                                trabajoId: doc.id,
                                                trabajo: data,
                                              ),
                                            ),
                                          );
                                        },
                                        style: IconButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .onSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Botón de Ver postulantes
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PostulantesTrabajoScreen(
                                                      trabajoId: doc.id),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          'Ver postulantes',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido, Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (mounted) {
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
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Trabajos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Mis pagos'),
        ],
      ),
    );
  }
}