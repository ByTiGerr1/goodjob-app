import 'dart:io'; // Needed for File
import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // For picking the payment proof image

// --- Adjust these import paths to match your project structure ---
import '../../services/postulante_service.dart';
import '../../services/trabajo_service.dart';
import '../../services/storage_service.dart';
// ---

class WidgetGestionPago extends StatefulWidget {
  final Trabajo trabajo;
  final PostulanteService postulanteService;
  final TrabajoService trabajoService;
  final StorageService storageService;
  final String adminId; // ID of the currently logged-in admin

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

  /// Handles picking an image and uploading it as payment proof.
  void _subirComprobante() async {
    // 1. Pick image using image_picker
    final XFile? imagen = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (imagen == null) return; // User cancelled

    setState(() => _isLoading = true);

    try {
      // 2. Upload using your StorageService
      final imageUrl = await widget.storageService.subirEvidenciaPago(
        trabajoId: widget.trabajo.id,
        imagen: File(imagen.path),
        usuarioId: widget.adminId, // Pass the admin's ID
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

  /// Marks the job as paid and finalized.
  void _finalizarPago() async {
    // Show confirmation dialog
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

    if (confirmar != true) return; // User cancelled

    setState(() => _isLoading = true);
    try {
      // Call your TrabajoService method
      await widget.trabajoService.finalizarYMarcarComoPagado(
        widget.trabajo.id,
      );
      // No need to setState here, the parent screen should react to the state change.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar el pago: $e'), backgroundColor: Colors.red));
      // Only stop loading if there was an error, otherwise the screen will rebuild
       if (mounted) setState(() => _isLoading = false);
    }
    // Don't set isLoading to false on success, let the screen rebuild trigger
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.simpleCurrency(locale: 'es_CL', decimalDigits: 0);

    // --- Null Check for assignedWorkerId ---
    final String? assignedWorkerId = widget.trabajo.trabajadorAsignadoId;

    if (assignedWorkerId == null) {
      // If the ID is null, show an error message. This shouldn't happen in 'porPagar' state.
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

    // If we reach here, assignedWorkerId is valid.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de Pago',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Realiza el pago por ${currencyFormatter.format(widget.trabajo.precio)} a la siguiente cuenta:',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),

        // --- FutureBuilder to load bank details ---
        FutureBuilder<Map<String, dynamic>?>(
          future: widget.postulanteService.obtenerDatosUsuario(assignedWorkerId), // Use the safe ID
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              print('Error al cargar datos bancarios: ${snapshot.error}');
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDatoBancario('Beneficiario', nombreCompleto.isNotEmpty ? nombreCompleto : 'No especificado'),
                    _buildDatoBancario('RUT', datosBancarios['rut'] ?? 'No especificado'),
                    _buildDatoBancario('Banco', datosBancarios['banco'] ?? 'No especificado'),
                    _buildDatoBancario('Tipo Cuenta', datosBancarios['tipoCuenta'] ?? 'No especificado'),
                    _buildDatoBancario('N° Cuenta', datosBancarios['numeroCuenta'] ?? 'No especificado'),
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
              Widget comprobantePreview = const SizedBox.shrink(); // Empty widget initially

              // Check stream status
              if (snapshot.connectionState == ConnectionState.active && snapshot.hasData && snapshot.data!.isNotEmpty) {
                 comprobanteSubido = true;
                 comprobanteUrl = snapshot.data![0]['url']; // Get URL from your service data structure
                 if (comprobanteUrl != null) {
                   // Build a preview if URL exists
                   comprobantePreview = Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text('Comprobante Subido:', style: TextStyle(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       Center(
                         child: InkWell(
                           onTap: () {
                             // TODO: Implement full-screen image viewer
                             print("View image: $comprobanteUrl");
                           },
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: Image.network(
                               comprobanteUrl!,
                               height: 150,
                               fit: BoxFit.contain, // Use contain to see the whole image
                               loadingBuilder: (context, child, progress) => progress == null
                                   ? child
                                   : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                               errorBuilder: (context, error, stackTrace) => Container(
                                 height: 150,
                                 color: Colors.grey.shade200,
                                 child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                               ),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(height: 16), // Spacing after preview
                     ],
                   );
                 }
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                // Show loading indicator while checking for proof
                return const Center(child: CircularProgressIndicator());
              }

              // Build the column with preview (if exists) and buttons
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons fill width
                children: [
                  comprobantePreview, // Show the preview widget

                  // Upload/Replace Button
                  ElevatedButton.icon(
                    icon: Icon(comprobanteSubido ? Icons.sync_alt_rounded : Icons.upload_file_outlined),
                    label: Text(comprobanteSubido ? 'Reemplazar Comprobante' : 'Subir Comprobante'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: comprobanteSubido ? Colors.orange.shade700 : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _subirComprobante, // Always enabled
                  ),
                  const SizedBox(height: 12),

                  // Finalize Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Marcar como Pagado y Finalizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    // Enable only if proof has been uploaded
                    onPressed: comprobanteSubido ? _finalizarPago : null,
                  ),
                  // Helper text if finalize button is disabled
                  if (!comprobanteSubido)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Debes subir el comprobante para poder finalizar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                ],
              );
            },
          ),
          // --- End StreamBuilder ---
      ],
    );
  } // Fin del build

  /// Helper widget to display bank details row
  Widget _buildDatoBancario(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          const SizedBox(width: 16), // Add space
          Expanded( // Allow value to wrap if too long
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.end, // Align value to the right
            ),
          ),
        ],
      ),
    );
  } // Fin de _buildDatoBancario

} // Fin de _WidgetGestionPagoState