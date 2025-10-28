import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/postulacion_service.dart';
import '../services/storage_service.dart';
import '../services/user_eligibility_service.dart';
import '../utils/format_utils.dart';
import '../widgets/user_eligibility_gate.dart';
import '../widgets/verification_required_view.dart';
import 'auth/account_verification_screen.dart';
import 'auth/login_screen.dart';

class MisPagosScreen extends StatefulWidget {
  const MisPagosScreen({super.key});

  @override
  State<MisPagosScreen> createState() => _MisPagosScreenState();
}

class _MisPagosScreenState extends State<MisPagosScreen> {
  final PostulacionService _postulacionService = PostulacionService();
  final StorageService _storageService = StorageService();

  String _normalizeStatus(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    }
    return '';
  }

  bool _isCompletedPostulation(Map<String, dynamic> data) {
    final estadoTrabajo = _normalizeStatus(data['estadoTrabajo'] ?? data['estado']);
    final estadoPago = _normalizeStatus(data['estadoPago']);
    final trabajoCompletado = data['trabajoCompletado'] == true;

    if (trabajoCompletado) return true;

    const estadosTrabajoFinales = {
      'finalizado',
      'pagado',
      'rechazado',
      'completado',
      'terminado',
      'cerrado',
    };

    const estadosPagoFinales = {
      'pagado',
      'completado',
      'rechazado',
    };

    if (estadosTrabajoFinales.contains(estadoTrabajo)) {
      return true;
    }

    if (estadosPagoFinales.contains(estadoPago)) {
      return true;
    }

    return false;
  } 

  Widget _buildEmptyCompletedJobs() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_history_rounded,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes trabajos completados.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando finalices un trabajo y el equipo de GoodJob procese tu pago, podrás consultar todos los detalles en esta sección.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedJobsList(List<QueryDocumentSnapshot> documentos) {
    if (documentos.isEmpty) {
      return _buildEmptyCompletedJobs();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      itemCount: documentos.length,
      itemBuilder: (context, index) {
        return _CompletedJobCard(
          postulacionDoc: documentos[index],
          storageService: _storageService,
        );
      },
    );
  }

  void _navigateAndRefresh(
    BuildContext context,
    Widget screen,
    Future<void> Function() refresh,
  ) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
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
    final description = status.messageForAction('consultar tus pagos');
    final primaryLabel =
        authenticated ? 'Terminar registro' : 'Iniciar sesión';

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
          _navigateAndRefresh(
            context,
            const LoginScreen(),
            refresh,
          );
        }
      },
      secondaryButtonLabel:
          authenticated ? 'Ya completé mi registro' : null,
      onSecondaryPressed: authenticated ? () => refresh() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: UserEligibilityGate(
        eligibleBuilder: (context, status, refresh) {
          final uid = status.userId;

          if (uid == null) {
            return const Center(
              child: Text('No pudimos identificar tu cuenta. Intenta nuevamente.'),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _postulacionService.obtenerPostulacionesDeUsuario(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No pudimos cargar tus trabajos completados. Intenta nuevamente más tarde.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final documentos = snapshot.data?.docs ?? [];

              final completados = documentos.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _isCompletedPostulation(data);
              }).toList()
                ..sort((a, b) {
                  DateTime? finA;
                  DateTime? finB;
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  finA = _readDate(dataA['finTrabajoReal']) ??
                      _readDate(dataA['finTrabajoLocal']) ??
                      _readDate(dataA['fechaAceptacion']);
                  finB = _readDate(dataB['finTrabajoReal']) ??
                      _readDate(dataB['finTrabajoLocal']) ??
                      _readDate(dataB['fechaAceptacion']);

                  if (finA == null && finB == null) return 0;
                  if (finA == null) return 1;
                  if (finB == null) return -1;
                  return finB.compareTo(finA);
                });

              return _buildCompletedJobsList(completados);
            },
          );
        },
        blockedBuilder: _buildEligibilityNotice,
      ),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}


class _CompletedJobCard extends StatelessWidget {
  const _CompletedJobCard({
    required this.postulacionDoc,
    required this.storageService,
  });

  final QueryDocumentSnapshot postulacionDoc;
  final StorageService storageService;

  Map<String, dynamic> get _postulacionData =>
      postulacionDoc.data() as Map<String, dynamic>;

  String? get _trabajoId => _postulacionData['trabajoId'] as String?;

  @override
  Widget build(BuildContext context) {
    final trabajoId = _trabajoId;
    if (trabajoId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('trabajos')
          .doc(trabajoId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text('Cargando detalles del trabajo...'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final trabajoData = snapshot.data?.data();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            title: _buildTitle(context, trabajoData),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(context, trabajoData),
                  const SizedBox(height: 8),
                  _buildPaymentRow(context, trabajoData),
                ],
              ),
            ),
            children: [
              _buildWorkSummarySection(context, trabajoData),
              const SizedBox(height: 16),
              _buildEvidencesSection(context, trabajoData),
              const SizedBox(height: 16),
              _buildResolutionSection(context, trabajoData),
              const SizedBox(height: 16),
              _buildPaymentSection(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context, Map<String, dynamic>? trabajoData) {
    final titulo = _postulacionData['trabajoTitulo'] ??
        trabajoData?['titulo'] ??
        'Trabajo sin título';
    final empresa = trabajoData?['empresa'] ?? 'Empresa no especificada';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          empresa,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    Map<String, dynamic>? trabajoData,
  ) {
    final estadoTrabajo = _normalizeStatus(
      _postulacionData['estadoTrabajo'] ??
          trabajoData?['estadoTrabajo'] ??
          trabajoData?['estado'] ??
          _postulacionData['estado'],
    );

    final estadoLabel = _statusLabel(estadoTrabajo);
    final estadoColor = _statusColor(estadoTrabajo, context);

    final finTrabajo = _readDate(_postulacionData['finTrabajoReal']) ??
        _readDate(_postulacionData['finTrabajoLocal']);

    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(
            estadoLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          avatar: Icon(
            _statusIcon(estadoTrabajo),
            color: estadoColor,
          ),
          backgroundColor: estadoColor.withOpacity(0.12),
          labelStyle: TextStyle(color: estadoColor),
          side: BorderSide(color: estadoColor.withOpacity(0.2)),
        ),
        if (finTrabajo != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available_outlined, size: 16),
              const SizedBox(width: 4),
              Text(
                'Finalizado el ${FormatUtils.formatDate(finTrabajo)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPaymentRow(
    BuildContext context,
    Map<String, dynamic>? trabajoData,
  ) {
    final dynamic montoRaw = trabajoData?['precio'] ?? _postulacionData['monto'];
    final monto = (montoRaw is num)
        ? FormatUtils.formatCurrency(montoRaw.toDouble())
        : null;

    final estadoPago = _normalizeStatus(
      _postulacionData['estadoPago'] ?? trabajoData?['estadoPago'],
    );

    final pagoLabel = _paymentLabel(estadoPago);
    final pagoColor = _paymentColor(estadoPago, context);

    final pagoConfirmadoEn = _readDate(
          _postulacionData['pagoConfirmadoEn'],
        ) ??
        _readDate(trabajoData?['pagoConfirmadoEn']);
    final pagoActualizadoEn = _readDate(
          _postulacionData['estadoPagoActualizadoEn'],
        ) ??
        _readDate(trabajoData?['estadoPagoActualizadoEn']);

    final chips = Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(
            pagoLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          avatar: Icon(
            _paymentIcon(estadoPago),
            color: pagoColor,
          ),
          backgroundColor: pagoColor.withOpacity(0.12),
          labelStyle: TextStyle(color: pagoColor),
          side: BorderSide(color: pagoColor.withOpacity(0.2)),
        ),
        if (monto != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_money_rounded, size: 16),
              const SizedBox(width: 4),
              Text(
                monto,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        if (pagoConfirmadoEn != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_available_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Pago confirmado el ${FormatUtils.formatDate(pagoConfirmadoEn)} a las ${FormatUtils.formatTime(pagoConfirmadoEn)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          )
        else if (pagoActualizadoEn != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Última actualización de pago: ${FormatUtils.formatDate(pagoActualizadoEn)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWorkSummarySection(
    BuildContext context,
    Map<String, dynamic>? trabajoData,
  ) {
    final inicio =
        _readDate(_postulacionData['inicioTrabajoReal']) ?? _readDate(_postulacionData['inicioTrabajoLocal']);
    final fin =
        _readDate(_postulacionData['finTrabajoReal']) ?? _readDate(_postulacionData['finTrabajoLocal']);

    final durationMinutes = _postulacionData['duracionTrabajoMinutos'] as int? ??
        _calculateDurationMinutes(inicio, fin);

    final evidenciasEnviadas = _postulacionData['evidenciasEnviadas'] as int?;
    final evidenciasRequeridas = _postulacionData['evidenciasRequeridas'] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen del trabajo',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.timer_outlined,
          title: 'Tiempo registrado',
          value: durationMinutes != null
              ? _formatDuration(durationMinutes)
              : 'No disponible',
        ),
        _InfoRow(
          icon: Icons.play_circle_outline,
          title: 'Inicio',
          value: inicio != null
              ? '${FormatUtils.formatDate(inicio)} · ${FormatUtils.formatTime(inicio)}'
              : 'No registrado',
        ),
        _InfoRow(
          icon: Icons.stop_circle_outlined,
          title: 'Fin',
          value: fin != null
              ? '${FormatUtils.formatDate(fin)} · ${FormatUtils.formatTime(fin)}'
              : 'No registrado',
        ),
        if (evidenciasEnviadas != null && evidenciasRequeridas != null)
          _InfoRow(
            icon: Icons.photo_library_outlined,
            title: 'Evidencias enviadas',
            value: '$evidenciasEnviadas de $evidenciasRequeridas',
          ),
      ],
    );
  }

  Widget _buildEvidencesSection(
    BuildContext context,
    Map<String, dynamic>? trabajoData,
  ) {
    final trabajoId = _trabajoId;
    if (trabajoId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidencias enviadas',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: storageService.mostrarEvidencias(trabajoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final evidencias = snapshot.data ?? const [];

            if (evidencias.isEmpty) {
              return const Text('No se registraron evidencias para este trabajo.');
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: evidencias.map((evidencia) {
                final url = evidencia['url'] as String?;
                final etapa = evidencia['etapa'] as String? ?? 'Evidencia';
                if (url == null) {
                  return const SizedBox.shrink();
                }
                return _EvidencePreview(
                  url: url,
                  label: etapa,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResolutionSection(
    BuildContext context,
    Map<String, dynamic>? trabajoData,
  ) {
    final mensaje = _resolveAdminMessage(trabajoData);
    final estadoTrabajo = _normalizeStatus(
      trabajoData?['estado'] ??
          trabajoData?['estadoTrabajo'] ??
          _postulacionData['estadoTrabajo'] ??
          _postulacionData['estado'],
    );

    IconData icon;
    Color? color;
    String titulo;
    String description;

    switch (estadoTrabajo) {
      case 'porpagar':
      case 'porpago':
      case 'porpagoenproceso':
      case 'porpagartrabajo':
        icon = Icons.verified_outlined;
        color = Colors.green.shade700;
        titulo = 'Evidencias aprobadas';
        description = mensaje ??
            'El administrador aprobó tus evidencias y tu pago está en proceso.';
        break;
      case 'finalizado':
      case 'pagado':
        icon = Icons.payments_outlined;
        color = Colors.green.shade700;
        titulo = 'Pago finalizado';
        description = mensaje ??
            'Tu trabajo fue finalizado y el pago se registró correctamente.';
        break;
      case 'rechazado':
        icon = Icons.cancel_outlined;
        color = Colors.red.shade700;
        titulo = 'Evidencias rechazadas';
        description = mensaje ??
            'Tus evidencias fueron rechazadas. Revisa los comentarios del administrador.';
        break;
      case 'pendienterevision':
      case 'porrevisar':
        icon = Icons.hourglass_bottom_rounded;
        color = Colors.orange.shade700;
        titulo = 'Revisión en proceso';
        description = mensaje ??
            'El administrador revisará tus evidencias y te notificará cualquier observación por este medio.';
        break;
      default:
        icon = mensaje != null && mensaje.isNotEmpty
            ? Icons.chat_bubble_outline_rounded
            : Icons.info_outline_rounded;
        color = null;
        titulo = 'Seguimiento del administrador';
        description = mensaje ??
            'El administrador revisará tus evidencias y te notificará cualquier observación por este medio.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resolución del trabajo',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (color ?? Theme.of(context).colorScheme.surfaceVariant)
                .withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color ??
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection(BuildContext context) {
    final trabajoId = _trabajoId;
    if (trabajoId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comprobante de pago',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: storageService.mostrarEvidenciasPagos(trabajoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final evidencias = snapshot.data ?? const [];
            final comprobante = evidencias.isNotEmpty
                ? evidencias.firstWhere(
                    (element) => (element['url'] as String?)?.isNotEmpty == true,
                    orElse: () => const {},
                  )
                : null;

            final url = comprobante is Map<String, dynamic>
                ? comprobante['url'] as String?
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url != null
                      ? 'Tu pago fue procesado. Puedes descargar el comprobante cuando lo necesites.'
                      : 'Aún no hay un comprobante disponible. Te avisaremos cuando el pago sea registrado.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                      url != null ? () => _launchExternal(context, url) : null,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar comprobante'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _statusLabel(String estado) {
    switch (estado) {
      case 'pendienterevision':
        return 'Pendiente de revisión';
      case 'porpagar':
        return 'Listo para pago';
      case 'finalizado':
      case 'pagado':
        return 'Trabajo finalizado';
      case 'rechazado':
        return 'Evidencias rechazadas';
      default:
        if (estado.isEmpty) return 'Estado no disponible';
        return estado;
    }
  }

  Color _statusColor(String estado, BuildContext context) {
    switch (estado) {
      case 'pendienterevision':
        return Colors.orange.shade700;
      case 'porpagar':
        return Colors.blue.shade700;
      case 'finalizado':
      case 'pagado':
        return Colors.green.shade700;
      case 'rechazado':
        return Colors.red.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _statusIcon(String estado) {
    switch (estado) {
      case 'pendienterevision':
        return Icons.fact_check_outlined;
      case 'porpagar':
        return Icons.payments_outlined;
      case 'finalizado':
      case 'pagado':
        return Icons.check_circle_outline;
      case 'rechazado':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _paymentLabel(String estado) {
    switch (estado) {
      case 'pagado':
      case 'completado':
        return 'Pago completado';
      case 'porpagar':
      case 'pendiente':
      case 'enproceso':
      case 'encurso':
        return 'Pago en proceso';
      default:
        if (estado.isEmpty) return 'Pago en revisión';
        return 'Pago: $estado';
    }
  }

  Color _paymentColor(String estado, BuildContext context) {
    switch (estado) {
      case 'pagado':
      case 'completado':
        return Colors.green.shade700;
      case 'porpagar':
      case 'pendiente':
      case 'enproceso':
      case 'encurso':
        return Colors.orange.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _paymentIcon(String estado) {
    switch (estado) {
      case 'pagado':
      case 'completado':
        return Icons.attach_money_rounded;
      case 'porpagar':
      case 'pendiente':
      case 'enproceso':
      case 'encurso':
        return Icons.schedule_rounded;
      default:
        return Icons.info_outline;
    }
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  int? _calculateDurationMinutes(DateTime? inicio, DateTime? fin) {
    if (inicio == null || fin == null) return null;
    final duration = fin.difference(inicio);
    if (duration.isNegative) return null;
    return duration.inMinutes;
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final parts = <String>[];
    if (hours > 0) {
      parts.add('$hours h');
    }
    if (mins > 0) {
      parts.add('$mins min');
    }
    if (parts.isEmpty) {
      return '$minutes min';
    }
    return parts.join(' ');
  }

  String? _resolveAdminMessage(Map<String, dynamic>? trabajoData) {
    final posiblesClaves = [
      'mensajeAdministrador',
      'mensajeAdmin',
      'comentarioAdministrador',
      'comentariosAdmin',
      'notaAdministrador',
      'notasAdministrador',
      'notaPago',
      'mensajePago',
      'motivoRechazo',
      'mensajeResolucion',
    ];

    for (final key in posiblesClaves) {
      final valor = _postulacionData[key] ?? trabajoData?[key];
      if (valor is String && valor.trim().isNotEmpty) {
        return valor.trim();
      }
    }

    return null;
  }

  Future<void> _launchExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos abrir el comprobante. Intenta nuevamente.'),
          ),
        );
      }
    }
  }

  String _normalizeStatus(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    }
    return '';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({
    required this.url,
    required this.label,
  });

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showFullImage(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 90,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.4),
                ),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}