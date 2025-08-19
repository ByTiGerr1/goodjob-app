import 'package:flutter/material.dart';

class TrabajosScreen extends StatelessWidget {
  const TrabajosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajos')),
      body: const Center(child: Text('Trabajos')),
    );
  }
}