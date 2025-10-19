import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/services/format_utils.dart';
import 'dart:async';

// Simulación de la pantalla de edición, que es la misma que la de creación
import 'crear_trabajo_screen.dart';

class AdminTrabajoDetalleScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const AdminTrabajoDetalleScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<AdminTrabajoDetalleScreen> createState() =>
      _AdminTrabajoDetalleScreenState();
}

class _AdminTrabajoDetalleScreenState extends State<AdminTrabajoDetalleScreen> {
  Timer? _timer;
  String _countdownText = '';

  // CORRECCIÓN CLAVE: Inicializamos _trabajoData directamente desde widget.trabajo.
  // Esto elimina el LateInitializationError y permite acceso inmediato a los datos.
  late Map<String, dynamic> _trabajoData = widget.trabajo;

  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = Color(0xFF7B0997); // Púrpura principal
  static const Color secondaryColor = Color(0xFFE91E63); // Rosa/Rojo de acento
  static const Color alertColor = Color(
    0xFFD32F2F,
  ); // Rojo para estados críticos

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

  // --- LÓGICA DE DATOS Y TIEMPO ---

  Map<String, dynamic>? _safeMapCast(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  DateTime? _getTrabajoStartDateTime() {
    final newStartTs = _trabajoData['fechaInicioTrabajo'] as Timestamp?;
    if (newStartTs != null) return newStartTs.toDate();

    final oldDateTs = _trabajoData['fechaTrabajo'] as Timestamp?;
    final oldHourMap = _safeMapCast(_trabajoData['horaInicio']);

    if (oldDateTs != null && oldHourMap != null) {
      final date = oldDateTs.toDate();
      final h = oldHourMap['h'] as int? ?? 0;
      final m = oldHourMap['m'] as int? ?? 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }
    return DateTime.now(); // Valor predeterminado
  }

  DateTime? _getTrabajoEndDateTime() {
    final newEndTs = _trabajoData['fechaFinTrabajo'] as Timestamp?;
    if (newEndTs != null) return newEndTs.toDate();

    final oldDateTs = _trabajoData['fechaTrabajo'] as Timestamp?;
    final oldHourMap = _safeMapCast(_trabajoData['horaFin']);

    if (oldDateTs != null && oldHourMap != null) {
      final date = oldDateTs.toDate();
      final h = oldHourMap['h'] as int? ?? 0;
      final m = oldHourMap['m'] as int? ?? 0;
      return DateTime(date.year, date.month, date.day, h, m);
    }
    return DateTime.now(); // Valor predeterminado
  }

  void _startCountdown() {
    final fechaFinTs =
        _trabajoData['fechaLimite'] as Timestamp? ??
        _trabajoData['fechaLimitePostulacion'] as Timestamp?;

    if (fechaFinTs == null) {
      setState(() {
        _countdownText = 'Fecha limite no disponible';
      });
      return;
    }

    _updateCountdown(fechaFinTs);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown(fechaFinTs);
    });
  }

  void _updateCountdown(Timestamp fechaFinTs) {
    final remaining = fechaFinTs.toDate().difference(DateTime.now());

    if (remaining.isNegative) {
      setState(() {
        _countdownText = 'Ya acabo';
      });
      _timer?.cancel();
    } else {
      final days = remaining.inDays;
      final hours = remaining.inHours % 24;
      final minutes = remaining.inMinutes % 60;
      final seconds = remaining.inSeconds % 60;
      setState(() {
        // Guardamos el formato completo, aunque solo mostremos el simplificado
        _countdownText = '${days}d ${hours}h ${minutes}m ${seconds}s';
      });
    }
  }

  // --- NAVEGACIÓN A EDICIÓN (FUNCIÓN ACTUALIZADA) ---
  Future<void> _editarTrabajo() async {
    final resultado = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CrearTrabajoScreen(
          trabajoIdParaEditar: widget.trabajoId,
          trabajoInicial: _trabajoData, // Pasamos el dato para precargar
        ),
      ),
    );

    // Si el resultado de la edición es 'true', podemos forzar una recarga o actualizar
    if (resultado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vista de detalle actualizada.')),
      );
      // En una app con Streams/BLoC/Provider, esto recargaría automáticamente.
      // Aquí, forzamos un setState para reflejar cualquier cambio simple si es necesario.
      // setState(() {});
    }
  }
  // ---------------------------------------------

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'N/D';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
      ubicacion['pais'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes.isEmpty ? 'N/D' : partes;
  }

  String _formatHora(DateTime? dateTime) {
    if (dateTime == null) return 'N/D';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/D';
    final day = fecha.day.toString().padLeft(2, '0');
    final month = fecha.month.toString().padLeft(2, '0');
    final year = (fecha.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  // --- WIDGETS DE VISTA ---

  Widget _buildDetalleItem(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: primaryColor, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black54,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      minLeadingWidth: 20,
    );
  }

  Widget _buildLogisticaSection(
    DateTime? fechaInicio,
    DateTime? fechaFin,
    Map<String, dynamic>? ubicacion,
  ) {
    final hora = (fechaInicio != null && fechaFin != null)
        ? '${_formatHora(fechaInicio)} - ${_formatHora(fechaFin)} hrs'
        : 'N/D';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logística y Pago',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primaryColor,
              ),
            ),
            const Divider(color: Colors.black12, height: 16),
            _buildDetalleItem(
              Icons.location_on_outlined,
              'Ubicación del trabajo',
              _formatearUbicacion(ubicacion),
            ),
            _buildDetalleItem(
              Icons.calendar_today,
              'Día de trabajo',
              _formatFecha(fechaInicio),
            ),
            _buildDetalleItem(Icons.access_time_filled, 'Horario', hora),
            _buildDetalleItem(
              Icons.payments,
              'Pago total',
              (_trabajoData['precio'] != null)
                  ? FormatUtils.formatCurrency(
                      _trabajoData['precio'].toDouble(),
                    )
                  : 'N/D',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequisitosContactoSection(
    Map<String, dynamic>? contacto,
    bool requiereUniforme,
    List<String> implementosUniforme,
    String instrucciones,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Requisitos y Contacto',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primaryColor,
              ),
            ),
            const Divider(color: Colors.black12, height: 16),

            // Requisitos
            _buildDetalleItem(
              requiereUniforme
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              'Uniforme Requerido',
              requiereUniforme ? 'Sí' : 'No',
            ),

            if (requiereUniforme && implementosUniforme.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 44.0, bottom: 12.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: implementosUniforme
                      .map(
                        (item) => Chip(
                          label: Text(
                            item,
                            style: const TextStyle(fontSize: 14),
                          ),
                          backgroundColor: primaryColor.withOpacity(0.1),
                          labelStyle: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

            _buildDetalleItem(
              Icons.info_outline,
              'Instrucciones Específicas',
              instrucciones,
            ),

            const SizedBox(height: 10),

            // Contacto
            const Text(
              'Información de Contacto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(color: Colors.black12, height: 16),
            _buildDetalleItem(
              Icons.person,
              'Nombre de contacto',
              contacto?['nombre'] ?? 'N/D',
            ),
            _buildDetalleItem(
              Icons.phone,
              'Número de contacto',
              contacto?['numero'] ?? 'N/D',
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET DE ADMINISTRACIÓN (Panel de Alerta) ---
  Widget _buildAdministracionSection() {
    final bool isFinished = _countdownText == 'Ya acabo';
    final Color countdownColor = isFinished ? alertColor : secondaryColor;

    // Nuevo Título
    const String panelTitle = 'Tiempo Límite para Postulación';

    // Cálculo del formato de tiempo simplificado (Días y Horas)
    String simplifiedCountdownText = _countdownText;
    if (!isFinished && _timer != null) {
      final fechaFinTs =
          _trabajoData['fechaLimite'] as Timestamp? ??
          _trabajoData['fechaLimitePostulacion'] as Timestamp?;

      if (fechaFinTs != null) {
        final remaining = fechaFinTs.toDate().difference(DateTime.now());
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        simplifiedCountdownText = '${days}d ${hours}h';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: isFinished
            ? alertColor.withOpacity(0.1)
            : primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFinished ? alertColor : primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título actualizado
          Text(
            panelTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: primaryColor,
            ),
          ),
          const Divider(color: Colors.black12, height: 16),

          // --- BLOQUE DE CUENTA REGRESIVA (CRÍTICO) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: countdownColor, size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFinished ? 'ESTADO' : 'QUEDAN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: countdownColor.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    isFinished ? _countdownText : simplifiedCountdownText,
                    style: TextStyle(
                      fontSize: 20, // Tamaño de fuente reducido
                      fontWeight: FontWeight.w900,
                      color: countdownColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ID del trabajo ha sido ELIMINADO según tu solicitud
        ],
      ),
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    // --- EXTRACCIÓN ROBUSTA DE DATOS ---
    final fechaInicio = _getTrabajoStartDateTime();
    final fechaFin = _getTrabajoEndDateTime();

    final Map<String, dynamic>? ubicacion = _safeMapCast(
      _trabajoData['ubicacion'],
    );
    // Usamos _safeMapCast para contacto para evitar el error de Map<String, String>
    final Map<String, dynamic>? contacto = _safeMapCast(
      _trabajoData['contacto'],
    );

    final bool requiereUniforme =
        _trabajoData['requiereUniforme'] as bool? ?? false;
    final List<String> implementosUniforme =
        (_trabajoData['implementosUniforme'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final String instrucciones =
        _trabajoData['instrucciones'] as String? ??
        'No hay requisitos específicos.';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              centerTitle: false,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _trabajoData['titulo'] ?? 'Título no disponible',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _trabajoData['empresa'] ?? 'Empresa N/D',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              background: Container(
                color: primaryColor,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 40),
                child: const Icon(
                  Icons.business_center,
                  size: 80,
                  color: Colors.white70,
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: 'Editar Trabajo',
                onPressed: _editarTrabajo, // Llamada a la función de edición
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- DESCRIPCIÓN ---
                    const Text(
                      'Descripción del Trabajo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Divider(height: 16),
                    Text(
                      _trabajoData['descripcion'] ??
                          'Descripción no disponible.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- SECCIONES ESTRUCTURADAS EN TARJETAS ---
                    _buildLogisticaSection(fechaInicio, fechaFin, ubicacion),
                    _buildRequisitosContactoSection(
                      contacto,
                      requiereUniforme,
                      implementosUniforme,
                      instrucciones,
                    ),

                    // --- PANEL DE ADMINISTRACIÓN MEJORADO ---
                    _buildAdministracionSection(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
