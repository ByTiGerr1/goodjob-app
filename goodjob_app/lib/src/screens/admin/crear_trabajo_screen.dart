import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:goodjob_app/src/models/trabajo.dart'; // Asegúrate que Trabajo y TrabajoPlantilla estén aquí o importados
import 'package:goodjob_app/src/services/plantilla_trabajo_service.dart';
import 'package:goodjob_app/src/services/storage_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/utils/format_utils.dart'; // Importa tus utils de formato
import 'package:goodjob_app/src/utils/location_utils.dart'; // Asume que tienes esta utilidad
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- ENUMS Y CLASES AUXILIARES ---
enum _MenuPlantillaOption { aplicar, crear }

class _PlantillaDialogResult {
  const _PlantillaDialogResult._(this.plantilla, this.crearNueva);
  final TrabajoPlantilla? plantilla;
  final bool crearNueva;
  factory _PlantillaDialogResult.aplicar(TrabajoPlantilla plantilla) =>
      _PlantillaDialogResult._(plantilla, false);
  factory _PlantillaDialogResult.crear() =>
      const _PlantillaDialogResult._(null, true);
}

// --- PANTALLA PRINCIPAL ---

class CrearTrabajoScreen extends StatefulWidget {
  // Solo el objeto Trabajo para edición
  final Trabajo? trabajoParaEditar;

  const CrearTrabajoScreen({
    super.key,
    this.trabajoParaEditar, // Parámetro opcional para modo edición
  });

  @override
  State<CrearTrabajoScreen> createState() => _CrearTrabajoScreenState();
}

class _CrearTrabajoScreenState extends State<CrearTrabajoScreen> {
  // Servicios
  final PlantillaTrabajoService _plantillaService = PlantillaTrabajoService();
  final TrabajoService _trabajoService = TrabajoService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  // Estados de Formulario y UI
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  int _currentStep = 0;
  bool _isSaving = false;

  // Estado de Datos
  List<TrabajoPlantilla> _plantillas = [];
  bool _cargandoPlantillas = false;

  // Estado de Imagen
  File? _imagenPrincipal;
  String? _imagenPrincipalUrlExistente;

  // Getter para saber si estamos editando
  bool get _esModoEdicion => widget.trabajoParaEditar != null;

  // Controladores
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _empresaController = TextEditingController();
  final _ubicacionDireccionCtrl = TextEditingController();
  final _ubicacionCiudadCtrl = TextEditingController();
  final _ubicacionPaisCtrl = TextEditingController();
  LatLng? _ubicacionLatLng;
  DateTime? _fechaTrabajo;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;
  final _precioCtrl = TextEditingController();
  bool _sinFechaLimite = false;
  final _contactoNombreController = TextEditingController();
  final _contactoNumeroController = TextEditingController();
  bool _requiereUniforme = false;
  final Set<String> _implementosSeleccionados = {};
  final _instruccionesController = TextEditingController();
  
  

  // Colores
  late Color _primaryColor;
  late Color _secondaryColor;
  late Color _errorColor;

  @override
  void initState() {
    super.initState();
    _cargarPlantillas(silent: true);
    // Carga datos iniciales si estamos en modo edición
    if (_esModoEdicion) {
      _cargarDatosParaEdicion(widget.trabajoParaEditar!);
    }
  }

  @override
  void dispose() {
    // Dispose de todos los controladores
    _tituloController.dispose();
    _descripcionController.dispose();
    _empresaController.dispose();
    _ubicacionDireccionCtrl.dispose();
    _ubicacionCiudadCtrl.dispose();
    _ubicacionPaisCtrl.dispose();
    _precioCtrl.dispose();
    _contactoNombreController.dispose();
    _contactoNumeroController.dispose();
    _instruccionesController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE CARGA PARA EDICIÓN ---
  void _cargarDatosParaEdicion(Trabajo trabajo) {
    // Carga datos desde el objeto Trabajo a los controladores y variables de estado
    _tituloController.text = trabajo.titulo;
    _descripcionController.text = trabajo.descripcion;
    _empresaController.text = trabajo.empresa;
    _imagenPrincipalUrlExistente = trabajo.imagenPrincipalUrl;

    final ubicacion = trabajo.ubicacion;
    _ubicacionDireccionCtrl.text = ubicacion['direccion'] ?? '';
    _ubicacionCiudadCtrl.text = ubicacion['ciudad'] ?? '';
    _ubicacionPaisCtrl.text = ubicacion['pais'] ?? '';
    _ubicacionLatLng = extractLatLngFromUbicacion(
      ubicacion,
    ); // Asume que esta función existe

    _fechaTrabajo = DateTime(
      trabajo.fechaInicioTrabajo.year,
      trabajo.fechaInicioTrabajo.month,
      trabajo.fechaInicioTrabajo.day,
    );
    _horaInicio = TimeOfDay.fromDateTime(trabajo.fechaInicioTrabajo);
    _horaFin = TimeOfDay.fromDateTime(trabajo.fechaFinTrabajo);

    _precioCtrl.text = trabajo.precio.toStringAsFixed(
      0,
    ); // Muestra sin decimales
    _sinFechaLimite = trabajo.sinFechaLimite;

    final contacto = trabajo.contacto;
    _contactoNombreController.text = contacto['nombre'] ?? '';
    _contactoNumeroController.text = contacto['numero'] ?? '';

    _requiereUniforme = trabajo.requiereUniforme;
    _implementosSeleccionados.clear();
    _implementosSeleccionados.addAll(trabajo.implementosUniforme);
    _instruccionesController.text = trabajo.instrucciones;

    // Asegura que la UI refleje los datos cargados
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }
  // --- FIN LÓGICA DE CARGA ---

  // --- LÓGICA DE SUBIDA DE IMAGEN ---
  Future<void> _seleccionarImagenPrincipal() async {
    // Muestra opciones Galería/Cámara
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return; // Usuario canceló

    // Selecciona la imagen
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 70, // Optimiza calidad/peso
    );

    // Actualiza el estado si se seleccionó una imagen
    if (image != null && mounted) {
      setState(() {
        _imagenPrincipal = File(image.path); // Guarda el archivo local
        _imagenPrincipalUrlExistente =
            null; // Borra la URL existente al seleccionar nueva imagen
      });
    }
  }
  // --- FIN LÓGICA IMAGEN ---

  // --- OTRAS FUNCIONES HELPER (Geocoding, Errores, Plantillas, Validación, Stepper) ---
  Future<LatLng?> _obtenerCoords(
    String direccion,
    String ciudad,
    String pais,
  ) async {
    final query = [
      direccion,
      ciudad,
      pais,
    ].where((e) => e.isNotEmpty).join(', ');
    if (query.isEmpty) return null;
    try {
      final results = await geocoding.locationFromAddress(query);
      if (results.isNotEmpty) {
        final loc = results.first;
        return LatLng(loc.latitude, loc.longitude);
      }
    } catch (e) {
      print('Error de Geocoding: $e');
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _errorColor),
    );
  }

  Future<void> _cargarPlantillas({bool silent = false}) async {
    if (!mounted || _esModoEdicion) return; // No cargar plantillas en edición
    setState(() => _cargandoPlantillas = true);
    try {
      final plantillas = await _plantillaService.obtenerPlantillas();
      if (!mounted) return;
      setState(() {
        _plantillas = plantillas;
        _cargandoPlantillas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoPlantillas = false);
      if (!silent) _showError('No se pudieron cargar las plantillas.');
    }
  }

  Future<void> _abrirCrearPlantilla() async {
    // Asume que tienes una ruta nombrada 'crear_plantilla'
    final created = await Navigator.of(context).pushNamed('crear_plantilla');
    if (created == true) await _cargarPlantillas(silent: true);
  }

  // Helper para parsear TimeOfDay desde varios formatos (si lo usa _aplicarPlantilla)
  TimeOfDay? _timeOfDayFromData(dynamic value) {
    if (value is Map) {
      final hour = value['h'] ?? value['hour'];
      final minute = value['m'] ?? value['minute'];
      if (hour is num && minute is num)
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
    } else if (value is Timestamp) {
      // Añadir soporte para Timestamp si es necesario
      final dt = value.toDate();
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
    // Añade más parsing si es necesario (String hh:mm, etc.)
    return null;
  }

  void _aplicarPlantilla(TrabajoPlantilla plantilla) {
    final data = plantilla.data;
    setState(() {
      _tituloController.text = (data['titulo'] as String?)?.trim() ?? '';
      _descripcionController.text =
          (data['descripcion'] as String?)?.trim() ?? '';
      _empresaController.text = (data['empresa'] as String?)?.trim() ?? '';
      _imagenPrincipal = null;
      _imagenPrincipalUrlExistente = data['imagenPrincipalUrl'] as String?;

      _ubicacionDireccionCtrl.text =
          (data['ubicacion']?['direccion'] as String?)?.trim() ?? '';
      _ubicacionCiudadCtrl.text =
          (data['ubicacion']?['ciudad'] as String?)?.trim() ?? '';
      _ubicacionPaisCtrl.text =
          (data['ubicacion']?['pais'] as String?)?.trim() ?? '';
      _ubicacionLatLng = extractLatLngFromUbicacion(data['ubicacion']);

      final fechaInicioTs = data['fechaInicioTrabajo'];
      final fechaFinTs = data['fechaFinTrabajo'];
      if (fechaInicioTs is Timestamp) {
        final dtInicio = fechaInicioTs.toDate();
        _fechaTrabajo = DateTime(dtInicio.year, dtInicio.month, dtInicio.day);
        _horaInicio = TimeOfDay.fromDateTime(dtInicio);
      } else {
        _fechaTrabajo = null;
        _horaInicio = null;
      }
      if (fechaFinTs is Timestamp) {
        _horaFin = TimeOfDay.fromDateTime(fechaFinTs.toDate());
      } else {
        _horaFin = null;
      }

      final dynamic precio = data['precio'];
      _precioCtrl.text = precio?.toString() ?? '';

      _sinFechaLimite = data['sinFechaLimite'] == true;

      final contacto = data['contacto'] as Map<String, dynamic>?;
      _contactoNombreController.text = (contacto?['nombre'] as String?) ?? '';
      _contactoNumeroController.text = (contacto?['numero'] as String?) ?? '';

      _requiereUniforme = data['requiereUniforme'] == true;
      _implementosSeleccionados.clear();
      _implementosSeleccionados.addAll(
        ((data['implementosUniforme'] as List?) ?? []).map((e) => e.toString()),
      );
      _instruccionesController.text =
          (data['instrucciones'] as String?)?.trim() ?? '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Plantilla "${plantilla.nombre}" aplicada.')),
    );
  }

  Future<void> _mostrarSelectorPlantillas() async {
    await _cargarPlantillas();
    if (!mounted || _esModoEdicion) return;

    final resultado = await showDialog<_PlantillaDialogResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plantillas disponibles'),
        content: SizedBox(
          width: double.maxFinite,
          child: _cargandoPlantillas
              ? const Center(child: CircularProgressIndicator())
              : _plantillas.isEmpty
              ? const Text('Aún no tienes plantillas guardadas.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _plantillas.length,
                  itemBuilder: (context, index) {
                    final plantilla = _plantillas[index];
                    return ListTile(
                      title: Text(plantilla.nombre),
                      subtitle: Text(
                        (plantilla.data['descripcion'] as String?) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(
                        ctx,
                      ).pop(_PlantillaDialogResult.aplicar(plantilla)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_PlantillaDialogResult.crear()),
            child: const Text('Nueva plantilla'),
          ),
        ],
      ),
    );

    if (!mounted || resultado == null) return;
    if (resultado.crearNueva)
      await _abrirCrearPlantilla();
    else if (resultado.plantilla != null)
      _aplicarPlantilla(resultado.plantilla!);
  }

  bool _validarFormularioPaso(int step) {
    final formState = _formKeys[step].currentState;
    if (formState == null) return true; // Si no hay form, es válido
    final validation = formState.validate();

    // Validación específica imagen paso 0
    if (step == 0) {
      final hasImage =
          _imagenPrincipal != null ||
          (_imagenPrincipalUrlExistente != null &&
              _imagenPrincipalUrlExistente!.isNotEmpty);
      if (!hasImage) {
        _showError('Debe subir una imagen principal para el trabajo.');
        return false; // Imagen es obligatoria
      }
    }
    return validation; // Devuelve resultado de validación de campos
  }

  String? _mensajeValidacionPaso(int step) {
    // Validaciones específicas que no cubre TextFormField
    if (step == 1) {
      final hasAddress =
          _ubicacionDireccionCtrl.text.isNotEmpty &&
          _ubicacionCiudadCtrl.text.isNotEmpty;
      if (_ubicacionLatLng == null && !hasAddress)
        return 'Debe ingresar dirección o seleccionar en mapa.';
      if (_fechaTrabajo == null) return 'Debe seleccionar la fecha.';
      if (_horaInicio == null || _horaFin == null)
        return 'Debe seleccionar hora de inicio y fin.';
      if (_horaInicio != null && _horaFin != null) {
        final ini = _horaInicio!.hour * 60 + _horaInicio!.minute;
        final fin = _horaFin!.hour * 60 + _horaFin!.minute;
        if (ini >= fin)
          return 'La hora de inicio debe ser anterior a la de fin.';
      }
    }
    if (step == 2 && _requiereUniforme && _implementosSeleccionados.isEmpty) {
      return 'Debe seleccionar al menos un implemento de uniforme.';
    }
    return null; // Sin errores específicos
  }

  Future<bool> _mostrarDialogoPasoIncompleto(String? detalle) async {
    // No mostrar si ya estamos guardando
    if (!mounted || _isSaving) return false;
    const mensajeBase =
        'Hay campos obligatorios sin completar. Revisa la información.';
    final texto = detalle == null
        ? mensajeBase
        : '$mensajeBase\n\nDetalle: $detalle';
    // Usamos showDialog directamente
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paso incompleto'),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(), // Simplemente cierra el diálogo
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return false; // Siempre devuelve false para no avanzar
  }

  Future<void> _irAlPaso(int step) async {
    if (step == _currentStep || step < 0 || step >= _getSteps().length) return;

    // Permite retroceder sin validar
    if (step < _currentStep) {
      setState(() => _currentStep = step);
      return;
    }

    // Valida el paso actual ANTES de intentar avanzar
    final formularioValido = _validarFormularioPaso(_currentStep);
    final mensajeEspecifico = _mensajeValidacionPaso(_currentStep);

    if (formularioValido && mensajeEspecifico == null) {
      // Si todo está bien, avanza
      if (!mounted) return;
      setState(() => _currentStep = step);
    } else {
      // Si hay error, muestra el diálogo
      await _mostrarDialogoPasoIncompleto(mensajeEspecifico);
    }
  }

  Future<void> _onStepContinue() async {
    final isLast = _currentStep == _getSteps().length - 1;
    // Valida el paso actual antes de continuar o guardar
    final formularioValido = _validarFormularioPaso(_currentStep);
    final mensajeEspecifico = _mensajeValidacionPaso(_currentStep);

    if (formularioValido && mensajeEspecifico == null) {
      // Si es válido, avanza o guarda
      if (isLast) {
        await _guardarTrabajo(); // Intenta guardar
      } else {
        setState(() => _currentStep += 1); // Avanza al siguiente paso
      }
    } else {
      // Si no es válido, muestra el error
      await _mostrarDialogoPasoIncompleto(mensajeEspecifico);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1); // Retrocede
    } else {
      Navigator.of(context).pop(); // Sale si está en el primer paso
    }
  }

  bool _validarTodoFormulario() {
    bool todoValido = true;
    String? primerError;
    int? pasoError;

    for (var i = 0; i < _formKeys.length; i++) {
      final formularioValido = _validarFormularioPaso(i);
      final mensaje = _mensajeValidacionPaso(i);

      if (!formularioValido || mensaje != null) {
        todoValido = false;
        if (primerError == null) {
          primerError = mensaje ?? 'Hay campos inválidos en el paso ${i + 1}.';
          pasoError = i;
        }
      }
    }

    if (!todoValido && pasoError != null) {
      _showError(primerError!);
      setState(() => _currentStep = pasoError!); // Ir al paso con error
    }
    return todoValido;
  }

  // --- LÓGICA DE GUARDADO/ACTUALIZACIÓN ---
  Future<void> _guardarTrabajo() async {
    if (!_validarTodoFormulario())
      return; // Valida TODO antes de empezar a guardar
    setState(() => _isSaving = true);

    String? finalImageUrl = _imagenPrincipalUrlExistente;
    String? trabajoId = widget.trabajoParaEditar?.id;
    DocumentReference<Map<String, dynamic>>? nuevoTrabajoRef;
    bool documentoTemporalCreado = false;

    try {
      // 1. Manejo de Imagen
      if (_imagenPrincipal != null) {
        if (!_esModoEdicion) {
          nuevoTrabajoRef = FirebaseFirestore.instance
              .collection('trabajos')
              .doc();
          trabajoId = nuevoTrabajoRef.id;
          await nuevoTrabajoRef.set({
            'estado': 'creando',
            'creadoEn': FieldValue.serverTimestamp(),
          });
          documentoTemporalCreado = true;
        }
        if (trabajoId == null) throw Exception("ID de trabajo no disponible.");

        finalImageUrl = await _storageService.subirImagenPrincipal(
          trabajoId: trabajoId,
          imagen: _imagenPrincipal!,
        );
        if (finalImageUrl == null)
          throw Exception('No se pudo subir la imagen.');
      } else if (!_esModoEdicion) {
        throw Exception('La imagen principal es obligatoria.');
      }

      // 2. Preparar Datos
      if (_fechaTrabajo == null || _horaInicio == null || _horaFin == null)
        throw Exception('Falta fecha/horario.');
      final fechaTrabajo = _fechaTrabajo!;
      final horaInicio = _horaInicio!;
      final horaFin = _horaFin!;
      final trabajoDateTimeStart = DateTime(
        fechaTrabajo.year,
        fechaTrabajo.month,
        fechaTrabajo.day,
        horaInicio.hour,
        horaInicio.minute,
      );
      final trabajoDateTimeEnd = DateTime(
        fechaTrabajo.year,
        fechaTrabajo.month,
        fechaTrabajo.day,
        horaFin.hour,
        horaFin.minute,
      );
      final DateTime? fechaLimiteFinal = _sinFechaLimite
          ? null
          : trabajoDateTimeStart.subtract(const Duration(hours: 1));

      LatLng? coords = _ubicacionLatLng;
      if (coords == null &&
          (_ubicacionDireccionCtrl.text.isNotEmpty ||
              _ubicacionCiudadCtrl.text.isNotEmpty ||
              _ubicacionPaisCtrl.text.isNotEmpty)) {
        coords = await _obtenerCoords(
          _ubicacionDireccionCtrl.text,
          _ubicacionCiudadCtrl.text,
          _ubicacionPaisCtrl.text,
        );
        if (coords == null)
          throw Exception('No se pudo encontrar la ubicación.');
      } else if (coords == null) {
        throw Exception('Debe proporcionar o seleccionar la ubicación.');
      }

      final ubicacionData = buildUbicacionPayload(
        direccion: _ubicacionDireccionCtrl.text,
        ciudad: _ubicacionCiudadCtrl.text,
        pais: _ubicacionPaisCtrl.text,
        coordenadas: coords,
      ); // Asume que esta función existe
      final contactoData = {
        'nombre': _contactoNombreController.text,
        'numero': _contactoNumeroController.text,
      };
      final precioNum = double.tryParse(_precioCtrl.text) ?? 0.0;

      // 3. Llamar al Servicio Correcto
      if (_esModoEdicion) {
        // --- MODO EDICIÓN ---
        await _trabajoService.actualizarTrabajo(
          trabajoId: widget.trabajoParaEditar!.id,
          titulo: _tituloController.text,
          descripcion: _descripcionController.text,
          empresa: _empresaController.text,
          ubicacion: ubicacionData,
          fechaLimite: fechaLimiteFinal,
          fechaInicioTrabajo: trabajoDateTimeStart,
          fechaFinTrabajo: trabajoDateTimeEnd,
          precio: precioNum,
          instrucciones: _instruccionesController.text,
          requiereUniforme: _requiereUniforme,
          implementosUniforme: _implementosSeleccionados.toList(),
          contacto: contactoData,

          sinFechaLimite: _sinFechaLimite,
          imagenPrincipalUrl: finalImageUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trabajo actualizado con éxito.')),
          );
          Navigator.pop(context, true); // Devuelve true para indicar éxito
        }
      } else {
        // --- MODO CREACIÓN ---
        await _trabajoService.crearTrabajo(
          trabajoId: trabajoId, // ID temporal si se creó
          titulo: _tituloController.text,
          descripcion: _descripcionController.text,
          empresa: _empresaController.text,
          ubicacion: ubicacionData,
          fechaLimite: fechaLimiteFinal,
          fechaInicioTrabajo: trabajoDateTimeStart,
          fechaFinTrabajo: trabajoDateTimeEnd,
          precio: precioNum,
          instrucciones: _instruccionesController.text,
          requiereUniforme: _requiereUniforme,
          implementosUniforme: _implementosSeleccionados.toList(),
          contacto: contactoData,
          sinFechaLimite: _sinFechaLimite,
          imagenPrincipalUrl: finalImageUrl,
          // destacado: false, // Default para creación
          // creadorId: 'admin_id', // Si lo necesitaras
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trabajo publicado con éxito.')),
          );
          Navigator.pop(context); // Simplemente vuelve atrás
        }
      }
    } catch (e) {
      if (documentoTemporalCreado && nuevoTrabajoRef != null) {
        await nuevoTrabajoRef.delete().catchError(
          (_) {},
        ); // Intenta borrar doc temporal
      }
      if (mounted) {
        _showError(
          'Error al guardar: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  // --- FIN LÓGICA DE GUARDADO ---

  // --- WIDGETS DE PASOS (Contenido) ---
  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImagePickerField(), // Campo de imagen
        const SizedBox(height: 20),
        TextFormField(
          key: const ValueKey('titulo'),
          controller: _tituloController,
          decoration: const InputDecoration(
            labelText: 'Nombre de trabajo / Puesto',
          ),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('descripcion'),
          controller: _descripcionController,
          decoration: const InputDecoration(
            labelText: 'Descripción del trabajo',
          ),
          maxLines: 3,
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('empresa'),
          controller: _empresaController,
          decoration: const InputDecoration(labelText: 'Empresa o Cliente'),
          maxLength: 30,
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
      ],
    );
  }

  Widget _buildImagePickerField() {
    // ... (Lógica sin cambios para mostrar imagen local/remota/placeholder y botón flotante)
    final hasLocalImage = _imagenPrincipal != null;
    final hasExistingUrl =
        _imagenPrincipalUrlExistente != null &&
        _imagenPrincipalUrlExistente!.isNotEmpty;
    final showNetwork = !hasLocalImage && hasExistingUrl;
    Widget imageWidget;
    if (hasLocalImage) {
      imageWidget = Image.file(_imagenPrincipal!, fit: BoxFit.cover);
    } else if (showNetwork) {
      imageWidget = Image.network(
        _imagenPrincipalUrlExistente!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => /* Placeholder error */ Icon(Icons.error),
      );
    } else {
      imageWidget = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.add_a_photo), Text('Añadir Imagen')],
        ),
      );
    }
    return GestureDetector(
      onTap: _isSaving ? null : _seleccionarImagenPrincipal,
      child: Container(
        height: 180,
        decoration: BoxDecoration(/*...*/),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (_isSaving) /* Overlay carga */ Container(),
            Positioned(
              bottom: 8,
              right: 8,
              child: FloatingActionButton.small(
                onPressed: _isSaving ? null : _seleccionarImagenPrincipal,
                child: const Icon(Icons.edit),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Content() {
    // Cálculo fecha límite automática (sin cambios)
    DateTime? fechaLimiteAuto;
    if (!_sinFechaLimite && _fechaTrabajo != null && _horaInicio != null) {
      final trabDT = DateTime(
        _fechaTrabajo!.year,
        _fechaTrabajo!.month,
        _fechaTrabajo!.day,
        _horaInicio!.hour,
        _horaInicio!.minute,
      );
      fechaLimiteAuto = trabDT.subtract(const Duration(hours: 1));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ubicación del trabajo',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('direccion'),
          controller: _ubicacionDireccionCtrl,
          decoration: const InputDecoration(labelText: 'Dirección'),
          validator: (v) => _ubicacionLatLng == null && (v == null || v.isEmpty)
              ? 'Requerido'
              : null,
        ),
        const SizedBox(height: 16),
        Row(
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
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _ubicacionLatLng == null
                    ? '📍 Coordenadas...'
                    : 'Lat: ${_ubicacionLatLng!.latitude.toStringAsFixed(4)}, Lng: ${_ubicacionLatLng!.longitude.toStringAsFixed(4)}',
              ),
            ),
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      /* Buscar Coords */
                    },
              child: const Text('Buscar'),
            ),
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      /* Elegir Mapa */
                    },
              child: const Text('Mapa'),
            ),
          ],
        ),
        const Divider(height: 30),
        Text(
          'Fechas y Horario',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: 8),
        _buildDatePicker(
          label: 'Fecha del trabajo',
          value: _fechaTrabajo,
          onPicked: (d) => setState(() => _fechaTrabajo = d),
        ),
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
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(/*...*/),
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            secondary: Icon(_sinFechaLimite ? Icons.lock_open : Icons.schedule),
            value: _sinFechaLimite,
            onChanged: _isSaving
                ? null
                : (v) => setState(() => _sinFechaLimite = v),
            title: const Text('Mantener postulaciones abiertas'),
            subtitle: const Text('Activa para trabajos sin fecha límite.'),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(/*...*/),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _sinFechaLimite
                      ? '🔓 Postulaciones abiertas...'
                      : (fechaLimiteAuto == null
                            ? 'La fecha límite aparecerá...'
                            : '📅 Límite: ${FormatUtils.formatDate(fechaLimiteAuto)}'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 30),
        Text(
          'Remuneración',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: _primaryColor),
        ),
        TextFormField(
          key: const ValueKey('precio'),
          controller: _precioCtrl,
          enabled: !_isSaving,
          decoration: const InputDecoration(
            labelText: 'Pago a trabajador (CLP)',
            prefixText: 'CLP \$',
          ),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            if (double.tryParse(v) == null) return 'Número inválido';
            return null;
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep3Content() {
    final implementos = [
      'Polera',
      'Pantalón',
      'Zapatos de seguridad',
      'Gorro',
      'Guantes',
      'Chaleco reflectante',
    ]; // Define tus implementos
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contacto para el Postulante',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('contacto_nombre'),
          controller: _contactoNombreController,
          enabled: !_isSaving,
          decoration: const InputDecoration(labelText: 'Nombre de contacto'),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('contacto_numero'),
          controller: _contactoNumeroController,
          enabled: !_isSaving,
          decoration: const InputDecoration(labelText: 'Número de contacto'),
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
        const Divider(height: 30),
        Text(
          'Uniforme y Requisitos',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: _primaryColor),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          color: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('¿Se requiere uniforme?'),
                Switch(
                  value: _requiereUniforme,
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() {
                          _requiereUniforme = v;
                          if (!v) _implementosSeleccionados.clear();
                        }),
                  activeThumbColor: _primaryColor,
                ),
              ],
            ),
          ),
        ),
        if (_requiereUniforme) ...[
          const SizedBox(height: 16),
          Text(
            'Selecciona los implementos:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Wrap(
            spacing: 8.0,
            children: implementos
                .map(
                  (e) => FilterChip(
                    label: Text(e),
                    selected: _implementosSeleccionados.contains(e),
                    onSelected: _isSaving
                        ? null
                        : (v) => setState(() {
                            if (v)
                              _implementosSeleccionados.add(e);
                            else
                              _implementosSeleccionados.remove(e);
                          }),
                    selectedColor: _secondaryColor.withOpacity(0.5),
                  ),
                )
                .toList(),
          ),
          if (_implementosSeleccionados.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Debe seleccionar al menos un implemento.',
                style: TextStyle(color: _errorColor, fontSize: 12),
              ),
            ),
        ],
        const Divider(height: 30),
        Text(
          'Instrucciones Específicas',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: _primaryColor),
        ),
        TextFormField(
          key: const ValueKey('instrucciones'),
          controller: _instruccionesController,
          enabled: !_isSaving,
          decoration: const InputDecoration(
            labelText: 'Instrucciones/Notas (Máx 1000)',
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          maxLength: 1000,
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- WIDGETS DE INPUTS PERSONALIZADOS (Fecha/Hora) ---
  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
  }) {
    final text = value == null
        ? 'Seleccionar fecha'
        : FormatUtils.formatDate(value); // Usa FormatUtils
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: _isSaving
            ? null
            : () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 5),
                );
                if (picked != null) onPicked(picked);
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today, size: 20),
            border: const OutlineInputBorder(),
          ),
          child: Text(
            text,
            style: TextStyle(color: value == null ? Colors.grey[700] : null),
          ),
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
        : value.format(context); // Formato local
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: _isSaving
            ? null
            : () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: value ?? TimeOfDay.now(),
                );
                if (picked != null) onPicked(picked);
              },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.access_time, size: 20),
            border: const OutlineInputBorder(),
          ),
          child: Text(
            text,
            style: TextStyle(color: value == null ? Colors.grey[700] : null),
          ),
        ),
      ),
    );
  }
  // ---

  // --- BUILD PRINCIPAL CON STEPPER ---
  List<Step> _getSteps() {
    // Define los pasos del Stepper
    return [
      Step(
        title: Text(
          '1. Básica',
          style: TextStyle(
            fontWeight: _currentStep == 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        content: Form(key: _formKeys[0], child: _buildStep1Content()),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text(
          '2. Logística y Pago',
          style: TextStyle(
            fontWeight: _currentStep == 1 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        content: Form(key: _formKeys[1], child: _buildStep2Content()),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text(
          '3. Requisitos',
          style: TextStyle(
            fontWeight: _currentStep == 2 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        content: Form(key: _formKeys[2], child: _buildStep3Content()),
        isActive: _currentStep >= 2,
        // Último paso no muestra 'complete' hasta guardar
        state: _currentStep == 2
            ? StepState.editing
            : (_currentStep > 2 ? StepState.complete : StepState.indexed),
      ),
    ];
  }

  Widget _buildCustomStepper() {
    // Construye el widget Stepper
    return Stepper(
      type: StepperType.vertical, // O StepperType.horizontal
      currentStep: _currentStep,
      physics: const ClampingScrollPhysics(), // Evita scroll excesivo
      onStepTapped: (step) =>
          _irAlPaso(step), // Permite navegar tocando el paso
      // onStepContinue: _onStepContinue, // Usa botones personalizados abajo
      // onStepCancel: _onStepCancel,     // Usa botones personalizados abajo
      steps: _getSteps(),
      // Oculta los botones por defecto del Stepper
      controlsBuilder: (context, details) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obtiene colores del tema actual
    _primaryColor = Theme.of(context).colorScheme.primary;
    _secondaryColor = Theme.of(context).colorScheme.secondary;
    _errorColor = Theme.of(context).colorScheme.error;
    final isLast = _currentStep == _getSteps().length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esModoEdicion ? 'Editar Oferta de Trabajo' : 'Crear Nueva Oferta',
        ),
        actions: [
          // Solo mostrar plantillas en modo CREACIÓN
          if (!_esModoEdicion && !_isSaving)
            PopupMenuButton<_MenuPlantillaOption>(
              tooltip: 'Acciones de plantillas',
              icon: const Icon(Icons.layers_outlined),
              onSelected: (option) {
                switch (option) {
                  case _MenuPlantillaOption.aplicar:
                    _mostrarSelectorPlantillas();
                    break;
                  case _MenuPlantillaOption.crear:
                    _abrirCrearPlantilla();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _MenuPlantillaOption.aplicar,
                  child: Text('Aplicar plantilla'),
                ),
                PopupMenuItem(
                  value: _MenuPlantillaOption.crear,
                  child: Text('Crear plantilla'),
                ),
              ],
            ),
        ],
      ),
      // Usa SingleChildScrollView si StepperType es horizontal o si hay mucho contenido
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 0,
        ), // Stepper maneja su padding
        child: Column(
          children: [
            Expanded(
              child: _buildCustomStepper(),
            ), // El Stepper ocupa el espacio
          ],
        ),
      ),

      // Botones de acción fijos en la parte inferior
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).cardColor, // Usa color de tarjeta para adaptarse al tema
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón Atrás/Cancelar
            TextButton(
              onPressed: _isSaving ? null : _onStepCancel,
              child: Text(
                _currentStep == 0 ? 'CANCELAR' : 'ATRÁS',
                style: TextStyle(
                  color: _currentStep == 0
                      ? _errorColor
                      : Theme.of(
                          context,
                        ).textTheme.bodyLarge?.color?.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Botón Siguiente/Publicar/Guardar
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _onStepContinue,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(isLast ? Icons.save : Icons.arrow_forward),
              label: Text(
                isLast
                    ? (_esModoEdicion ? 'GUARDAR CAMBIOS' : 'PUBLICAR TRABAJO')
                    : 'SIGUIENTE',
                // style: const TextStyle(fontSize: 16), // Color se hereda del botón
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast
                    ? (_esModoEdicion
                          ? Colors.green.shade600
                          : _primaryColor) // Verde al guardar cambios
                    : _primaryColor, // Color primario para Siguiente
                foregroundColor: Colors.white, // Color del texto e icono
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
