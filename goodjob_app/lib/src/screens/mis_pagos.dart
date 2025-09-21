import 'package:flutter/material.dart';

import '../services/user_eligibility_service.dart';
import '../widgets/user_eligibility_gate.dart';
import '../widgets/verification_required_view.dart';
import 'account_verification_screen.dart';
import 'login_screen.dart';

class MisPagosScreen extends StatefulWidget {
  const MisPagosScreen({super.key});

  @override
  State<MisPagosScreen> createState() => _MisPagosScreenState();
}

class _MisPagosScreenState extends State<MisPagosScreen> {
  void _navigateAndRefresh(
    BuildContext context,
    Widget screen,
    Future<void> Function() refresh,
  ) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (!mounted) return;
      refresh();
    });
  }

  Widget _buildEligibilityNotice(
    BuildContext context,
    UserEligibilityStatus status,
    Future<void> Function() refresh,
  ) {
    final authenticated = status.isAuthenticated;
    final description = status.messageForAction('consultar tus pagos');
    final primaryLabel =
        authenticated ? 'Terminar registro' : 'Iniciar sesión';

    return VerificationRequiredView(
      title: 'Termina tu registro',
      description: description,
      primaryButtonLabel: primaryLabel,
      onPrimaryPressed: () {
        if (authenticated) {
          _navigateAndRefresh(
            context,
            const AccountVerificationScreen(),
            refresh,
          );
        } else {
          _navigateAndRefresh(
            context,
            const LoginScreen(),
            refresh,
          );
        }
      },
      secondaryButtonLabel:
          authenticated ? 'Ya completé mi registro' : null,
      onSecondaryPressed: authenticated ? () => refresh() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: UserEligibilityGate(
        eligibleBuilder: (context, status, refresh) {
          return Center(
            child: Text(
              'Aquí podrás revisar tus pagos cuando estén disponibles.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          );
        },
        blockedBuilder: _buildEligibilityNotice,
      ),
    );
  }
}