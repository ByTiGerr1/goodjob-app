import 'package:flutter/material.dart';
import '../services/trabajo_service.dart';

class CrearTrabajoScreen extends StatefulWidget {
  const CrearTrabajoScreen({super.key});

  @override
  State<CrearTrabajoScreen> createState() => _CrearTrabajoScreenState();
}

class _CrearTrabajoScreenState extends State<CrearTrabajoScreen> {
  final _formKeys = List.generate(6, (_) => GlobalKey<FormState>());
  int _currentStep = 0;

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  String? _empresa;

  final _origenDireccionCtrl = TextEditingController();
  final _origenCiudadCtrl = TextEditingController();
  final _origenPaisCtrl = TextEditingController();

  final _destinoDireccionCtrl = TextEditingController();
  final _destinoCiudadCtrl = TextEditingController();
  final _destinoPaisCtrl = TextEditingController();

  DateTime? _fechaLimite;
  DateTime? _fechaTrabajo;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;

  final _precioCtrl = TextEditingController();
  final _instruccionesController = TextEditingController(); // Added controller for instrucciones

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _origenDireccionCtrl.dispose();
    _origenCiudadCtrl.dispose();
    _origenPaisCtrl.dispose();
    _destinoDireccionCtrl.dispose();
    _destinoCiudadCtrl.dispose();
    _destinoPaisCtrl.dispose();
    _precioCtrl.dispose();
    _instruccionesController.dispose(); // Dispose instrucciones controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Trabajo')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        onStepCancel: _previousStep,
        steps: steps,
        controlsBuilder: (context, details) {
          final isLast = _currentStep == steps.length - 1;
          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text(isLast ? 'Guardar' : 'Siguiente'),
              ),
              const SizedBox(width: 8),
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Atrás'),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Step> _buildSteps(BuildContext context) {
    return [
      Step(
        title: const Text('Detalles'),
        isActive: _currentStep >= 0,
        content: Form(
          key: _formKeys[0],
          child: Column(
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Empresa'),
        isActive: _currentStep >= 1,
        content: Form(
          key: _formKeys[1],
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Empresa'),
            initialValue: _empresa,
            items: const [
              DropdownMenuItem(value: 'Empresa A', child: Text('Empresa A')),
              DropdownMenuItem(value: 'Empresa B', child: Text('Empresa B')),
            ],
            onChanged: (value) => setState(() => _empresa = value),
            validator: (value) =>
                value == null ? 'Seleccione una empresa' : null,
          ),
        ),
      ),
      Step(
        title: const Text('Ubicaciones'),
        isActive: _currentStep >= 2,
        content: Form(
          key: _formKeys[2],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Origen', style: Theme.of(context).textTheme.titleMedium),
              TextFormField(
                controller: _origenDireccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _origenCiudadCtrl,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _origenPaisCtrl,
                decoration: const InputDecoration(labelText: 'País'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              Text('Destino', style: Theme.of(context).textTheme.titleMedium),
              TextFormField(
                controller: _destinoDireccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _destinoCiudadCtrl,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _destinoPaisCtrl,
                decoration: const InputDecoration(labelText: 'País'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Fechas y horario'),
        isActive: _currentStep >= 3,
        content: Form(
          key: _formKeys[3],
          child: Column(
            children: [
              _buildDatePicker(
                label: 'Fecha límite de postulación',
                value: _fechaLimite,
                onPicked: (d) => setState(() => _fechaLimite = d),
              ),
              _buildDatePicker(
                label: 'Fecha del trabajo',
                value: _fechaTrabajo,
                onPicked: (d) => setState(() => _fechaTrabajo = d),
              ),
              _buildTimePicker(
                label: 'Hora de inicio',
                value: _horaInicio,
                onPicked: (t) => setState(() => _horaInicio = t),
              ),
              _buildTimePicker(
                label: 'Hora de fin',
                value: _horaFin,
                onPicked: (t) => setState(() => _horaFin = t),
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Pago'),
        isActive: _currentStep >= 4,
        content: Form(
          key: _formKeys[4],
          child: TextFormField(
            controller: _precioCtrl,
            decoration: const InputDecoration(labelText: 'Precio'),
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
        ),
      ),
      Step(
        title: const Text('Instrucciones'),
        isActive: _currentStep >= 5,
        content: Form(
          key: GlobalKey<FormState>(),
          child: TextFormField(
            controller: _instruccionesController,
            decoration: const InputDecoration(labelText: 'Instrucciones'),
            maxLines: 3,
            maxLength: 1000,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Requerido';
              } else if (value.length > 1000) {
                return 'Máximo 1000 caracteres';
              }
              return null;
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
  }) {
    final text = value == null
        ? label
        : '$label: ${value.day}/${value.month}/${value.year}';
    return Row(
      children: [
        Expanded(child: Text(text)),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              onPicked(picked);
            }
          },
          child: const Text('Seleccionar'),
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay> onPicked,
  }) {
    final text =
        value == null ? label : '$label: ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Expanded(child: Text(text)),
        TextButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              onPicked(picked);
            }
          },
          child: const Text('Seleccionar'),
        ),
      ],
    );
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < _formKeys.length - 1) {
      setState(() => _currentStep += 1);
    } else {
      _guardarTrabajo();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  bool _validateStep(int step) {
    final form = _formKeys[step].currentState;
    if (form != null && !form.validate()) return false;
    if (step == 3) {
      if (_fechaLimite == null || _fechaTrabajo == null) {
        _showError('Seleccione las fechas.');
        return false;
      }
      if (_fechaLimite!.isAfter(_fechaTrabajo!)) {
        _showError(
            'La fecha límite no puede ser posterior a la fecha del trabajo.');
        return false;
      }
      if (_horaInicio == null || _horaFin == null) {
        _showError('Seleccione horas válidas.');
        return false;
      }
      final ini = _horaInicio!.hour * 60 + _horaInicio!.minute;
      final fin = _horaFin!.hour * 60 + _horaFin!.minute;
      if (ini >= fin) {
        _showError('La hora de inicio debe ser anterior a la de fin.');
        return false;
      }
    }
    return true;
  }

  bool _validarDirecciones() {
    if (_origenPaisCtrl.text.isEmpty || _destinoPaisCtrl.text.isEmpty) {
      return false;
    }
    return _origenPaisCtrl.text.trim().toLowerCase() ==
        _destinoPaisCtrl.text.trim().toLowerCase();
  }

  void _guardarTrabajo() {
    for (final key in _formKeys) {
      final form = key.currentState;
      if (form != null && !form.validate()) return;
    }
    if (!_validarDirecciones()) {
      _showError('Las direcciones deben pertenecer al mismo país.');
      return;
    }

    final servicio = TrabajoService();
    servicio.crearTrabajo(
      titulo: _tituloController.text,
      descripcion: _descripcionController.text,
      empresa: _empresa!,
      origen: {
        'direccion': _origenDireccionCtrl.text,
        'ciudad': _origenCiudadCtrl.text,
        'pais': _origenPaisCtrl.text,
      },
      destino: {
        'direccion': _destinoDireccionCtrl.text,
        'ciudad': _destinoCiudadCtrl.text,
        'pais': _destinoPaisCtrl.text,
      },
      fechaLimite: _fechaLimite!,
      fechaTrabajo: _fechaTrabajo!,
      horaInicio: _horaInicio!,
      horaFin: _horaFin!,
      precio: double.tryParse(_precioCtrl.text) ?? 0,
      instrucciones: _instruccionesController.text, // Added instrucciones
    ).then((_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Trabajo guardado')));
      Navigator.pop(context);
    }).catchError((e) {
      _showError('Error al guardar: $e');
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
