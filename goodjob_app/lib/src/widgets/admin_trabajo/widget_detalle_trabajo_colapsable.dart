import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart';
import 'package:goodjob_app/src/utils/format_utils.dart';

class DetalleTrabajoColapsable extends StatefulWidget {
  final Trabajo trabajo;
  const DetalleTrabajoColapsable({super.key, required this.trabajo});

  @override
  State<DetalleTrabajoColapsable> createState() =>
      _DetalleTrabajoColapsableState();
}

class _DetalleTrabajoColapsableState extends State<DetalleTrabajoColapsable>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _iconAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceVariant,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpand,
            splashColor: colorScheme.primary.withOpacity(0.1),
            highlightColor: colorScheme.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Detalles del Trabajo',
                      // --- MEJORA: Título más grande ---
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconAnimation,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? _buildExpandedContent(context, colorScheme)
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          _InfoSection(
            icon: Icons.description_outlined,
            title: 'Descripción del Servicio',
            child: Text(
              widget.trabajo.descripcion.isEmpty
                  ? 'Sin descripción.'
                  : widget.trabajo.descripcion,
              // --- MEJORA: Color de texto principal ---
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface, // No 'onSurfaceVariant'
                  ),
            ),
          ),
          const SizedBox(height: 24),
          _InfoSection(
            icon: Icons.list_alt_outlined,
            title: 'Detalles de Ejecución',
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  text: widget.trabajo.ubicacion['direccion'] ?? 'N/A',
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text:
                      'Inicia: ${FormatUtils.formatDate(widget.trabajo.fechaInicioTrabajo)}',
                ),
                _InfoRow(
                  icon: Icons.flag_outlined,
                  text:
                      'Finaliza: ${FormatUtils.formatDate(widget.trabajo.fechaFinTrabajo)}',
                ),
                if (widget.trabajo.estado != EstadoTrabajo.cancelado &&
                    widget.trabajo.estado != EstadoTrabajo.rechazado) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.attach_money_outlined,
                    text: FormatUtils.formatCurrency(widget.trabajo.precio),
                    isHighlighted: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPERS (Mejorados) ---

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: child
          ),
        ],
      ),
    );
  }
}

// --- WIDGET _InfoRow MEJORADO ---
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isHighlighted;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = colorScheme.onSurfaceVariant;

    // --- MEJORA: Lógica de RichText ---
    String label = '';
    String value = text;
    final splitIndex = text.indexOf(':');

    // Si encontramos ':', separamos el texto
    if (splitIndex != -1 && !isHighlighted) {
      label = text.substring(0, splitIndex + 1); // "Inicia: "
      value = text.substring(splitIndex + 1).trim(); // "27/10/2025"
    }

    // Estilo para la etiqueta (ej: "Inicia:")
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant, // Color sutil
      height: 1.4,
    );
    
    // Estilo para el valor (ej: "27/10/2025")
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface, // Color principal
      fontWeight: FontWeight.w500,  // Peso "Medium" para darle énfasis
      height: 1.4,
    );

    // Estilo para el precio (destacado)
    final highlightedStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.bold,
      height: 1.4,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: labelStyle, // Estilo por defecto (el de la etiqueta)
                children: [
                  // Si hay etiqueta (y no está destacado), la mostramos
                  if (label.isNotEmpty)
                    TextSpan(text: '$label '), // Añadimos espacio
                  
                  // El valor siempre se muestra, con su estilo correspondiente
                  TextSpan(
                    text: value,
                    style: isHighlighted ? highlightedStyle : valueStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}