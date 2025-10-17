import 'package:flutter/material.dart';

class AdminTrabajoPorRevisarScreen extends StatefulWidget {
  final String trabajoId;
  final Map<String, dynamic> trabajo;
  
  const AdminTrabajoPorRevisarScreen({
    super.key,
    required this.trabajoId,
    required this.trabajo,
    });

  @override
  State<AdminTrabajoPorRevisarScreen> createState() => _AdminTrabajoPorRevisarScreenState();
}

class _AdminTrabajoPorRevisarScreenState extends State<AdminTrabajoPorRevisarScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}