import 'package:flutter/material.dart';

import '../services/user_eligibility_service.dart';

typedef EligibilityViewBuilder = Widget Function(
  BuildContext context,
  UserEligibilityStatus status,
  Future<void> Function() refresh,
);

class UserEligibilityGate extends StatefulWidget {
  const UserEligibilityGate({
    super.key,
    required this.eligibleBuilder,
    required this.blockedBuilder,
    this.loadingBuilder,
    this.service,
  });

  final EligibilityViewBuilder eligibleBuilder;
  final EligibilityViewBuilder blockedBuilder;
  final WidgetBuilder? loadingBuilder;
  final UserEligibilityService? service;

  @override
  State<UserEligibilityGate> createState() => _UserEligibilityGateState();
}

class _UserEligibilityGateState extends State<UserEligibilityGate> {
  late UserEligibilityService _service;
  late Future<UserEligibilityStatus> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? UserEligibilityService();
    _future = _service.fetchStatus();
  }

  Future<void> _refresh() async {
    final future = _service.fetchStatus();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserEligibilityStatus>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(context);
          }
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return widget.blockedBuilder(
            context,
            const UserEligibilityStatus(
              isEligible: false,
              isAuthenticated: true,
              emailVerified: false,
              hasBankDetails: false,
              errorMessage:
                  'No pudimos validar tu cuenta. Intenta nuevamente en unos minutos.',
            ),
            _refresh,
          );
        }

        final status = snapshot.data ??
            const UserEligibilityStatus(
              isEligible: false,
              isAuthenticated: true,
              emailVerified: false,
              hasBankDetails: false,
              errorMessage:
                  'No pudimos validar tu cuenta. Intenta nuevamente en unos minutos.',
            );

        if (status.isEligible) {
          return widget.eligibleBuilder(context, status, _refresh);
        }

        return widget.blockedBuilder(context, status, _refresh);
      },
    );
  }
}