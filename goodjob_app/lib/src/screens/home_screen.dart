import 'package:flutter/material.dart';
import 'trabajos_screen.dart';
import 'mis_trabajos_screen.dart';
import 'mis_pagos.dart';
import 'configuracion/configuracion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TrabajosScreen(),
    MisTrabajosScreen(),
    MisPagosScreen(),
    ConfiguracionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Trabajos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Mis trabajos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payment), label: 'Mis pagos'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}