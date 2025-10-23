import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import '../services/postulacion_service.dart'; // Asumiendo que PostulacionService existe

class DetalleTrabajoScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const DetalleTrabajoScreen(
      {super.key, required this.trabajoId, required this.trabajo});

  @override
  State<DetalleTrabajoScreen> createState() => _DetalleTrabajoScreenState();
}

class _DetalleTrabajoScreenState extends State<DetalleTrabajoScreen> {
  // --- CONSTANTES Y SERVICIOS ---
  final PostulacionService _postulacionService = PostulacionService();
  final String? _usuarioId = FirebaseAuth.instance.currentUser?.uid;
  Timer? _timer;
  String _countdownText = '';
  bool _isConfirming = false;
  bool _isCanceling = false; // Nuevo estado para la cancelación
  bool _liberacionExpiracionEnCurso = false;
  bool _liberacionExpiracionRealizada = false;

  // Colores de la aplicación
  static const Color primaryColor = Color(0xFF7B0997);
  static const Color secondaryColor = Color(0xFF7B0997);
  static const Color alertColor = Color(0xFFD32F2F); // Rojo para expirar
  static const Color cancelColor = Color(0xFF757575); // Gris para cancelar

  // --- LÓGICA DE TIEMPO Y ESTADOS ---

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- FUNCIONES DE AYUDA DE CASTING ---

  Map<String, dynamic>? safeMapCast(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Timestamp? safeTimestampCast(dynamic value) {
    return value is Timestamp ? value : null;
  }
  
  // FUNCIÓN: Obtener la URL de la imagen principal
  String? _getImagenPrincipalUrl() {
    return widget.trabajo['imagenPrincipalUrl'] as String?;
  }

  // --- FUNCIONES DE FORMATO REQUERIDAS ---

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/D';
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    final year = (fecha.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  String _formatHora(Map<String, dynamic>? hora) {
    if (hora == null) return 'N/D';
    final h = hora['h'];
    final m = hora['m'];
    final hour = (h is int ? h : int.tryParse(h?.toString() ?? '0') ?? 0)
        .toString()
        .padLeft(2, '0');
    final min = (m is int ? m : int.tryParse(m?.toString() ?? '0') ?? 0)
        .toString()
        .padLeft(2, '0');
    return '$hour:$min';
  }
  
  String _formatFechaHora(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$minuto';
  }
  
  // --- FUNCIONES DE EXTRACCIÓN ROBUSTA DE DATOS (DUAL-SCHEMA) ---

  Timestamp? _getFechaLimiteTs() {
    final dynamic fechaLimite = widget.trabajo['fechaLimite'];
    final dynamic fechaLimiteAntigua = widget.trabajo['fechaLimitePostulacion'];
    
    if (fechaLimite is Timestamp) return fechaLimite;
    if (fechaLimiteAntigua is Timestamp) return fechaLimiteAntigua;

    return null;
  }
  
  Timestamp? _getFechaInicioTrabajoTs() {
    final dynamic fechaInicio = widget.trabajo['fechaInicioTrabajo'];
    final dynamic fechaTrabajoAntigua = widget.trabajo['fechaTrabajo'];

    if (fechaInicio is Timestamp) return fechaInicio;
    if (fechaTrabajoAntigua is Timestamp) return fechaTrabajoAntigua;
    
    return null;
  }

  Map<String, dynamic>? _getHoraInicioMap() {
    final dynamic horaInicioNuevo = widget.trabajo['horaInicioTrabajo'];
    final dynamic horaInicioAntiguo = widget.trabajo['horaInicio'];

    if (horaInicioNuevo is Map) return safeMapCast(horaInicioNuevo);
    if (horaInicioAntiguo is Map) return safeMapCast(horaInicioAntiguo);
    
    return null; 
  }

  Map<String, dynamic>? _getHoraFinMap() {
    final dynamic horaFinNuevo = widget.trabajo['fechaFinTrabajo'];
    final dynamic horaFinAntiguo = widget.trabajo['horaFin'];

    if (horaFinNuevo is Map) return safeMapCast(horaFinNuevo);
    if (horaFinAntiguo is Map) return safeMapCast(horaFinAntiguo);
    
    return null;
  }

  // --- LÓGICA DE TEMPORIZADOR Y ACCIONES (OPTIMIZADA) ---

  void _startCountdown() {
    if (widget.trabajo['sinFechaLimite'] == true) {
      setState(() {
        _countdownText = 'Postulaciones abiertas';
      });
      return;
    }

    _updateCountdown();
    // Actualizar cada 30 segundos (suficiente para días/horas)
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (widget.trabajo['sinFechaLimite'] == true) {
      _timer?.cancel();
      return;
    }

    final safeFechaFin = _getFechaLimiteTs();

    if (safeFechaFin == null) {
      _timer?.cancel();
      return;
    }

    final remaining = safeFechaFin.toDate().difference(DateTime.now());

    if (remaining.isNegative) {
      setState(() {
        _countdownText = 'Ya expiró';
      });
      _timer?.cancel();
    } else {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      // Mostrar solo días y horas.
      setState(() {
        _countdownText =
            '${days}d ${hours}h';
      });
    }
  }

  Future<void> _postularse() async {
    if (_usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para postularte.')),
      );
      return;
    }

    try {
      // ASUME QUE ESTE MÉTODO EXISTE EN PostulacionService
      await _postulacionService.crearPostulacion(
        trabajoId: widget.trabajoId,
        trabajoTitulo: widget.trabajo['titulo'] ?? '',
        usuarioId: _usuarioId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Te has postulado con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al postularte: $e')),
        );
      }
    }
  }

  // FUNCIÓN: Lógica para cancelar postulación
  Future<void> _cancelarPostulacion() async {
    if (_usuarioId == null || _isCanceling) return;

    final cancelar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Postulación'),
        content: const Text(
          '¿Estás seguro de que quieres cancelar tu postulación? El administrador será notificado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Mantener Postulación'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Sí, Cancelar', style: TextStyle(color: alertColor)),
          ),
        ],
      ),
    );

    if (cancelar != true || !mounted) {
      return;
    }

    setState(() => _isCanceling = true);

    try {
      // ** ASUME QUE ESTE MÉTODO EXISTE EN PostulacionService **
      await _postulacionService.cancelarPostulacion(
        trabajoId: widget.trabajoId,
        usuarioId: _usuarioId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postulación cancelada con éxito.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar postulación: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCanceling = false);
      } else {
        _isCanceling = false;
      }
    }
  }

  Future<void> _confirmarTrabajo() async {
    if (_usuarioId == null || _isConfirming) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar trabajo'),
        content: const Text(
          'Al confirmar el trabajo te comprometes a asistir y cumplir con las responsabilidades asignadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) {
      return;
    }

    setState(() => _isConfirming = true);

    try {
      await _postulacionService.confirmarAsignacion(
        trabajoId: widget.trabajoId,
        postulanteId: _usuarioId,
        trabajoTitulo: widget.trabajo['titulo'] ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Has confirmado el trabajo con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo confirmar el trabajo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      } else {
        _isConfirming = false;
      }
    }
  }

  Future<void> _liberarAsignacionExpirada() async {
    if (_usuarioId == null || _liberacionExpiracionEnCurso || _liberacionExpiracionRealizada) {
      return;
    }

    setState(() => _liberacionExpiracionEnCurso = true);

    try {
      await _postulacionService.liberarAsignacionPorExpiracion(
        trabajoId: widget.trabajoId,
        postulanteId: _usuarioId,
        trabajoTitulo: widget.trabajo['titulo'] ?? '',
      );
      if (mounted) {
        setState(() => _liberacionExpiracionRealizada = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El plazo de confirmación expiró. El trabajo volvió a estar disponible para el administrador.',
            ),
          ),
        );
      } else {
        _liberacionExpiracionRealizada = true;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo liberar la asignación expirada: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _liberacionExpiracionEnCurso = false);
      } else {
        _liberacionExpiracionEnCurso = false;
      }
    }
  }
  
  // --- WIDGETS DE VISTA Y FORMATO ---

  ButtonStyle get _primaryButtonStyle {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
    );
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'N/D';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
      ubicacion['pais'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes.isEmpty ? 'N/D' : partes;
  }
  
  // Utilidad para extraer horarioTexto, día, pago, etc.
  Map<String, dynamic> _extractJobDetails() {
    // FECHA DE INICIO DEL TRABAJO:
    final fechaInicioTrabajoTs = _getFechaInicioTrabajoTs();
    final fechaInicio = fechaInicioTrabajoTs?.toDate();

    // HORARIOS: 
    final horaInicioAntigua = _getHoraInicioMap();
    final horaFinAntigua = _getHoraFinMap();
    
    String horarioTexto = 'N/D';
    if (fechaInicioTrabajoTs != null) {
      final fechaFinTrabajoTs = safeTimestampCast(widget.trabajo['fechaFinTrabajo']);
      
      if (fechaFinTrabajoTs != null) {
        final inicio = fechaInicioTrabajoTs.toDate();
        final fin = fechaFinTrabajoTs.toDate();
        horarioTexto = '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')} - ${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')} hrs';
      } else {
        final inicio = fechaInicioTrabajoTs.toDate();
        horarioTexto = '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')} hrs';
      }
    } else if (horaInicioAntigua != null && horaFinAntigua != null) {
      // Esquema Antiguo
      horarioTexto = '${_formatHora(horaInicioAntigua)} - ${_formatHora(horaFinAntigua)} hrs';
    }
    
    final diaTexto = _formatFecha(fechaInicio);
    final dynamic precio = widget.trabajo['precio'];
    final pagoTexto = (precio != null) 
    // Usamos FormatUtils (asumido que existe)
    ? FormatUtils.formatCurrency(precio.toDouble()) 
    : 'N/D';

    return {
      'horario': horarioTexto,
      'dia': diaTexto,
      'pago': pagoTexto,
    };
  }

  Widget _buildDetalleItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estilo del TÍTULO (menos prominente)
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Colors.black45),
                ),
                // Estilo del VALOR (más prominente)
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL: Botón de Acción ---

  Widget _buildBotonAccionPrincipal(BuildContext context) {
    if (_usuarioId == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: _primaryButtonStyle,
          child: const Text(
            'Inicia sesión para postularte',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _postulacionService.observarPostulacionDeUsuario(
        trabajoId: widget.trabajoId,
        usuarioId: _usuarioId,
      ),
      builder: (context, snapshot) {
        // Manejo de estados de carga/error
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: _primaryButtonStyle,
              child: const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          );
        }

        final postulacionDoc = snapshot.data;
        if (postulacionDoc == null || !postulacionDoc.exists) {
          // 1. ESTADO: No Postulado
          final bool isExpired = _countdownText == 'Ya expiró'; 
          
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isExpired ? null : _postularse,
              style: _primaryButtonStyle.copyWith(
                backgroundColor: isExpired ? WidgetStateProperty.all(Colors.grey) : null,
              ),
              child: Text(
                isExpired ? 'Plazo de postulación expirado' : 'Postularme ahora',
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        // 2. ESTADOS: Postulado (Pendiente, Aceptado, Confirmado, Rechazado)
        final data = postulacionDoc.data() ?? <String, dynamic>{};
        final estado = (data['estado'] as String? ?? '').toLowerCase();
        
        final confirmarAntesDeTs = data['confirmarAntesDe'];
        final safeConfirmarAntesDeTs = confirmarAntesDeTs is Timestamp ? confirmarAntesDeTs : null;
        
        DateTime? confirmarAntesDe = safeConfirmarAntesDeTs?.toDate();
        // Si no hay 'confirmarAntesDe', asumimos el plazo por defecto (ej. 24h desde 'aceptadoEn')
        if (confirmarAntesDe == null) {
          final acceptedEnTs = safeTimestampCast(data['aceptadoEn']);
          if (acceptedEnTs != null) {
              confirmarAntesDe = acceptedEnTs.toDate().add(const Duration(hours: 24));
          }
        }
        
        final plazoExpirado = confirmarAntesDe != null && DateTime.now().isAfter(confirmarAntesDe);
        
        Widget estadoMensaje(IconData icon, String message, Color color) {
            return Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color),
                ),
                child: Row(
                    children: [
                        Icon(icon, color: color, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                message,
                                style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.w500),
                            ),
                        ),
                    ],
                ),
            );
        }

        switch (estado) {
            case 'aceptado':
                if (plazoExpirado) {
                    if (!_liberacionExpiracionRealizada && !_liberacionExpiracionEnCurso) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                            _liberarAsignacionExpirada();
                        });
                    }

                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            estadoMensaje(
                                Icons.watch_later_outlined,
                                'El plazo para confirmar expiró. La asignación será liberada.',
                                Colors.orange,
                            ),
                            ElevatedButton(
                                onPressed: null,
                                style: _primaryButtonStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.grey)),
                                child: const Text('Plazo de confirmación expirado', style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                        ],
                    );
                }
                
                // Requiere confirmación
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        estadoMensaje(
                            Icons.check_circle_outline,
                            '¡Felicidades! Fuiste seleccionado. Confirma tu asistencia antes del ${_formatFechaHora(confirmarAntesDe!)}.',
                            Colors.green.shade800,
                        ),
                        ElevatedButton(
                            onPressed: _isConfirming ? null : _confirmarTrabajo,
                            style: _primaryButtonStyle,
                            child: _isConfirming
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Confirmar trabajo', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                    ],
                );
            case 'confirmado':
                // Confirmado
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        estadoMensaje(
                            Icons.done_all,
                            '¡Trabajo confirmado! Revisa la sección de requisitos.',
                            primaryColor,
                        ),
                        ElevatedButton(
                            onPressed: null,
                            style: _primaryButtonStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.green)),
                            child: const Text('Trabajo confirmado', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                    ],
                );
            case 'rechazado':
                // Rechazado
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        estadoMensaje(
                            Icons.cancel_outlined,
                            'Tu postulación fue rechazada para este trabajo.',
                            Colors.red.shade800,
                        ),
                        ElevatedButton(
                            onPressed: null,
                            style: _primaryButtonStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.grey)),
                            child: const Text('Postulación rechazada', style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                    ],
                );
            case 'pendiente':
                // PENDIENTE: Ofrecer opción de cancelar/retractarse
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        estadoMensaje(
                            Icons.pending_actions,
                            'Tu postulación está en revisión. Te notificaremos cuando el administrador tome una decisión.',
                            Colors.blue.shade800,
                        ),
                        // Botón Primario para el estado
                        ElevatedButton(
                            onPressed: null,
                            style: _primaryButtonStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.blue)),
                            child: const Text('Postulación en revisión', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        // NUEVO BOTÓN: Opción de Cancelar
                        OutlinedButton.icon(
                            onPressed: _isCanceling ? null : _cancelarPostulacion,
                            icon: _isCanceling 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cancelColor))
                                : const Icon(Icons.close, color: cancelColor),
                            label: Text(
                                _isCanceling ? 'Cancelando...' : 'Cancelar Postulación',
                                style: const TextStyle(color: cancelColor, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: cancelColor, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                        ),
                    ],
                );
            default:
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        estadoMensaje(
                            Icons.help_outline,
                            'El estado de tu postulación es desconocido.',
                            Colors.grey.shade600,
                        ),
                        ElevatedButton(
                            onPressed: null,
                            style: _primaryButtonStyle.copyWith(backgroundColor: WidgetStateProperty.all(Colors.grey)),
                            child: const Text('Estado Desconocido', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                    ],
                );
        }
      },
    );
  }

  // Helper para los elementos de la Tarjeta de Resumen (Espaciado mejorado)
  Widget _buildSummaryItem(IconData icon, String title, String value, {bool isPrimary = false}) {
    return Column(
      children: [
        Icon(icon, color: isPrimary ? secondaryColor : primaryColor, size: 30),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black54),
          textAlign: TextAlign.center, // Centrar texto para mejor lectura en la columna
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: isPrimary ? secondaryColor : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // --- WIDGET PRINCIPAL: VISTA DETALLE ---

  @override
  Widget build(BuildContext context) {
    // Extracción de datos (centralizada para limpieza del build)
    final detalles = _extractJobDetails();
    final ubicacion = safeMapCast(widget.trabajo['ubicacion']);
    final requiereUniforme = widget.trabajo['requiereUniforme'] as bool? ?? false;
    final implementosUniforme = (widget.trabajo['implementosUniforme'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final instrucciones = widget.trabajo['instrucciones'] as String? ?? 'No hay requisitos específicos.';
    final descripcion = widget.trabajo['descripcion'] ?? 'Descripción no disponible.';
    
    final imagenUrl = _getImagenPrincipalUrl(); // EXTRAEMOS LA URL DE LA IMAGEN

    // Lógica para el texto claro del uniforme
    final String uniformeTexto = requiereUniforme 
        ? 'Sí, debe llevar el suyo.' 
        : 'No, no se requiere uniforme.';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0, // Aumentamos la altura para la imagen
            floating: true,
            pinned: true,
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              centerTitle: false,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trabajo['titulo'] ?? 'Título N/D',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, shadows: [
                      Shadow(blurRadius: 5.0, color: Colors.black, offset: Offset(1, 1))
                    ]),
                  ),
                  Text(
                    widget.trabajo['empresa'] ?? 'Empresa N/D',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), shadows: const [
                      Shadow(blurRadius: 3.0, color: Colors.black, offset: Offset(1, 1))
                    ]),
                  ),
                ],
              ),
              background: Container(
                color: primaryColor,
                child: imagenUrl != null && imagenUrl.isNotEmpty
                    ? Image.network(
                        imagenUrl,
                        fit: BoxFit.cover,
                        // Manejo de errores de carga de red
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: primaryColor,
                            child: const Center(
                              child: Icon(Icons.business_center_outlined, size: 80, color: Colors.white54),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.business_center_outlined, size: 80, color: Colors.white54),
                      ),
              ),
            ),
          ),
          
          SliverList(
            delegate: SliverChildListDelegate(
              [
                // --- 1. TARJETA DE RESUMEN CLAVE ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), 
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), 
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                        children: [
                          _buildSummaryItem(Icons.calendar_today, 'Día', detalles['dia']),
                          _buildSummaryItem(Icons.access_time, 'Horario', detalles['horario']),
                          _buildSummaryItem(Icons.monetization_on, 'Pago', detalles['pago'], isPrimary: true),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // --- 2. DESCRIPCIÓN ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Descripción del Trabajo', 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Divider(height: 16),
                      Text(
                        descripcion,
                        style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                      ),
                      const SizedBox(height: 40), 
                      
                      // --- 3. LOGÍSTICA (Ubicación) ---
                      const Text('Ubicación y Logística', 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Divider(height: 16),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildDetalleItem(
                            Icons.location_on_outlined,
                            'Ubicación',
                            _formatearUbicacion(ubicacion),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40), 

                      // --- 4. REQUISITOS CLAVE (Uniforme/Instrucciones) ---
                      const Text('Requisitos Clave', 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Divider(height: 16),
                      
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Uniforme: Ahora con texto claro
                              _buildDetalleItem(
                                requiereUniforme ? Icons.check_circle_outline : Icons.cancel_outlined,
                                'Uniforme',
                                uniformeTexto,
                              ),
                              if (requiereUniforme && implementosUniforme.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 36.0, bottom: 12.0),
                                  child: Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: implementosUniforme
                                        .map((item) => Chip(
                                              label: Text(item, style: const TextStyle(fontSize: 14)),
                                              backgroundColor: primaryColor.withOpacity(0.1),
                                              labelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              _buildDetalleItem(
                                Icons.info_outline,
                                'Instrucciones Específicas',
                                instrucciones,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 100), // Espacio final para el FAB
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // --- BOTÓN DE ACCIÓN FIJO Y CUENTA REGRESIVA ---
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy, color: alertColor, size: 24), // Usamos alertColor para el reloj
                const SizedBox(width: 8),
                const Text(
                  'Esta oferta termina en:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black54),
                ),
                const Spacer(),
                Text(
                  _countdownText,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: alertColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBotonAccionPrincipal(context),
          ],
        ),
      ),
    );
  }
}
