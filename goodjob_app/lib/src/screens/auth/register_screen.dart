import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/firebase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _rutController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _regionController = TextEditingController();
  final _streetController = TextEditingController();
  final _streetNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  DateTime? _selectedBirthDate;
  bool _termsAccepted = false;
  final Auth _auth = Auth();

  int _currentStep = 0;
  final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro'];
  final List<String> _nationalityOptions = [
    'Chile',
    'Venezuela',
    'Perú',
    'Colombia',
    'Bolivia',
    'Argentina',
    'Ecuador',
    'Haití',
    'Afganistán',
    'Brasil',
    'Estados Unidos',
    'España',
    'México',
    'Uruguay',
    'Paraguay',
  ];
  String? _selectedGender;
  String? _selectedNationality;
  bool _hasDisability = false;

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _rutController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _streetController.dispose();
    _streetNumberController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final formState = _formKeys[_currentStep].currentState;
    if (formState != null && formState.validate()) {
      formState.save();
      setState(() {
        if (_currentStep < _formKeys.length - 1) {
          _currentStep++;
        }
      });
    }
  }

  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  Future<void> _register() async {
    final formState = _formKeys[_currentStep].currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final confirmEmail = _confirmEmailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || confirmEmail.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete todos los campos requeridos.')),
      );
      return;
    }
    if (email != confirmEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Los correos electrónicos no coinciden.')),
      );
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un correo válido.')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe aceptar los términos y condiciones.')),
      );
      return;
    }

    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, seleccione su fecha de nacimiento.')),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, seleccione su género.')),
      );
      return;
    }

    if (_selectedNationality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, seleccione su nacionalidad.')),
      );
      return;
    }

    try {
      await _auth.registerUserWithDetails(
        email: email,
        password: password,
        name: _nameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        rut: _rutController.text.trim(),
        birthDate: _selectedBirthDate!,
        phoneNumber: _phoneController.text.trim(),
        gender: _selectedGender!,
        nationality: _selectedNationality!,
        hasDisability: _hasDisability,
        region: _regionController.text.trim(),
        street: _streetController.text.trim(),
        streetNumber: _streetNumberController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, 'login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar: $e')),
      );
    }
  }

  Widget _buildPersonalDataStep() {
    return Form(
      key: _formKeys[0],
      child: Column(
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
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombres'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese sus nombres';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Apellidos'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese sus apellidos';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rutController,
            decoration: const InputDecoration(labelText: 'RUT'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            validator: (value) {
              if (value == null) {
                return 'Ingrese su RUT';
              }
              final trimmed = value.trim();
              if (trimmed.isEmpty) {
                return 'Ingrese su RUT';
              }
              if (trimmed.length > 9) {
                return 'El RUT debe tener un máximo de 9 números';
              }
              final onlyDigits = trimmed.split('').every((digit) => int.tryParse(digit) != null);
              if (!onlyDigits) {
                return 'El RUT debe contener solo números';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _birthDateController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Fecha de nacimiento'),
            onTap: () async {
              FocusScope.of(context).unfocus();
              final now = DateTime.now();
              final initialDate = DateTime(now.year - 18, now.month, now.day);
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: initialDate,
                helpText: 'Seleccione su fecha de nacimiento',
                cancelText: 'Cancelar',
                confirmText: 'Aceptar',
              );
              if (pickedDate != null) {
                setState(() {
                  _selectedBirthDate = pickedDate;
                  final day = pickedDate.day.toString().padLeft(2, '0');
                  final month = pickedDate.month.toString().padLeft(2, '0');
                  _birthDateController.text = '$day/$month/${pickedDate.year}';
                });
              }
            },
            validator: (_) {
              if (_selectedBirthDate == null) {
                return 'Seleccione su fecha de nacimiento';
              }
              final today = DateTime.now();
              final adultDate = DateTime(today.year - 18, today.month, today.day);
              if (_selectedBirthDate!.isAfter(adultDate)) {
                return 'Debe ser mayor de 18 años';
              }
              return null;
            },
            
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Número de teléfono'),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9+]')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese su número de teléfono';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: const InputDecoration(labelText: 'Género'),
            items: _genderOptions.map((value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedGender = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Seleccione su género';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedNationality,
            decoration: const InputDecoration(labelText: 'Nacionalidad'),
            items: _nationalityOptions.map((value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedNationality = newValue;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Seleccione su nacionalidad';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _hasDisability,
            onChanged: (value) {
              setState(() {
                _hasDisability = value ?? false;
              });
            },
            title: const Text(
              '¿Cuenta con alguna discapacidad?',
              style: TextStyle(color: Colors.white70),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).colorScheme.secondary,
            checkColor: Theme.of(context).colorScheme.onSecondary,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              child: const Text('Siguiente'),
            ),
          ),
          // Botón para volver
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, 'login'),
            child: const Text('Iniciar Sesión'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return Form(
      key: _formKeys[1],
      child: Column(
        children: [
          const Text(
            'Dirección',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _regionController,
            decoration: const InputDecoration(labelText: 'Región'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese su región';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _streetController,
            decoration: const InputDecoration(labelText: 'Calle'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese su calle';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _streetNumberController,
            decoration: const InputDecoration(labelText: 'Número'),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese el número de su domicilio';
              }
              return null;
            },
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
      ),
    );
  }

  Widget _buildAccountDataStep() {
    return Form(
      key: _formKeys[2],
      child: Column(
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
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Correo'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese su correo';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Ingrese un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmEmailController,
            decoration: const InputDecoration(labelText: 'Repetir Correo'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Repita su correo';
              }
              if (value.trim() != _emailController.text.trim()) {
                return 'Los correos electrónicos no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingrese su contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(labelText: 'Confirmar Contraseña'),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirme su contraseña';
              }
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
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
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalDataStep();
      case 1:
        return _buildAddressStep();
      case 2:
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
                  image: AssetImage('assets/images/onboarding.jpg'),
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