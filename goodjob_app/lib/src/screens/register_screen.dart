import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers para cada campo de texto
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _rutController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _activityController = TextEditingController();
  final _careerController = TextEditingController();
  final _aboutYouController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _siiAcceptedController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _accountType;
  bool _termsAccepted = false;
  final Auth _auth = Auth();

  // Variables de estado para el formulario de varios pasos
  int _currentStep = 0;
  final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro'];
  final List<String> _activityOptions = ['Estudiante', 'Trabajador', 'Independiente', 'Desempleado'];
  String? _selectedGender;
  String? _selectedActivity;
  bool _siiStarted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _rutController.dispose();
    _birthDateController.dispose();
    _genderController.dispose();
    _nationalityController.dispose();
    _activityController.dispose();
    _careerController.dispose();
    _aboutYouController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _siiAcceptedController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Lógica para avanzar de paso en el formulario
  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  // Lógica para retroceder de paso en el formulario
  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  Future<void> _register() async {
    // Validaciones de datos
    final email = _emailController.text.trim();
    final confirmEmail = _confirmEmailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || confirmEmail.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, complete todos los campos requeridos.')));
      return;
    }
    if (email != confirmEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los correos electrónicos no coinciden.')));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden.')));
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe aceptar los términos y condiciones.')));
      return;
    }

    try {
      await _auth.registerUserWithOptionalData(
        email: email,
        password: password,
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        lastName: _lastNameController.text.trim().isNotEmpty ? _lastNameController.text.trim() : null,
        rut: _rutController.text.trim().isNotEmpty ? _rutController.text.trim() : null,
        birthDate: _birthDateController.text.trim().isNotEmpty ? _birthDateController.text.trim() : null,
        gender: _selectedGender,
        nationality: _nationalityController.text.trim().isNotEmpty ? _nationalityController.text.trim() : null,
        activity: _selectedActivity,
        career: _careerController.text.trim().isNotEmpty ? _careerController.text.trim() : null,
        aboutYou: _aboutYouController.text.trim().isNotEmpty ? _aboutYouController.text.trim() : null,
        bankName: _bankNameController.text.trim().isNotEmpty ? _bankNameController.text.trim() : null,
        accountType: _accountType,
        bankAccountNumber: _bankAccountNumberController.text.trim().isNotEmpty ? _bankAccountNumberController.text.trim() : null,
        siiStarted: _siiStarted
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e')));
    }
  }

  // Widget para la sección 1: Datos Personales
  Widget _buildPersonalDataStep() {
    return Column(
      children: [
        const Text(
          'Datos Personales',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _lastNameController,
          decoration: const InputDecoration(labelText: 'Apellido'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rutController,
          decoration: const InputDecoration(labelText: 'RUT'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _birthDateController,
          decoration: const InputDecoration(labelText: 'Fecha de Nacimiento'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextStep,
            child: const Text('Siguiente'),
          ),
        ),
        TextButton(
          onPressed: _nextStep,
          child: const Text('Omitir', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  // Widget para la sección 2: Datos Personales Extras
  Widget _buildExtraPersonalDataStep() {
    return Column(
      children: [
        const Text(
          'Datos Personales Extras',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: const InputDecoration(labelText: 'Género'),
          items: _genderOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nationalityController,
          decoration: const InputDecoration(labelText: 'Nacionalidad'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedActivity,
          decoration: const InputDecoration(labelText: 'Actividad'),
          items: _activityOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedActivity = newValue;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _careerController,
          decoration: const InputDecoration(labelText: 'Carrera (si corresponde)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _aboutYouController,
          decoration: const InputDecoration(labelText: 'Sobre ti (descripción)'),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextStep,
            child: const Text('Siguiente'),
          ),
        ),
        TextButton(
          onPressed: _previousStep,
          child: const Text('Atrás', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  // Widget para la sección 3: Datos Bancarios
  Widget _buildBankDataStep() {
    return Column(
      children: [
        const Text(
          'Datos Bancarios',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _bankNameController,
          decoration: const InputDecoration(labelText: 'Banco'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _accountType,
          decoration: const InputDecoration(labelText: 'Tipo de Cuenta'),
          items: const [
            DropdownMenuItem(value: 'Cuenta Corriente', child: Text('Cuenta Corriente')),
            DropdownMenuItem(value: 'Cuenta Vista', child: Text('Cuenta Vista')),
            DropdownMenuItem(value: 'Cuenta de Ahorro', child: Text('Cuenta de Ahorro')),
          ],
          onChanged: (value) {
            setState(() {
              _accountType = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bankAccountNumberController,
          decoration: const InputDecoration(labelText: 'Número de Cuenta'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('¿Has iniciado actividades en el SII?',
                style: TextStyle(color: Colors.white70)),
            const Spacer(),
            Switch(
              value: _siiStarted,
              onChanged: (value) {
                setState(() {
                  _siiStarted = value;
                });
              },
              activeColor: Theme.of(context).colorScheme.secondary,
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextStep,
            child: const Text('Siguiente'),
          ),
        ),
        TextButton(
          onPressed: () {
            _nextStep();
          },
          child: const Text('Omitir', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _previousStep,
          child: const Text('Atrás', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  // Widget para la sección 4: Datos de Cuenta
  Widget _buildAccountDataStep() {
    return Column(
      children: [
        const Text(
          'Datos de la Cuenta',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmEmailController,
          decoration: const InputDecoration(labelText: 'Repetir Correo'),
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _register,
            child: const Text('Crear Cuenta'),
          ),
        ),
        TextButton(
          onPressed: _previousStep,
          child: const Text('Atrás', style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, 'login'),
          child: const Text('Iniciar Sesión'),
        ),
      ],
    );
  }

  // Widget para mostrar el paso actual del formulario
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalDataStep();
      case 1:
        return _buildExtraPersonalDataStep();
      case 2:
        return _buildBankDataStep();
      case 3:
        return _buildAccountDataStep();
      default:
        return _buildAccountDataStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/monachina.webp'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: _buildCurrentStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}