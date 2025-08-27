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
        Navigator.pushReplacementNamed(context, 'admin_home');
      } else {
        Navigator.pushReplacementNamed(context, 'home');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Ingresar'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, 'register'),
              child: const Text('Registrarse'),
            ),
          ],
        ),
      ),
    );
  }
}