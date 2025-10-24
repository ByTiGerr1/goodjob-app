import 'package:flutter/material.dart';

import 'package:goodjob_app/theme/app_colors.dart';

/// Muestra un diálogo de confirmación con la estética de la aplicación para
/// confirmar la eliminación permanente de la cuenta del usuario.
Future<bool> showDeleteAccountConfirmationDialog(BuildContext context) async {
  final bool? shouldDelete = await showDialog<bool>(
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
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Eliminar tu cuenta?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Esta acción eliminará tu cuenta y todos tus datos de forma '
          'permanente. No podrás recuperar la información luego de continuar.',
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
              backgroundColor: AppColors.error,
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
                Text('Eliminar definitivamente'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ],
      );
    },
  );

  return shouldDelete ?? false;
}