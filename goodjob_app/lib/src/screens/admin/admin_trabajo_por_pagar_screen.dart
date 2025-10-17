import 'package:flutter/material.dart';

class AdminTrabajoPorPagarScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;

  const AdminTrabajoPorPagarScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
    });

  @override
  State<AdminTrabajoPorPagarScreen> createState() => _AdminTrabajoPorPagarScreenState();
}

class _AdminTrabajoPorPagarScreenState extends State<AdminTrabajoPorPagarScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}