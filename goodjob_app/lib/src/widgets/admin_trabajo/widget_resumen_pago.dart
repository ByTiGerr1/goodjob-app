import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/services/postulante_service.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';
import 'package:goodjob_app/src/utils/rut_utils.dart';

class WidgetResumenPago extends StatelessWidget {
  final Trabajo trabajo;
  final PostulanteService postulanteService;
  final StorageService storageService;

  const WidgetResumenPago({
    Key? key,
    required this.trabajo,
    required this.postulanteService,
    required this.storageService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? trabajadorAsignadoId = trabajo.trabajadorAsignadoId;

    if (trabajadorAsignadoId == null) {
      // Esto no debería pasar si el trabajo está finalizado, pero es un buen control
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Error: No se puede mostrar el resumen de pago. El ID del trabajador es nulo.',
          style: TextStyle(color: Colors.red.shade800),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: trabajo.estado.colorTextoChip.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: trabajo.estado.colorTextoChip.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade700, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pago Realizado',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Se transfirió ${FormatUtils.formatCurrency(trabajo.precio)} al postulante.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // --- Comprobante ---
          Text(
            'Comprobante de Pago',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: storageService.mostrarEvidenciasPagos(trabajo.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No se encontró el comprobante de pago.');
              }

              final String? url = snapshot.data![0]['url'];
              if (url == null) {
                return const Text('Error al cargar la imagen del comprobante.');
              }

              return Center(
                child: InkWell(
                  onTap: () => _mostrarImagenFullScreen(context, url),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 150,
                            width: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.grey, size: 40)),
                          ),
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const SizedBox(
                                      height: 150,
                                      child: Center(
                                          child: CircularProgressIndicator())),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.zoom_in_rounded,
                            color: Colors.white, size: 40),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Helper para mostrar la imagen ---
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
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(ctx).pop(),
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.3)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}