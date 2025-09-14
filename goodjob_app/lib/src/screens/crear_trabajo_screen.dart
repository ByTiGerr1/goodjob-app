import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'seleccionar_ubicacion_screen.dart';
import '../services/trabajo_service.dart';

class CrearTrabajoScreen extends StatefulWidget {
  const CrearTrabajoScreen({super.key});

  @override
  State<CrearTrabajoScreen> createState() => _CrearTrabajoScreenState();
}

class _CrearTrabajoScreenState extends State<CrearTrabajoScreen> {
  /// Tres formularios para las secciones: información básica,
  /// logística/pago y requisitos/contacto.
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  int _currentStep = 0;

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  final _contactoNombreController = TextEditingController();
  final _contactoNumeroController = TextEditingController();
  final Set<String> _implementosSeleccionados = {};

  final _empresaController = TextEditingController();

  final _origenDireccionCtrl = TextEditingController();
  final _origenCiudadCtrl = TextEditingController();
  final _origenPaisCtrl = TextEditingController();
  LatLng? _origenLatLng;

  final _destinoDireccionCtrl = TextEditingController();
  final _destinoCiudadCtrl = TextEditingController();
  final _destinoPaisCtrl = TextEditingController();
  LatLng? _destinoLatLng;

  DateTime? _fechaLimite;
  DateTime? _fechaTrabajo;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;

  final _precioCtrl = TextEditingController();
  final _instruccionesController =
      TextEditingController(); // Added controller for instrucciones

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _contactoNombreController.dispose();
    _contactoNumeroController.dispose();
    _origenDireccionCtrl.dispose();
    _origenCiudadCtrl.dispose();
    _origenPaisCtrl.dispose();
    _destinoDireccionCtrl.dispose();
    _destinoCiudadCtrl.dispose();
    _destinoPaisCtrl.dispose();
    _precioCtrl.dispose();
    _instruccionesController.dispose(); // Dispose instrucciones controller
    _empresaController.dispose();
    super.dispose();
  }

  Future<LatLng?> _obtenerCoords(
      String direccion, String ciudad, String pais) async {
    final query = [direccion, ciudad, pais]
        .where((e) => e.isNotEmpty)
        .join(', ');
    if (query.isEmpty) return null;
    try {
      final results = await geocoding.locationFromAddress(query);
      if (results.isNotEmpty) {
        final loc = results.first;
        return LatLng(loc.latitude, loc.longitude);
      }
    } catch (_) {}
    return null;
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
        onStepTapped: (step) => setState(() => _currentStep = step),
        steps: steps,
        controlsBuilder: (context, details) {
          final isLast = _currentStep == steps.length - 1;
          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                child: Text(isLast ? 'Publicar' : 'Siguiente'),
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
        title: const Text('Información básica'),
        isActive: _currentStep >= 0,
        content: Form(
          key: _formKeys[0],
          child: Column(
            children: [
              TextFormField(
                controller: _tituloController,
                decoration:
                    const InputDecoration(labelText: 'Nombre de trabajo'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                    labelText: 'Descripción del trabajo'),
                maxLines: 3,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _empresaController,
                decoration: const InputDecoration(labelText: 'Empresa'),
                maxLength: 30,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requerido';
                  } else if (value.length > 30) {
                    return 'Máximo 30 caracteres';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Logística y pago'),
        isActive: _currentStep >= 1,
        content: Form(
          key: _formKeys[1],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Origen', style: Theme.of(context).textTheme.titleMedium),
              TextFormField(
                controller: _origenDireccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) =>
                    _origenLatLng == null && (v == null || v.isEmpty)
                        ? 'Requerido'
                        : null,
              ),
              TextFormField(
                controller: _origenCiudadCtrl,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (v) =>
                    _origenLatLng == null && (v == null || v.isEmpty)
                        ? 'Requerido'
                        : null,
              ),
              TextFormField(
                controller: _origenPaisCtrl,
                decoration: const InputDecoration(labelText: 'País'),
                validator: (v) =>
                    _origenLatLng == null && (v == null || v.isEmpty)
                        ? 'Requerido'
                        : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_origenLatLng == null
                        ? 'Ubicación no seleccionada'
                        : 'Lat: ${_origenLatLng!.latitude.toStringAsFixed(4)}, Lng: ${_origenLatLng!.longitude.toStringAsFixed(4)}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeleccionarUbicacionScreen(
                            initialPosition: _origenLatLng ??
                                const LatLng(-33.447487, -70.673676),
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() => _origenLatLng = result);
                      }
                    },
                    child: const Text('Mapa'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final coords = await _obtenerCoords(
                        _origenDireccionCtrl.text,
                        _origenCiudadCtrl.text,
                        _origenPaisCtrl.text,
                      );
                      if (coords != null) {
                        setState(() => _origenLatLng = coords);
                      } else {
                        _showError('Dirección no encontrada');
                      }
                    },
                    child: const Text('Buscar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Destino', style: Theme.of(context).textTheme.titleMedium),
              TextFormField(
                controller: _destinoDireccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) =>
                    _destinoLatLng == null && (v == null || v.isEmpty)
                        ? 'Requerido'
                        : null,
              ),
              TextFormField(
                controller: _destinoCiudadCtrl,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: (v) =>
                    _destinoLatLng == null && (v == null || v.isEmpty)
                        ? 'Requerido'
                        : null,
              ),
              TextFormField(
                controller: _destinoPaisCtrl,
                decoration: const InputDecoration(labelText: 'País'),
                validator: (v) =>
                    _destinoLatLng == null && (v == null || v.isEmpty)
                        ? 'Requerido'
                        : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(_destinoLatLng == null
                        ? 'Ubicación no seleccionada'
                        : 'Lat: ${_destinoLatLng!.latitude.toStringAsFixed(4)}, Lng: ${_destinoLatLng!.longitude.toStringAsFixed(4)}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeleccionarUbicacionScreen(
                            initialPosition: _destinoLatLng ??
                                const LatLng(-33.447487, -70.673676),
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() => _destinoLatLng = result);
                      }
                    },
                    child: const Text('Mapa'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final coords = await _obtenerCoords(
                        _destinoDireccionCtrl.text,
                        _destinoCiudadCtrl.text,
                        _destinoPaisCtrl.text,
                      );
                      if (coords != null) {
                        setState(() => _destinoLatLng = coords);
                      } else {
                        _showError('Dirección no encontrada');
                      }
                    },
                    child: const Text('Buscar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              TextFormField(
                controller: _precioCtrl,
                decoration: const InputDecoration(labelText: 'Pago total'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Requisitos y contacto'),
        isActive: _currentStep >= 2,
        content: Form(
          key: _formKeys[2],
          child: Column(
            children: [
              TextFormField(
                controller: _contactoNombreController,
                decoration:
                    const InputDecoration(labelText: 'Nombre de contacto'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _contactoNumeroController,
                decoration: const InputDecoration(labelText: 'Número de contacto'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              ...['Implemento A', 'Implemento B', 'Implemento C']
                  .map((e) => CheckboxListTile(
                        title: Text(e),
                        value: _implementosSeleccionados.contains(e),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _implementosSeleccionados.add(e);
                          } else {
                            _implementosSeleccionados.remove(e);
                          }
                        }),
                      )),
              TextFormField(
                controller: _instruccionesController,
                decoration:
                    const InputDecoration(labelText: 'Requisitos específicos'),
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
            ],
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

  bool _direccionCompleta(TextEditingController d, TextEditingController c,
      TextEditingController p) {
    return d.text.isNotEmpty && c.text.isNotEmpty && p.text.isNotEmpty;
  }

  bool _validarDirecciones() {
    if (!_direccionCompleta(
            _origenDireccionCtrl, _origenCiudadCtrl, _origenPaisCtrl) ||
        !_direccionCompleta(
            _destinoDireccionCtrl, _destinoCiudadCtrl, _destinoPaisCtrl)) {
      return true;
    }
    return _origenPaisCtrl.text.trim().toLowerCase() ==
        _destinoPaisCtrl.text.trim().toLowerCase();
  }

  Future<void> _guardarTrabajo() async {
    for (final key in _formKeys) {
      key.currentState?.validate();
    }

    final missing = <String>[];
    if (_tituloController.text.isEmpty) missing.add('título');
    if (_descripcionController.text.isEmpty) missing.add('descripción');
    if (_empresaController.text.isEmpty) missing.add('empresa');
    if (_contactoNombreController.text.isEmpty)
      missing.add('nombre de contacto');
    if (_contactoNumeroController.text.isEmpty)
      missing.add('número de contacto');

    final origenCompleto =
        _origenLatLng != null ||
            _direccionCompleta(
                _origenDireccionCtrl, _origenCiudadCtrl, _origenPaisCtrl);
    final destinoCompleto =
        _destinoLatLng != null ||
            _direccionCompleta(
                _destinoDireccionCtrl, _destinoCiudadCtrl, _destinoPaisCtrl);
    if (!origenCompleto) missing.add('ubicación de origen');
    if (!destinoCompleto) missing.add('ubicación de destino');

    if (_fechaLimite == null) missing.add('fecha límite');
    if (_fechaTrabajo == null) missing.add('fecha del trabajo');
    if (_horaInicio == null) missing.add('hora de inicio');
    if (_horaFin == null) missing.add('hora de fin');
    if (_precioCtrl.text.isEmpty) missing.add('precio');
    if (_instruccionesController.text.isEmpty) missing.add('instrucciones');

    if (missing.isNotEmpty) {
      _showError('Complete: ${missing.join(', ')}');
      return;
    }

    if (_fechaLimite!.isAfter(_fechaTrabajo!)) {
      _showError('La fecha límite no puede ser posterior a la fecha del trabajo.');
      return;
    }
    final ini = _horaInicio!.hour * 60 + _horaInicio!.minute;
    final fin = _horaFin!.hour * 60 + _horaFin!.minute;
    if (ini >= fin) {
      _showError('La hora de inicio debe ser anterior a la de fin.');
      return;
    }

    if (!_validarDirecciones()) {
      _showError('Las direcciones deben pertenecer al mismo país.');
      return;
    }

    if (_origenLatLng == null) {
      _origenLatLng = await _obtenerCoords(
          _origenDireccionCtrl.text,
          _origenCiudadCtrl.text,
          _origenPaisCtrl.text);
    }
    if (_destinoLatLng == null) {
      _destinoLatLng = await _obtenerCoords(
          _destinoDireccionCtrl.text,
          _destinoCiudadCtrl.text,
          _destinoPaisCtrl.text);
    }

    final servicio = TrabajoService();
    try {
      await servicio.crearTrabajo(
        titulo: _tituloController.text,
        descripcion: _descripcionController.text,
        empresa: _empresaController.text,
        origen: {
          'direccion': _origenDireccionCtrl.text,
          'ciudad': _origenCiudadCtrl.text,
          'pais': _origenPaisCtrl.text,
          if (_origenLatLng != null) ...{
            'lat': _origenLatLng!.latitude,
            'lng': _origenLatLng!.longitude,
          },
        },
        destino: {
          'direccion': _destinoDireccionCtrl.text,
          'ciudad': _destinoCiudadCtrl.text,
          'pais': _destinoPaisCtrl.text,
          if (_destinoLatLng != null) ...{
            'lat': _destinoLatLng!.latitude,
            'lng': _destinoLatLng!.longitude,
          },
        },
        fechaLimite: _fechaLimite!,
        fechaTrabajo: _fechaTrabajo!,
        horaInicio: _horaInicio!,
        horaFin: _horaFin!,
        precio: double.tryParse(_precioCtrl.text) ?? 0,
        instrucciones: _instruccionesController.text,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Trabajo guardado')));
      Navigator.pop(context);
    } catch (e) {
      _showError('Error al guardar: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}