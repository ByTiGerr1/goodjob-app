import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/postulacion_service.dart';
import '../services/user_eligibility_service.dart';
import '../widgets/user_eligibility_gate.dart';
import '../widgets/verification_required_view.dart';
import 'auth/account_verification_screen.dart';
import 'auth/login_screen.dart';
import 'seguimiento_postulacion_screen.dart';

// Definición de colores de estado centralizados (CONFIRMADO actualizado a Verde Azulado)
const Color _COLOR_ACEPTADO = AppColors.success; // Verde (Aceptado por Admin)
const Color _COLOR_RECHAZADO = AppColors.rejectColor; // Rojo (Rechazado)
const Color _COLOR_CONFIRMADO = AppColors.confirmadoPorUsuario;
const Color _COLOR_PENDIENTE = AppColors.pendingColor;

class MisTrabajosScreen extends StatefulWidget {
  const MisTrabajosScreen({super.key});

  @override
  State<MisTrabajosScreen> createState() => _MisTrabajosScreenState();
}

class _MisTrabajosScreenState extends State<MisTrabajosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Auth _authService = Auth();
  final PostulacionService _postulacionService = PostulacionService();

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

  // --- Funciones de Utilidad de Estado ---

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'aceptado':
        return _COLOR_ACEPTADO;
      case 'rechazado':
        return _COLOR_RECHAZADO;
      case 'confirmado':
        return _COLOR_CONFIRMADO;
      default:
        return _COLOR_PENDIENTE;
    }
  }

  IconData _iconEstado(String estado) {
    switch (estado) {
      case 'aceptado':
        return Icons.verified_user_outlined; // Verde
      case 'rechazado':
        return Icons.cancel_outlined; // Rojo
      case 'confirmado':
        return Icons.task_alt; // Verde Azulado
      default:
        return Icons.access_time_filled; // Púrpura
    }
  }

  String _estadoDisplay(String estado) {
    switch (estado) {
      case 'aceptado':
        return 'Aceptado';
      case 'rechazado':
        return 'Rechazado';
      case 'confirmado':
        return 'Confirmado';
      case 'pendiente_revision':
        return 'Pendiente de Revisión';
      case 'pendiente':
      default:
        final normalized = estado.replaceAll('_', ' ').trim();
        if (normalized.isEmpty) return 'Pendiente';
        return normalized[0].toUpperCase() + normalized.substring(1);
    }
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/D';
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    final year = fecha.year.toString();
    return '$day/$month/$year';
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _obtenerFechaTrabajo(
    Map<String, dynamic> trabajoData,
    Map<String, dynamic> postulacionData,
  ) {
    return _parseDate(trabajoData['fechaTrabajo']) ??
        _parseDate(trabajoData['fechaInicioTrabajo']) ??
        _parseDate(trabajoData['fechaFinTrabajo']) ??
        _parseDate(postulacionData['fechaTrabajo']) ??
        _parseDate(postulacionData['fechaAceptacion']);
  }

  // --- Lógica de Acciones ---

  Future<void> _actualizarEstadoPostulacion(
    String trabajoId,
    String nuevoEstado, {
    String? trabajoTitulo,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Usuario no autenticado.')));
      return;
    }

    try {
      await _postulacionService.actualizarEstado(
        trabajoId: trabajoId,
        postulanteId: uid,
        nuevoEstado: nuevoEstado,
        trabajoTitulo: trabajoTitulo,
        limitarAUsuario: true,
      );
      if (!mounted) return;
      final estadoNormalizado = nuevoEstado.toLowerCase();
      final mensaje = estadoNormalizado == 'confirmado'
          ? '¡Trabajo confirmado! ¡Prepárate!'
          : estadoNormalizado == 'rechazado'
          ? 'Postulación rechazada con éxito.'
          : 'Estado de postulación actualizado.';
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar la postulación.')),
      );
    }
  }

  // --- Widgets de Tarjeta Unificados ---

  Widget _buildJobCard(
    BuildContext context,
    QueryDocumentSnapshot postulacionDoc,
  ) {
    final postulacionData = postulacionDoc.data() as Map<String, dynamic>;
    final trabajoId = postulacionData['trabajoId'];

    if (trabajoId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('trabajos')
          .doc(trabajoId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final trabajoData = snapshot.data!.data() as Map<String, dynamic>;
        final titulo =
            postulacionData['trabajoTitulo'] ??
            trabajoData['titulo'] ??
            'Título no disponible';
        final empresa = trabajoData['empresa'] ?? 'Empresa N/D';
        final dynamic precioNumerico = trabajoData['precio'];

        final precio = (precioNumerico != null)
            ? FormatUtils.formatCurrency(precioNumerico.toDouble())
            : 'N/D';

        final estadoRaw = postulacionData['estado']?.toString() ?? 'pendiente';
        final estado = estadoRaw.toLowerCase();

        final fechaTrabajo = _obtenerFechaTrabajo(trabajoData, postulacionData);

        final fechaPostulacionTs =
            postulacionData['fechaPostulacion'] as Timestamp?;
        final fechaPostulacion = fechaPostulacionTs?.toDate();

        if (estado == 'confirmado' &&
            fechaTrabajo != null &&
            DateTime.now().isAfter(fechaTrabajo.add(const Duration(days: 1)))) {
          return const SizedBox.shrink();
        }

        Widget subtitleContent;
        Widget actionButtons = const SizedBox.shrink();

        if (estado == 'confirmado') {
          subtitleContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha: ${_formatFecha(fechaTrabajo)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              // Color de pago ahora es Verde Azulado
              Text(
                'Pago: $precio',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _COLOR_CONFIRMADO,
                ),
              ),
            ],
          );
          actionButtons = ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SeguimientoPostulacionScreen(
                    trabajoId: trabajoId,
                    trabajo: trabajoData,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Ver Detalles'),
          );
        } else if (estado == 'aceptado') {
          // Si está aceptado, forzamos la acción de Confirmar/Rechazar
          subtitleContent = Text(
            '¡Seleccionado! Pendiente de tu confirmación.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _COLOR_ACEPTADO,
            ),
          );

          actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => _actualizarEstadoPostulacion(
                  trabajoId,
                  'confirmado',
                  trabajoTitulo: titulo,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _COLOR_ACEPTADO,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _actualizarEstadoPostulacion(
                  trabajoId,
                  'rechazado',
                  trabajoTitulo: titulo,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _COLOR_RECHAZADO,
                  side: BorderSide(color: _COLOR_RECHAZADO),
                ),
                child: const Text('Rechazar'),
              ),
            ],
          );
        } else {
          // Pendiente, Rechazado
          subtitleContent = Text(
            'Postulado el ${_formatFecha(fechaPostulacion)}',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          );
          actionButtons = const SizedBox.shrink(); // No hay acción directa
        }

        // --- Layout de la Tarjeta ---
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            empresa,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Etiqueta de Estado (Chip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _colorEstado(estado).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconEstado(estado),
                            size: 16,
                            color: _colorEstado(estado),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _estadoDisplay(estado),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _colorEstado(estado),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                subtitleContent,
                const SizedBox(height: 12),

                Align(alignment: Alignment.centerRight, child: actionButtons),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Cargando detalles del trabajo...'),
          ],
        ),
      ),
    );
  }

  // --- Widgets de Lista y Cuerpo ---

  Widget _buildPostulacionList(List<QueryDocumentSnapshot> postulaciones) {
    if (postulaciones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No tienes trabajos o postulaciones en esta categoría. ¡Es momento de buscar nuevas oportunidades!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: postulaciones.length,
      itemBuilder: (context, index) {
        return _buildJobCard(context, postulaciones[index]);
      },
    );
  }

  Widget _buildPostulacionesBody(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _postulacionService.obtenerPostulacionesDeUsuario(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is FirebaseException &&
              error.code == 'failed-precondition') {
            return const Center(
              child: Text('Preparando índices, intenta más tarde'),
            );
          }
          return const Center(child: Text('Error al cargar las postulaciones'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aún no tienes postulaciones.'));
        }

        final postulaciones = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['fechaPostulacion'] as Timestamp?;
            final bTime = bData['fechaPostulacion'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

        final confirmados = postulaciones
            .where(
              (p) =>
                  (p.data() as Map<String, dynamic>)['estado']?.toLowerCase() ==
                  'confirmado',
            )
            .toList();

        final pendientes = postulaciones.where((p) {
          final estado = (p.data() as Map<String, dynamic>)['estado']
              ?.toLowerCase();
          return estado == 'pendiente' || estado == 'aceptado';
        }).toList();

        final todos = postulaciones;

        return TabBarView(
          controller: _tabController,
          children: [
            _buildPostulacionList(confirmados),
            _buildPostulacionList(pendientes),
            _buildPostulacionList(todos),
          ],
        );
      },
    );
  }

  // --- Lógica de Navegación/Elegibilidad ---

  void _navigateAndRefresh(
    BuildContext context,
    Widget screen,
    Future<void> Function() refresh,
  ) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      if (!mounted) return;
      refresh();
    });
  }

  Widget _buildEligibilityNotice(
    BuildContext context,
    UserEligibilityStatus status,
    Future<void> Function() refresh,
  ) {
    final authenticated = status.isAuthenticated;
    final description = status.messageForAction('visualizar tus postulaciones');
    final primaryLabel = authenticated ? 'Terminar registro' : 'Iniciar sesión';

    return VerificationRequiredView(
      title: 'Termina tu registro',
      description: description,
      primaryButtonLabel: primaryLabel,
      onPrimaryPressed: () {
        if (authenticated) {
          _navigateAndRefresh(
            context,
            const AccountVerificationScreen(),
            refresh,
          );
        } else {
          _navigateAndRefresh(context, const LoginScreen(), refresh);
        }
      },
      secondaryButtonLabel: authenticated ? 'Ya completé mi registro' : null,
      onSecondaryPressed: authenticated ? () => refresh() : null,
    );
  }

  // --- Build Principal ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Trabajos'),
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, color: Colors.white70),
          tabs: const [
            Tab(text: 'Confirmados'),
            Tab(text: 'Pendientes'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: UserEligibilityGate(
        eligibleBuilder: (context, status, refresh) {
          final uid = status.userId ?? _authService.currentUser?.uid;
          if (uid == null) {
            return const Center(
              child: Text('No se pudo obtener tu sesión actual.'),
            );
          }
          return _buildPostulacionesBody(uid);
        },
        blockedBuilder: _buildEligibilityNotice,
      ),
    );
  }
}
