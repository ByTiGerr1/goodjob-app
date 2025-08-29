import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import '../services/trabajo_service.dart';
import 'postulaciones_screen.dart';
import 'detalle_trabajo_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  final Auth auth = Auth();
  final servicio = TrabajoService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
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
          : const PostulacionesScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, 'crear_trabajo'),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _currentIndex = 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.work,
                        color: _currentIndex == 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      Text(
                        'Trabajos publicados',
                        style: TextStyle(
                          color: _currentIndex == 0
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment,
                        color: _currentIndex == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      Text(
                        'Postulaciones',
                        style: TextStyle(
                          color: _currentIndex == 1
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay trabajos'));
        }
        final trabajos = snapshot.data!.docs;
        return ListView.builder(
          itemCount: trabajos.length,
          itemBuilder: (context, index) {
            final doc = trabajos[index];
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['titulo'] ?? ''),
              subtitle: Text(data['descripcion'] ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalleTrabajoScreen(
                      trabajoId: doc.id,
                      trabajo: data,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
