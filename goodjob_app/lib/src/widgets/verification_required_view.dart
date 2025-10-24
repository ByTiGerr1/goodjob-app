import 'package:flutter/material.dart';
import 'package:goodjob_app/theme/app_colors.dart';

class VerificationRequiredView extends StatelessWidget {
  const VerificationRequiredView({
    super.key,
    required this.title,
    required this.description,
    required this.primaryButtonLabel,
    this.onPrimaryPressed,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
    this.illustrationAsset = 'assets/images/onboarding.jpg',
  });

  final String title;
  final String description;
  final String primaryButtonLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;
  final String illustrationAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(24),
              child: Image.asset(
                illustrationAsset,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimaryPressed,
                child: Text(primaryButtonLabel),
              ),
            ),
            if (onSecondaryPressed != null && secondaryButtonLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: onSecondaryPressed,
                  icon: const Icon(Icons.refresh),
                  label: Text(secondaryButtonLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}