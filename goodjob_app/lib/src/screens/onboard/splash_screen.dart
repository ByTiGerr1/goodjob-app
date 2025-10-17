import 'package:flutter/material.dart';
import 'dart:async'; // Necesario para usar Timer

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Inicia un temporizador para la navegación automática
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Navega a la pantalla de beneficios después del tiempo de espera
        Navigator.pushReplacementNamed(context, 'benefit_slides');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Usa el color principal definido en tu ThemeData para el fondo
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: primaryColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Asegúrate de que tu logo esté en esta ruta de assets
              Image.asset("assets/images/logo.png", height: 120),
              const SizedBox(height: 48.0),
              // Opcional: puedes añadir un indicador de carga si la inicialización es más larga
              // const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
