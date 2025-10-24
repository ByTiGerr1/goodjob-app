import 'package:flutter/material.dart';

import 'package:goodjob_app/theme/app_colors.dart';

/// Muestra un cuadro de diálogo de confirmación para cerrar sesión con
/// la estética y colores de la aplicación. Devuelve `true` si el usuario
/// confirma que desea cerrar sesión.
Future<bool> showLogoutConfirmationDialog(BuildContext context) async {
  final bool? shouldLogout = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.backgroundLight,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.logout,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Deseas cerrar sesión?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Al cerrar sesión saldrás de tu cuenta actual. Podrás volver a ' 
          'ingresar cuando lo necesites.',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppColors.textDark,
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.cancelColor,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Cerrar sesión'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ],
      );
    },
  );

  return shouldLogout ?? false;
}
