import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _BankController = TextEditingController();
  final _accountNumberController = TextEditingController();
  String? _accountType; // para seleccionar tipos de cuentas
  bool _termsAccepted = false;
  final Auth _auth = Auth();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _BankController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final bank = _BankController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountType = _accountType;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || bank.isEmpty || accountNumber.isEmpty || accountType == null ) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, complete todos los campos')));
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Debe aceptar los términos y condiciones')));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }
    try {
      await _auth.registerUser(name, email, password);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
                  image: AssetImage('assets/images/monachina.webp'), // Asegúrate de que esta sea la ruta correcta a tu imagen
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
                      'Crea tu cuenta',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Campos de texto
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Correo'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(labelText: 'Confirmar Contraseña'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _BankController,
                      decoration: const InputDecoration(labelText: 'Banco'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(labelText: 'Número de cuenta'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _accountType,
                      decoration: const InputDecoration(labelText: 'Tipo de Cuenta'),
                      items: const [
                        DropdownMenuItem(value: 'Cuenta Corriente',  child: Text('Cuenta Corriente')),
                        DropdownMenuItem(value: 'Cuenta Vista', child: Text('Cuenta Vista')),
                        DropdownMenuItem(value: 'Cuenta de ahorro',child: Text('Cuenta de Ahorro')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _accountType = value;
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                          // El color del Checkbox se ajusta aquí manualmente
                          checkColor: Theme.of(context).colorScheme.onSecondary,
                          activeColor: Theme.of(context).colorScheme.secondary,
                        ),
                        const Expanded(
                          child: Text(
                            'Acepto los términos y condiciones',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Botón principal
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _register,
                        child: const Text('Crear Cuenta'),
                      ),
                    ),
                    // Botón para volver
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, 'home'),
                      child: const Text('Iniciar Sesión'),
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
