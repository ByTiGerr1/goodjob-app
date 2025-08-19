import 'package:flutter/material.dart';

class MisTrabajosScreen extends StatelessWidget {
  const MisTrabajosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis trabajos')),
      body: const Center(child: Text('Mis trabajos')),
    );
  }
}