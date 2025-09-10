import 'package:flutter/material.dart';

class AdminPagosScreen extends StatelessWidget {
  const AdminPagosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GOODS')),
      body: const Center(child: Text('Mis pagos')),
    );
  }
}