import 'dart:io'; // Needed for File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para el portapapeles (Clipboard)
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/utils/format_utils.dart'; // Asegúrate que esta ruta sea correcta
import 'package:image_picker/image_picker.dart';

class WidgetGestionPago extends StatefulWidget {
  final Trabajo trabajo;
  final PostulanteService postulanteService;
  final TrabajoService trabajoService;
  final StorageService storageService;
  final String adminId;

  const WidgetGestionPago({
    Key? key,
    required this.trabajo,
    required this.postulanteService,
    required this.trabajoService,
    required this.storageService,
    required this.adminId,
  }) : super(key: key);

  @override
  State<WidgetGestionPago> createState() => _WidgetGestionPagoState();
}

class _WidgetGestionPagoState extends State<WidgetGestionPago> {
  bool _isLoading = false;

  void _subirComprobante() async {
    final XFile? imagen = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (imagen == null) return;

    setState(() => _isLoading = true);

    try {
      final imageUrl = await widget.storageService.subirEvidenciaPago(
        trabajoId: widget.trabajo.id,
        imagen: File(imagen.path),
        usuarioId: widget.adminId,
      );

      if (imageUrl == null) {
        throw Exception('Storage service returned null URL after upload.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante subido con éxito 👍'), backgroundColor: Colors.green),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir comprobante: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _finalizarPago() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Trabajo'),
        content: const Text('¿Confirmas que el pago fue realizado y deseas finalizar este trabajo? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar y Finalizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.trabajoService.finalizarYMarcarComoPagado(
        widget.trabajo.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar el pago: $e'), backgroundColor: Colors.red));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ CORRECCIÓN: Usar el nombre de campo correcto del modelo Trabajo
    final String? trabajadorAsignadoId = widget.trabajo.trabajadorAsignadoId;

    if (trabajadorAsignadoId == null) {
      // --- (El bloque de error crítico se mantiene) ---
      return Card(
        color: Colors.red.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 30),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Error Crítico: No se encontró el ID del trabajador asignado para este pago. Por favor, contacta a soporte.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // --- End Null Check ---

    // Si llegamos aquí, trabajadorAsignadoId NO es null
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de Pago',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Realiza el pago por ${FormatUtils.formatCurrency(widget.trabajo.precio)} a la siguiente cuenta:',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),

        // --- FutureBuilder para cargar datos bancarios ---
        FutureBuilder<Map<String, dynamic>?>(
          // ⚠️ CORRECCIÓN: Usar la variable correcta 'trabajadorAsignadoId'
          future: widget.postulanteService.obtenerDatosUsuario(trabajadorAsignadoId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              // --- (El bloque de warning se mantiene) ---
              return Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'No se pudieron cargar los datos bancarios. Verifica que el trabajador los haya ingresado en su perfil.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  )
                ),
              );
            }

            // Data fetched successfully
            final postulanteData = snapshot.data!;
            final Map<String, dynamic> datosBancarios = postulanteData['datosBancarios'] ?? {};
            final String nombre = postulanteData['nombre'] ?? 'Sin nombre';
            final String apellido = postulanteData['apellido'] ?? '';
            final String nombreCompleto = '$nombre $apellido'.trim();

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Datos para Transferencia',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 20),
                    _buildDatoBancarioCopiable(context, 'Beneficiario', nombreCompleto.isNotEmpty ? nombreCompleto : 'No especificado'),
                    _buildDatoBancarioCopiable(context, 'RUT', postulanteData['rut'] ?? 'No especificado'),
                    _buildDatoBancarioCopiable(context, 'Banco', datosBancarios['banco'] ?? 'No especificado'),
                    _buildDatoBancarioCopiable(context, 'Tipo Cuenta', datosBancarios['tipoCuenta'] ?? 'No especificado'),
                    _buildDatoBancarioCopiable(context, 'N° Cuenta', datosBancarios['numeroCuenta'] ?? 'No especificado'),
                  ],
                ),
              ),
            );
          },
        ),
        // --- End FutureBuilder ---

        const SizedBox(height: 24),

        // --- Loading indicator or Buttons ---
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
        else
          // --- StreamBuilder for Payment Proof Buttons ---
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.storageService.mostrarEvidenciasPagos(widget.trabajo.id),
            builder: (context, snapshot) {
              bool comprobanteSubido = false;
              String? comprobanteUrl;
              Widget comprobantePreview = const SizedBox.shrink();

              if (snapshot.connectionState == ConnectionState.active && snapshot.hasData && snapshot.data!.isNotEmpty) {
                comprobanteSubido = true;
                // Asumiendo que tu servicio devuelve una lista y el URL está en el primer elemento
                comprobanteUrl = snapshot.data![0]['url'];
                if (comprobanteUrl != null) {
                  comprobantePreview = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Comprobante Subido:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Center(
                        child: InkWell(
                          onTap: () => _mostrarImagenFullScreen(context, comprobanteUrl!),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  comprobanteUrl!,
                                  height: 150,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) => progress == null
                                      ? child
                                      : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 150,
                                    width: double.infinity,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  shape: BoxShape.circle
                                ),
                                child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 40),
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  comprobantePreview,

                  ElevatedButton.icon(
                    icon: Icon(comprobanteSubido ? Icons.sync_alt_rounded : Icons.upload_file_outlined),
                    label: Text(comprobanteSubido ? 'Reemplazar Comprobante' : 'Subir Comprobante'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: comprobanteSubido ? Colors.orange.shade700 : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _subirComprobante,
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Marcar como Pagado y Finalizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: comprobanteSubido ? _finalizarPago : null,
                  ),
                  
                  if (!comprobanteSubido)
                    _buildHintBox('Debes subir el comprobante para poder finalizar.')
                ],
              );
            },
          ),
          // --- End StreamBuilder ---
      ],
    );
  }

  Widget _buildDatoBancarioCopiable(BuildContext context, String label, String valor) {
    if (valor.toLowerCase() == 'no especificado' || valor.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            Text(valor, style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic, fontSize: 14)),
          ],
        ),
      );
    }
    
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: valor));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$valor" copiado al portapapeles'),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.copy_all_rounded, size: 16, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                valor,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarImagenFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  // ⚠️ CORRECCIÓN: Ícono de cerrar correcto
                  icon: const Icon(Icons.cloud_circle_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.3)), // Fondo para visibilidad
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildHintBox(String text) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.light ? Colors.orange.shade50 : Colors.orange.shade900.withOpacity(0.3);
    final iconColor = theme.brightness == Brightness.light ? Colors.orange.shade800 : Colors.orange.shade200;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: iconColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

} // Fin de _WidgetGestionPagoState