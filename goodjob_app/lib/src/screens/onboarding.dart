import 'package:flutter/material.dart';
import 'dart:async'; // Importar la librería para usar Timer

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    // Iniciar un temporizador que, después de 3 segundos, navega a la siguiente pantalla
    Timer(const Duration(seconds: 3), () {
      // Usar pushReplacementNamed para reemplazar la ruta actual
      // y evitar que el usuario pueda volver a la pantalla de bienvenida con el botón de retroceso
      Navigator.pushReplacementNamed(context, 'welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: primaryColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset("assets/images/logo.png", height: 120),
              const SizedBox(height: 48.0),
            ],
          ),
        ),
      ),
    );
  }
}
