import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'seleccionar_ubicacion_screen.dart'; // Asumiendo que existe
import '../services/trabajo_service.dart'; // Asumiendo que existe

class CrearTrabajoScreen extends StatefulWidget {
  const CrearTrabajoScreen({super.key});

  @override
  State<CrearTrabajoScreen> createState() => _CrearTrabajoScreenState();
}

class _CrearTrabajoScreenState extends State<CrearTrabajoScreen> {
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  int _currentStep = 0;

  // Paso 1: Información básica
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _empresaController = TextEditingController();

  // Paso 2: Logística y pago
  final _ubicacionDireccionCtrl = TextEditingController();
  final _ubicacionCiudadCtrl = TextEditingController();
  final _ubicacionPaisCtrl = TextEditingController();
  LatLng? _ubicacionLatLng;

  DateTime? _fechaTrabajo;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  final _precioCtrl = TextEditingController();

  // Paso 3: Requisitos y contacto
  final _contactoNombreController = TextEditingController();
  final _contactoNumeroController = TextEditingController();
  bool _requiereUniforme = false;
  final Set<String> _implementosSeleccionados = {};
  final _instruccionesController = TextEditingController();

  // Colores del tema
  late Color _primaryColor;
  late Color _secondaryColor;
  late Color _errorColor;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _contactoNombreController.dispose();
    _contactoNumeroController.dispose();
    _ubicacionDireccionCtrl.dispose();
    _ubicacionCiudadCtrl.dispose();
    _ubicacionPaisCtrl.dispose();
    _precioCtrl.dispose();
    _instruccionesController.dispose();
    _empresaController.dispose();
    super.dispose();
  }
  
  // --- LÓGICA DE GEOLOCALIZACIÓN ---

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
    } catch (_) {
      // Manejar error de geocodificación
    }
    return null;
  }

  // --- NAVEGACIÓN Y VALIDACIÓN ---

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateStep(int step) {
    // 1. Validar el formulario actual
    if (!_formKeys[step].currentState!.validate()) {
      return false;
    }

    // 2. Validaciones específicas (Paso 2: Logística)
    if (step == 1) {
      final hasAddress = _ubicacionDireccionCtrl.text.isNotEmpty && _ubicacionCiudadCtrl.text.isNotEmpty;
      
      if (_ubicacionLatLng == null && !hasAddress) {
        _showError('Debe ingresar una dirección completa o seleccionarla en el mapa.');
        return false;
      }
      if (_fechaTrabajo == null) {
        _showError('Debe seleccionar la fecha del trabajo.');
        return false;
      }
      if (_horaInicio == null || _horaFin == null) {
        _showError('Debe seleccionar la hora de inicio y fin.');
        return false;
      }
      final ini = _horaInicio!.hour * 60 + _horaInicio!.minute;
      final fin = _horaFin!.hour * 60 + _horaFin!.minute;
      if (ini >= fin) {
        _showError('La hora de inicio debe ser anterior a la de fin.');
        return false;
      }
    }
    
    // 3. Validaciones específicas (Paso 3: Requisitos)
    if (step == 2) {
      if (_requiereUniforme && _implementosSeleccionados.isEmpty) {
        _showError('Debe seleccionar al menos un implemento de uniforme.');
        return false;
      }
    }
    return true;
  }

  void _onStepContinue() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < _getSteps().length - 1) {
        setState(() => _currentStep += 1);
      } else {
        _guardarTrabajo();
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  // --- WIDGETS DE PASOS (Contenido) ---

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // APLICANDO MÁS ESPACIADO
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('titulo'),
            controller: _tituloController,
            decoration: const InputDecoration(labelText: 'Nombre de trabajo / Puesto'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('descripcion'),
            controller: _descripcionController,
            decoration: const InputDecoration(
                labelText: 'Descripción del trabajo (Detalles de la tarea)'),
            maxLines: 3,
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('empresa'),
            controller: _empresaController,
            decoration: const InputDecoration(labelText: 'Empresa o Cliente'),
            maxLength: 30,
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    // Calculamos la hora límite (1 hora antes de la fecha de inicio del trabajo)
    DateTime? fechaLimiteAuto;
    if (_fechaTrabajo != null && _horaInicio != null) {
      final trabajoDateTime = DateTime(
        _fechaTrabajo!.year, _fechaTrabajo!.month, _fechaTrabajo!.day,
        _horaInicio!.hour, _horaInicio!.minute,
      );
      fechaLimiteAuto = trabajoDateTime.subtract(const Duration(hours: 1));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- UBICACIÓN ---
        Text('Ubicación del trabajo', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: _primaryColor)),
        const SizedBox(height: 8),
        
        // Dirección
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('direccion'),
            controller: _ubicacionDireccionCtrl,
            decoration: const InputDecoration(labelText: 'Dirección (Calle y número)'),
            validator: (value) {
               if (_ubicacionLatLng == null && (value == null || value.isEmpty)) {
                  return 'Requerido si no usa el mapa';
               }
               return null;
            }
          ),
        ),
        
        // Ciudad y País
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('ciudad'),
                  controller: _ubicacionCiudadCtrl,
                  decoration: const InputDecoration(labelText: 'Ciudad'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('pais'),
                  controller: _ubicacionPaisCtrl,
                  decoration: const InputDecoration(labelText: 'País'),
                ),
              ),
            ],
          ),
        ),
        
        // Controles de Coordenadas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(_ubicacionLatLng == null
                    ? '📍 Coordenadas no seleccionadas'
                    : 'Lat: ${_ubicacionLatLng!.latitude.toStringAsFixed(4)}, Lng: ${_ubicacionLatLng!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(color: _ubicacionLatLng != null ? Colors.green.shade600 : Colors.black54, fontSize: 13)),
              ),
            ),
            TextButton(
              onPressed: () async {
                final coords = await _obtenerCoords(
                    _ubicacionDireccionCtrl.text,
                    _ubicacionCiudadCtrl.text,
                    _ubicacionPaisCtrl.text);
                if (coords != null) {
                  setState(() => _ubicacionLatLng = coords);
                  _showError('Coordenadas obtenidas de la dirección.');
                } else {
                  _showError('Dirección no encontrada. Use el mapa.');
                }
              },
              child: const Text('Buscar Coords'),
            ),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeleccionarUbicacionScreen(
                      initialPosition: _ubicacionLatLng ??
                          const LatLng(-33.447487, -70.673676),
                    ),
                  ),
                );
                if (result != null) {
                  setState(() => _ubicacionLatLng = result);
                }
              },
              child: const Text('Elegir en Mapa'),
            ),
          ],
        ),
        const Divider(height: 30),
        
        // --- FECHAS Y HORARIO ---
        Text('Fechas y Horario', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: _primaryColor)),
        const SizedBox(height: 8),
        
        // Fecha del trabajo (El padding ya está en _buildDatePicker)
        _buildDatePicker(
          label: 'Fecha del trabajo',
          value: _fechaTrabajo,
          onPicked: (d) => setState(() => _fechaTrabajo = d),
        ),
        
        // Hora de inicio y fin (El padding ya está en _buildTimePicker)
        Row(
          children: [
            Expanded(
              child: _buildTimePicker(
                label: 'Hora de inicio',
                value: _horaInicio,
                onPicked: (t) => setState(() => _horaInicio = t),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimePicker(
                label: 'Hora de fin',
                value: _horaFin,
                onPicked: (t) => setState(() => _horaFin = t),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),

        // Fecha Límite Automática (Banner)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Icon(Icons.info_outline, color: _primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        fechaLimiteAuto == null
                            ? 'La fecha límite de postulación aparecerá aquí (ej: 1 hora antes del inicio).'
                            : '📅 Límite de Postulación: ${_formatFechaHora(fechaLimiteAuto)}.',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                ),
            ],
          ),
        ),

        const Divider(height: 30),

        // --- PAGO ---
        Text('Remuneración', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: _primaryColor)),
        
        // Precio
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('precio'),
            controller: _precioCtrl,
            decoration: const InputDecoration(
              labelText: 'Pago total (CLP o moneda local)',
              prefixText: '\$',
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Requerido';
              if (double.tryParse(v) == null) return 'Debe ser un número válido';
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep3Content() {
    final implementos = ['Polera', 'Pantalón', 'Zapatos de seguridad', 'Gorro', 'Guantes', 'Chaleco reflectante'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- CONTACTO ---
        Text('Contacto para el Postulante', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: _primaryColor)),
        const SizedBox(height: 8),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('contacto_nombre'),
            controller: _contactoNombreController,
            decoration: const InputDecoration(labelText: 'Nombre de contacto'),
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('contacto_numero'),
            controller: _contactoNumeroController,
            decoration: const InputDecoration(labelText: 'Número de contacto (Ej: +569...)'),
            keyboardType: TextInputType.phone,
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ),
        const Divider(height: 30),

        // --- UNIFORME ---
        Text('Uniforme y Requisitos', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: _primaryColor)),
        const SizedBox(height: 10),

        // Pregunta de Uniforme (Mejorado con Switch)
        Card(
          elevation: 0,
          color: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('¿Se requiere uniforme?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Switch(
                  value: _requiereUniforme,
                  onChanged: (v) => setState(() {
                    _requiereUniforme = v;
                    if (!v) _implementosSeleccionados.clear();
                  }),
                  activeColor: _primaryColor,
                ),
              ],
            ),
          ),
        ),
        
        // Lista de implementos (solo si requiere uniforme es Sí)
        if (_requiereUniforme) ...[
          const SizedBox(height: 16),
          Text('Selecciona los implementos que el trabajador debe llevar:', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8.0,
            children: implementos.map((e) => FilterChip(
              label: Text(e),
              selected: _implementosSeleccionados.contains(e),
              onSelected: (v) => setState(() {
                if (v) {
                  _implementosSeleccionados.add(e);
                } else {
                  _implementosSeleccionados.remove(e);
                }
              }),
              selectedColor: _secondaryColor.withOpacity(0.5),
              checkmarkColor: Colors.black,
            )).toList(),
          ),
          if (_implementosSeleccionados.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Debe seleccionar al menos un implemento.',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
        ],

        const Divider(height: 30),

        // --- INSTRUCCIONES ---
        Text('Instrucciones Específicas', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: _primaryColor)),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('instrucciones'),
            controller: _instruccionesController,
            decoration: const InputDecoration(labelText: 'Instrucciones/Notas especiales (Máx 1000 caracteres)'),
            maxLines: 4,
            maxLength: 1000,
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- WIDGETS DE INPUTS PERSONALIZADOS (Mantenidos) ---

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
  }) {
    final text = value == null
        ? 'Seleccionar fecha'
        : '${value.day}/${value.month}/${value.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            onPicked(picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          ),
          child: Text(text, style: TextStyle(color: value == null ? Colors.grey[700] : Colors.black87)),
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay> onPicked,
  }) {
    final text = value == null
        ? 'Seleccionar hora'
        : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (picked != null) {
            onPicked(picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.access_time, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          ),
          child: Text(text, style: TextStyle(color: value == null ? Colors.grey[700] : Colors.black87)),
        ),
      ),
    );
  }

  // --- LÓGICA DE GUARDADO ---

  Future<void> _guardarTrabajo() async {
    if (!_validateStep(2)) {
      return;
    }

    final fechaTrabajo = _fechaTrabajo!;
    final horaInicio = _horaInicio!;
    final horaFin = _horaFin!;

    final trabajoDateTimeStart = DateTime(
      fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day,
      horaInicio.hour, horaInicio.minute,
    );

    final trabajoDateTimeEnd = DateTime(
      fechaTrabajo.year, fechaTrabajo.month, fechaTrabajo.day,
      horaFin.hour, horaFin.minute,
    );

    final fechaLimiteFinal = trabajoDateTimeStart.subtract(const Duration(hours: 1));
    
    LatLng? coords = _ubicacionLatLng;
    if (coords == null && 
        (_ubicacionDireccionCtrl.text.isNotEmpty || _ubicacionCiudadCtrl.text.isNotEmpty || _ubicacionPaisCtrl.text.isNotEmpty)) {
      coords = await _obtenerCoords(
          _ubicacionDireccionCtrl.text,
          _ubicacionCiudadCtrl.text,
          _ubicacionPaisCtrl.text);
      if (coords == null) {
        _showError('No se pudo encontrar la ubicación de la dirección proporcionada.');
        return;
      }
    } else if (coords == null) {
        _showError('Debe proporcionar o seleccionar la ubicación del trabajo.');
        return;
    }

    final servicio = TrabajoService();
    try {
      await servicio.crearTrabajo(
        titulo: _tituloController.text,
        descripcion: _descripcionController.text,
        empresa: _empresaController.text,
        ubicacion: {
          'direccion': _ubicacionDireccionCtrl.text,
          'ciudad': _ubicacionCiudadCtrl.text,
          'pais': _ubicacionPaisCtrl.text,
          'lat': coords!.latitude, 
          'lng': coords.longitude,
        },
        fechaLimite: fechaLimiteFinal, 
        fechaInicioTrabajo: trabajoDateTimeStart,
        fechaFinTrabajo: trabajoDateTimeEnd,
        precio: double.tryParse(_precioCtrl.text) ?? 0,
        instrucciones: _instruccionesController.text,
        
        requiereUniforme: _requiereUniforme,
        implementosUniforme: _implementosSeleccionados.toList(),
        contacto: {
          'nombre': _contactoNombreController.text,
          'numero': _contactoNumeroController.text,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Trabajo publicado con éxito.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al publicar el trabajo: $e');
      }
    }
  }

  String _formatFechaHora(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio ${hora}h:${minuto}m';
  }

  // --- BUILD PRINCIPAL CON STEPPER ---
  
  List<Step> _getSteps() {
    return [
      Step(
        title: Text('1. Básica', style: TextStyle(fontWeight: _currentStep == 0 ? FontWeight.bold : FontWeight.normal)),
        content: Form(key: _formKeys[0], child: _buildStep1Content()),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('2. Logística y Pago', style: TextStyle(fontWeight: _currentStep == 1 ? FontWeight.bold : FontWeight.normal)),
        content: Form(key: _formKeys[1], child: _buildStep2Content()),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('3. Requisitos y Contacto', style: TextStyle(fontWeight: _currentStep == 2 ? FontWeight.bold : FontWeight.normal)),
        content: Form(key: _formKeys[2], child: _buildStep3Content()),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
    ];
  }
  
  // Custom Stepper Builder
  Widget _buildCustomStepper() {
    return Stepper(
      type: StepperType.vertical,
      currentStep: _currentStep,
      // INYECTAMOS CLAMPING SCROLL PHYSICS
      physics: const ClampingScrollPhysics(), 
      onStepTapped: (step) {
         if (_validateStep(_currentStep) || step < _currentStep) {
             setState(() => _currentStep = step);
         }
      },
      steps: _getSteps(),
      // Se usa un Stepper controlsBuilder vacío
      controlsBuilder: (context, details) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar colores del tema en el build
    _primaryColor = Theme.of(context).colorScheme.primary;
    _secondaryColor = Theme.of(context).colorScheme.secondary;
    _errorColor = Theme.of(context).colorScheme.error;
    
    final isLast = _currentStep == _getSteps().length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Oferta de Trabajo'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      // ELIMINAMOS EL SINGLECHILDSCROLLVIEW EXTERNO (el Stepper se encarga del scroll)
      // Y LO REEMPLAZAMOS CON EL STEPPER DIRECTO, pero mantenemos el padding para el Stepper
      body: Padding( 
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: _buildCustomStepper(),
      ),
      
      // Botones de acción fijos en la parte inferior
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón Atrás/Cancelar
            TextButton(
              onPressed: _currentStep == 0 ? _onStepCancel : _onStepCancel, 
              child: Text(
                _currentStep == 0 ? 'CANCELAR' : 'ATRÁS',
                style: TextStyle(
                  color: _currentStep == 0 ? _errorColor : Colors.black54, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            
            // Botón Siguiente/Publicar
            ElevatedButton.icon(
              onPressed: _onStepContinue, 
              icon: Icon(isLast ? Icons.send : Icons.arrow_forward, color: Colors.white),
              label: Text(isLast ? 'PUBLICAR TRABAJO' : 'SIGUIENTE', style: const TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? Colors.green.shade600 : _primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}