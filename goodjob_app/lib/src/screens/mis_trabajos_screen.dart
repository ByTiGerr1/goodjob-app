import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_trabajo_screen.dart';
import '../services/firebase_service.dart';
import '../services/postulacion_service.dart';

class MisTrabajosScreen extends StatefulWidget {
  const MisTrabajosScreen({super.key});

  @override
  State<MisTrabajosScreen> createState() => _MisTrabajosScreenState();
}

class _MisTrabajosScreenState extends State<MisTrabajosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'aceptado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      case 'confirmado':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _iconEstado(String estado) {
    switch (estado) {
      case 'aceptado':
        return Icons.check_circle_outline;
      case 'rechazado':
        return Icons.cancel_outlined;
      case 'confirmado':
        return Icons.task_alt_outlined;
      default:
        return Icons.pending_outlined;
    }
  }

  void _mostrarNotificacion(
      BuildContext context, String titulo, String estado) {
    final mensaje = estado == 'aceptado'
        ? 'Tu postulación a "$titulo" fue aceptada'
        : 'Tu postulación a "$titulo" fue rechazada';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/D';
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    final year = fecha.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _actualizarEstadoPostulacion(
      String postId, String nuevoEstado) async {
    try {
      await FirebaseFirestore.instance
          .collection('postulaciones')
          .doc(postId)
          .update({'estado': nuevoEstado});
    } catch (e) {
      print('Error al actualizar estado de la postulación: $e');
    }
  }

  Widget _buildConfirmedCard(
      BuildContext context, QueryDocumentSnapshot postulacionDoc) {
    final postulacionData = postulacionDoc.data() as Map<String, dynamic>;
    final trabajoId = postulacionData['trabajoId'];

    if (trabajoId == null) {
      return const SizedBox.shrink();
    }
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('trabajos')
          .doc(trabajoId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text('Cargando detalles del trabajo...'),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final trabajoData = snapshot.data!.data() as Map<String, dynamic>;
        final titulo = postulacionData['trabajoTitulo'] ?? '';
        final precio = trabajoData['precio']?.toString() ?? 'N/D';
        final estado = postulacionData['estado'] ?? 'pendiente';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  estado.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _colorEstado(estado),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pago: \$$precio',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetalleTrabajoScreen(
                            trabajoId: trabajoId,
                            trabajo: trabajoData,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Ver más'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingCard(BuildContext context, QueryDocumentSnapshot postulacionDoc) {
    final postulacionData = postulacionDoc.data() as Map<String, dynamic>;
    final trabajoId = postulacionData['trabajoId'];

    if (trabajoId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('trabajos')
          .doc(trabajoId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text('Cargando detalles del trabajo...'),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final trabajoData = snapshot.data!.data() as Map<String, dynamic>;
        final titulo = postulacionData['trabajoTitulo'] ?? '';
        final estado = postulacionData['estado'] ?? 'pendiente';
        final fechaTrabajoTs = trabajoData['fechaTrabajo'] as Timestamp?;
        final fechaTrabajo = fechaTrabajoTs?.toDate();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha: ${_formatFecha(fechaTrabajo)}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (estado == 'aceptado')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await _actualizarEstadoPostulacion(
                              postulacionDoc.id, 'confirmado');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirmar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          await _actualizarEstadoPostulacion(
                              postulacionDoc.id, 'rechazado');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        _iconEstado(estado),
                        color: _colorEstado(estado),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        estado.toUpperCase(),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _colorEstado(estado)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostulacionList(List<QueryDocumentSnapshot> postulaciones, bool? isConfirmedTab) {
    if (postulaciones.isEmpty) {
      return const Center(child: Text('No hay postulaciones en esta categoría.'));
    }

    return ListView.builder(
      itemCount: postulaciones.length,
      itemBuilder: (context, index) {
        final post = postulaciones[index];
        final data = post.data() as Map<String, dynamic>;
        final estado = data['estado'] ?? '';

        if (isConfirmedTab == true) {
          return _buildConfirmedCard(context, post);
        } else if (isConfirmedTab == false) {
          return _buildPendingCard(context, post);
        } else { // 'Todos' tab
          if (estado == 'aceptado' || estado == 'confirmado') {
            return _buildConfirmedCard(context, post);
          } else {
            return _buildPendingCard(context, post);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Auth();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('JOBS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Confirmados'),
            Tab(text: 'Pendientes'),
            Tab(text: 'Todos'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: PostulacionService().obtenerPostulacionesDeUsuario(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is FirebaseException &&
                error.code == 'failed-precondition') {
              return const Center(
                  child: Text('Preparando índices, intenta más tarde'));
            }
            return const Center(
                child: Text('Error al cargar las postulaciones'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data != null) {
            for (final cambio in snapshot.data!.docChanges) {
              if (cambio.type == DocumentChangeType.modified) {
                final data = cambio.doc.data() as Map<String, dynamic>? ?? {};
                final estado = data['estado'];
                if (estado == 'aceptado' || estado == 'rechazado') {
                  final titulo = data['trabajoTitulo'] ?? '';
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _mostrarNotificacion(context, titulo, estado);
                  });
                }
              }
            }
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay postulaciones.'));
          }
          final postulaciones = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['creadoEn'] as Timestamp?;
              final bTime = bData['creadoEn'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
          
          final confirmados = postulaciones
              .where(
                  (p) => (p.data() as Map<String, dynamic>)['estado'] == 'aceptado')
              .toList();
          final noAceptados = postulaciones
              .where(
                  (p) => (p.data() as Map<String, dynamic>)['estado'] != 'aceptado')
              .toList();
          final todos = postulaciones;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPostulacionList(confirmados, true),
              _buildPostulacionList(noAceptados, false),
              _buildPostulacionList(todos, null),
            ],
          );
        },
      ),
    );
  }
}
