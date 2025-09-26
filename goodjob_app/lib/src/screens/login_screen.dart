import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Auth _auth = Auth();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete todos los campos.')),
      );
      return;
    }

    try {
      await _auth.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      final uid = _auth.currentUser?.uid;
      String? role;
      if (uid != null) {
        role = await _auth.getUserRole(uid);
      }
      if (!mounted) return;
      if (role == 'admin') {
        Navigator.pushNamedAndRemoveUntil(
            context, 'admin_home', (Route<dynamic> route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, 'home', (Route<dynamic> route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Ocurrió un error. Por favor, inténtelo de nuevo.';

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            errorMessage = 'Nombre y/o contraseña incorrectos.';
            break;
          case 'invalid-email':
            errorMessage = 'El correo electrónico no es válido.';
            break;
          default:
            errorMessage = 'Error: ${e.message}';
        }
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtiene el tamaño de la pantalla para cálculos de diseño
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      // Usamos un Stack para superponer la imagen de fondo y el contenedor de botones
      body: Stack(
        children: [
          // Contenedor de la imagen de fondo. Ocupa el 60% de la pantalla.
          Positioned.fill(
            child: Container(
              height: screenHeight * 0.6,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/onboarding.jpg'), // Asegúrate de que esta sea la ruta correcta a tu imagen
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Contenedor con los campos de texto y botones, posicionado en la parte inferior de la pantalla.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              // Ajustamos el padding para el espaciado interno
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary, 
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título de la pantalla
                    const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Campos de texto
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    // Botón principal
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        child: const Text('Ingresar'),
                      ),
                    ),
                    // Botón para volver
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, 'register'),
                      child: const Text('Registrarse'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
