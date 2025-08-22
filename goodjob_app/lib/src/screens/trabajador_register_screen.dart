import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class TrabajadorRegisterScreen extends StatefulWidget {
  const TrabajadorRegisterScreen({super.key});

  @override
  State<TrabajadorRegisterScreen> createState() => _TrabajadorRegisterScreenState();
}

class _TrabajadorRegisterScreenState extends State<TrabajadorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  final Auth _auth= Auth();

   Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _auth.registerUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Usuario registrado correctamente")),
      );

      // Limpiar campos después de registro exitoso
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      // Redirigir al login
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Error al registrar';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro de Usuario")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nombre"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu nombre';
                  }
                  if (value.length < 3) {
                    return 'Debe tener al menos 3 caracteres';
                  }
                  if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(value)) {
                    return 'Solo letras y espacios permitidos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu email';
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Email no válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Contraseña"),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu contraseña';
                  }
                  if (value.length < 6) {
                    return 'Debe tener al menos 6 caracteres';
                  }
                  if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$')
                      .hasMatch(value)) {
                    return 'Debe incluir mayúscula, minúscula y número';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 10),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      child: const Text("Registrarse"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

