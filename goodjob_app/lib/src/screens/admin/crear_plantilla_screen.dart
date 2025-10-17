import 'package:flutter/material.dart';

import '../../services/plantilla_trabajo_service.dart';

class CrearPlantillaScreen extends StatefulWidget {
  const CrearPlantillaScreen({super.key});

  @override
  State<CrearPlantillaScreen> createState() => _CrearPlantillaScreenState();
}

class _CrearPlantillaScreenState extends State<CrearPlantillaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombrePlantillaController = TextEditingController();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _empresaController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _paisController = TextEditingController();
  final _contactoNombreController = TextEditingController();
  final _contactoTelefonoController = TextEditingController();
  final _instruccionesController = TextEditingController();
  final _precioController = TextEditingController();

  final PlantillaTrabajoService _plantillaService = PlantillaTrabajoService();

  bool _guardando = false;

  @override
  void dispose() {
    _nombrePlantillaController.dispose();
    _tituloController.dispose();
    _descripcionController.dispose();
    _empresaController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _paisController.dispose();
    _contactoNombreController.dispose();
    _contactoTelefonoController.dispose();
    _instruccionesController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _construirDatosPlantilla() {
    final data = <String, dynamic>{
      'titulo': _tituloController.text.trim(),
      'descripcion': _descripcionController.text.trim(),
      'empresa': _empresaController.text.trim(),
      'ubicacionDireccion': _direccionController.text.trim(),
      'ubicacionCiudad': _ciudadController.text.trim(),
      'ubicacionPais': _paisController.text.trim(),
      'contactoNombre': _contactoNombreController.text.trim(),
      'contactoNumero': _contactoTelefonoController.text.trim(),
      'instrucciones': _instruccionesController.text.trim(),
      'precio': _precioController.text.trim(),
    };

    data.removeWhere((key, value) => value == null || (value is String && value.isEmpty));
    return data;
  }

  Future<void> _guardarPlantilla() async {
    if (_guardando) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final datos = _construirDatosPlantilla();
    if (datos.isEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Agrega al menos un campo de texto para la plantilla.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final nombre = _nombrePlantillaController.text.trim();
      await _plantillaService.guardarPlantilla(nombre: nombre, data: datos);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plantilla "$nombre" guardada.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la plantilla. Intenta nuevamente.')),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear plantilla'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombrePlantillaController,
              decoration: const InputDecoration(labelText: 'Nombre de la plantilla'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa un nombre para la plantilla';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(labelText: 'Título del trabajo'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _empresaController,
              decoration: const InputDecoration(labelText: 'Empresa o cliente'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _direccionController,
              decoration: const InputDecoration(labelText: 'Dirección'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ciudadController,
              decoration: const InputDecoration(labelText: 'Ciudad'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paisController,
              decoration: const InputDecoration(labelText: 'País'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactoNombreController,
              decoration: const InputDecoration(labelText: 'Nombre de contacto'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactoTelefonoController,
              decoration: const InputDecoration(labelText: 'Teléfono de contacto'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instruccionesController,
              decoration: const InputDecoration(labelText: 'Instrucciones adicionales'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _precioController,
              decoration: const InputDecoration(labelText: 'Precio'),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _guardando ? null : _guardarPlantilla,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar plantilla'),
            ),
          ],
        ),
      ),
    );
  }
}