import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/theme/app_colors.dart';
// import 'package:goodjob_app/src/services/trabajo_service.dart'; 
// import 'package:goodjob_app/src/models/trabajo.dart'; 

class TrabajoFinalizado extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const TrabajoFinalizado({
    super.key,
    required this.trabajoId,
    required this.trabajo,
  });

  @override
  State<TrabajoFinalizado> createState() => _TrabajoFinalizadoState();
}

class _TrabajoFinalizadoState extends State<TrabajoFinalizado> {
  final StorageService _storageService = StorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  Map<String, dynamic>? _usuarioData;

  // --- COLORES Y CONSTANTES UI/UX ---
  static const Color primaryColor = AppColors.primary;
  static const Color alertColor = AppColors.alertColor;
  static const Color paidColor = AppColors.paidColor; // Color para indicar "Pagado"
  static const Color neutralColor = AppColors.neutralColor;

  @override
  void initState() {
    super.initState();
    _cargarUsuarioConfirmado();
  }

  // --- LÓGICA DE CARGA DE DATOS ---

  Future<void> _cargarUsuarioConfirmado() async {
    setState(() => _isLoading = true);
    try {
      final postulacionesSnapshot = await _firestore
          .collection('trabajos')
          .doc(widget.trabajoId)
          .collection('postulaciones')
          .where('estado', isEqualTo: 'confirmado')
          .limit(1)
          .get();

      if (postulacionesSnapshot.docs.isNotEmpty) {
        final postulacionData = postulacionesSnapshot.docs.first.data();
        final usuarioId = postulacionData['usuarioId'] as String?;

        if (usuarioId != null) {
          final usuarioDoc = await _firestore
              .collection('usuarios')
              .doc(usuarioId)
              .get();

          if (usuarioDoc.exists) {
            setState(() {
              _usuarioData = usuarioDoc.data();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar usuario confirmado: $e');
      if (mounted) {
        // Usar Theme color para SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del trabajador: $e'),
            backgroundColor: alertColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UTILIDADES ---

  Map<String, dynamic>? _safeMapCast(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  DateTime? _getTrabajoStartDateTime() {
    final newStartTs = widget.trabajo['fechaInicioTrabajo'] as Timestamp?;
    if (newStartTs != null) return newStartTs.toDate();
    return null;
  }

  DateTime? _getTrabajoEndDateTime() {
    final newEndTs = widget.trabajo['fechaFinTrabajo'] as Timestamp?;
    if (newEndTs != null) return newEndTs.toDate();
    return null;
  }

  String _formatearUbicacion(Map<String, dynamic>? ubicacion) {
    if (ubicacion == null) return 'N/A';
    final partes = [
      ubicacion['direccion'],
      ubicacion['ciudad'],
      ubicacion['pais'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
    return partes.isEmpty ? 'N/A' : partes;
  }

  String _formatHora(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'N/A';
    return FormatUtils.formatDate(fecha);
  }

  // --- WIDGETS DE VISTA MEJORADOS ---

  // Nuevo widget compacto de datos (UX: Agrupación visual, más limpio y compacto)
  Widget _buildDataChip(IconData icon, String label, String value, {Color iconColor = primaryColor}) {
    // Reducción de padding y tamaño de fuente para mayor densidad de información sin ruido
    return Container( 
      width: 150, // Ancho fijo para control de 'wrapping'
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18), // Icono ligeramente más pequeño
              const SizedBox(width: 4), // Espacio reducido
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: neutralColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2), // Espacio vertical muy reducido
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Nuevo widget para el encabezado principal (UX: Jerarquía clara)
  Widget _buildHeaderSummary() {
    final titulo = widget.trabajo['titulo'] as String? ?? 'Trabajo Finalizado';
    final estadoPago = widget.trabajo['estadoPago'] as String? ?? 'N/A';
    final esPagado = estadoPago.toLowerCase() == 'pagado';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título del trabajo (Elemento más grande)
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        // Chip de Estado de Pago (Énfasis semántico)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: esPagado ? paidColor : alertColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(esPagado ? Icons.verified_user : Icons.warning_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                esPagado ? 'PAGO Y TRABAJO FINALIZADO' : 'PENDIENTE DE PAGO',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
      ],
    );
  }


  Widget _buildSeccionTrabajo() {
    final fechaInicio = _getTrabajoStartDateTime();
    final fechaFin = _getTrabajoEndDateTime();
    final ubicacion = _safeMapCast(widget.trabajo['ubicacion']);
    final precio = (widget.trabajo['precio'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Detalles del Trabajo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        
        // UX: Usar Wrap para agrupar visualmente la información en chips de datos
        Wrap(
          spacing: 8.0, // Espacio horizontal reducido
          runSpacing: 12.0, // Espacio vertical entre filas de chips
          children: [
            _buildDataChip(
              Icons.business,
              'Empresa',
              widget.trabajo['empresa'] as String? ?? 'N/A',
              iconColor: Colors.teal,
            ),
            _buildDataChip(
              Icons.location_on,
              'Ubicación',
              _formatearUbicacion(ubicacion),
              iconColor: Colors.teal,
            ),
            _buildDataChip(
              Icons.calendar_today,
              'Fechas',
              '${_formatFecha(fechaInicio)} - ${_formatFecha(fechaFin)}',
              iconColor: Colors.indigo,
            ),
            _buildDataChip(
              Icons.access_time,
              'Horario',
              '${_formatHora(fechaInicio)} - ${_formatHora(fechaFin)} hrs',
              iconColor: Colors.indigo,
            ),
            _buildDataChip(
              Icons.attach_money,
              'Precio Original',
              FormatUtils.formatCurrency(precio),
              iconColor: paidColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionUsuario() {
    if (_usuarioData == null) {
      return const SizedBox(); // Si no hay usuario, no mostrar esta sección para no generar ruido
    }

    final nombre = _usuarioData!['nombre'] as String? ?? 'N/A';
    final apellido = _usuarioData!['apellido'] as String? ?? '';
    final nombreCompleto = '$nombre $apellido'.trim();
    final email = _usuarioData!['email'] as String? ?? 'N/A';
    final telefono = _usuarioData!['telefono'] as String? ?? 'N/A';
    final rut = _usuarioData!['rut'] as String? ?? 'N/A';
    final region = _usuarioData!['region'] as String? ?? 'N/A';
    final calle = _usuarioData!['calle'] as String? ?? '';
    final numero = _usuarioData!['numero'] as String? ?? '';
    final direccion = '$calle $numero'.trim().isEmpty ? 'N/A' : '$calle $numero';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Datos del Trabajador',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        
        // UX: Usar Wrap para datos del trabajador
        Wrap(
          spacing: 8.0, // Espacio horizontal reducido
          runSpacing: 12.0, // Espacio vertical entre filas de chips
          children: [
            _buildDataChip(Icons.badge, 'Nombre', nombreCompleto.isEmpty ? 'N/A' : nombreCompleto, iconColor: Colors.pink),
            _buildDataChip(Icons.fingerprint, 'RUT', rut, iconColor: Colors.pink),
            _buildDataChip(Icons.phone, 'Teléfono', telefono, iconColor: Colors.pink),
            _buildDataChip(Icons.email, 'Email', email, iconColor: Colors.pink),
            _buildDataChip(Icons.location_city, 'Región', region, iconColor: Colors.pink),
            _buildDataChip(Icons.home, 'Dirección', direccion, iconColor: Colors.pink),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionPago() {
    final estadoPago = widget.trabajo['estadoPago'] as String? ?? 'N/A';
    final montoPagado = (widget.trabajo['montoPagado'] as num?)?.toDouble() ?? 0.0;
    final fechaPagoTs = widget.trabajo['fechaPago'] as Timestamp?;
    final metodoPago = widget.trabajo['metodoPago'] as String? ?? 'N/A';
    final transactionId = widget.trabajo['idTransaccion'] as String? ?? 'N/A';

    final fechaPago = fechaPagoTs != null ? _formatFecha(fechaPagoTs.toDate()) : 'N/A';
    final esPagado = estadoPago.toLowerCase() == 'pagado';
    final colorPrincipal = esPagado ? paidColor : alertColor;

    // UX: Usar un contenedor estilizado para enfatizar los detalles financieros (Éxito o Advertencia)
    return Container(
      decoration: BoxDecoration(
        color: colorPrincipal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorPrincipal.withOpacity(0.5), width: 2),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: colorPrincipal, size: 28),
              const SizedBox(width: 8),
              Text(
                'Detalles de Pago',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorPrincipal,
                ),
              ),
              const Spacer(),
              // Indicador de estado más grande
              Text(
                estadoPago.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: colorPrincipal,
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Colors.black12),
          
          // UX: Usar el nuevo chip de datos para los detalles de pago
          Wrap(
            spacing: 8.0,
            runSpacing: 12.0,
            children: [
              _buildDataChip(
                Icons.account_balance_wallet,
                'Monto Pagado',
                FormatUtils.formatCurrency(montoPagado),
                iconColor: colorPrincipal,
              ),
              _buildDataChip(
                Icons.date_range,
                'Fecha de Pago',
                fechaPago,
                iconColor: colorPrincipal,
              ),
              _buildDataChip(
                Icons.credit_card,
                'Método',
                metodoPago,
                iconColor: colorPrincipal,
              ),
              _buildDataChip(
                Icons.receipt,
                'ID Transacción',
                transactionId,
                iconColor: colorPrincipal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionEvidencias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library, color: primaryColor, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Evidencias Fotográficas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _storageService.mostrarEvidencias(widget.trabajoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
            }

            if (snapshot.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Error al cargar evidencias: ${snapshot.error}', style: const TextStyle(color: alertColor))));
            }

            final evidencias = snapshot.data ?? [];

            if (evidencias.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No se encontraron evidencias fotográficas.',
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: neutralColor),
                  ),
                ),
              );
            }

            // UX: Usar GridView para una visualización compacta y mejor de imágenes
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 columnas en móvil
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.75, // Ajuste para que quepa la información debajo
              ),
              itemCount: evidencias.length,
              itemBuilder: (context, index) {
                final evidencia = evidencias[index];
                final etapa = evidencia['etapa'] as String? ?? 'N/A';
                final url = evidencia['url'] as String?;
                final gps = _safeMapCast(evidencia['gps']);
                final lat = gps?['lat']?.toString() ?? 'N/A';
                final lng = gps?['lng']?.toString() ?? 'N/A';
                final capturadaEn = evidencia['capturadaEn'] as Timestamp?;

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias, // Recortar la imagen al borde de la tarjeta
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Imagen
                      Expanded(
                        child: url != null
                            ? Image.network(
                                url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Icon(Icons.error_outline, size: 40, color: alertColor),
                                    ),
                                  );
                                },
                              )
                            : Container(color: Colors.grey[300]),
                      ),
                      
                      // Información
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              etapa.toUpperCase(),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: neutralColor),
                                const SizedBox(width: 4),
                                Text(
                                  capturadaEn != null ? _formatHora(capturadaEn.toDate()) : 'N/A',
                                  style: const TextStyle(fontSize: 12, color: neutralColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: neutralColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    // Muestra solo la latitud para evitar cortar demasiado
                                    'GPS: $lat', 
                                    style: const TextStyle(fontSize: 12, color: neutralColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // --- BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del Trabajo', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0, // AppBar plana para modernizar
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Encabezado de Título y Estado de Pago
                      _buildHeaderSummary(),
                      const SizedBox(height: 20),

                      // 2. Secciones
                      _buildSeccionTrabajo(),
                      const SizedBox(height: 30),
                      
                      _buildSeccionUsuario(),
                      const SizedBox(height: 30),

                      // 3. Sección de Pago (Con énfasis visual fuerte)
                      _buildSeccionPago(), 
                      const SizedBox(height: 30),

                      // 4. Evidencias
                      _buildSeccionEvidencias(),

                      const SizedBox(height: 40), 
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
