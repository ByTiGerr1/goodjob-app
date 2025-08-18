import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ColoredBox(color: Colors.red, child: Center(child: Text('Página 1'))),
    ColoredBox(color: Colors.green, child: Center(child: Text('Página 2'))),
    ColoredBox(color: Colors.blue, child: Center(child: Text('Página 3'))),
    ColoredBox(color: Colors.orange, child: Center(child: Text('Página 4'))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 4),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.looks_one), label: 'Rojo'),
            BottomNavigationBarItem(icon: Icon(Icons.looks_two), label: 'Verde'),
            BottomNavigationBarItem(icon: Icon(Icons.looks_3), label: 'Azul'),
            BottomNavigationBarItem(icon: Icon(Icons.looks_4), label: 'Naranja'),
          ],
        ),
      ),
    );
  }
}
