import 'dart:async';
import 'dart:io'; 

import 'package:flutter/material.dart';
import 'package:goodjob_app/src/screens/admin/seleccionar_ubicacion_screen.dart';
import 'package:goodjob_app/src/services/plantilla_trabajo_service.dart';
import 'package:goodjob_app/src/services/trabajo_service.dart';
import 'package:goodjob_app/src/utils/location_utils.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
// Importaciones de utilidades y servicios requeridos:
import 'package:image_picker/image_picker.dart'; 
import '../../services/storage_service.dart'; // Importado
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
  final String? trabajoIdParaEditar;
  final Map<String, dynamic>? trabajoInicial;

  const CrearTrabajoScreen({
    super.key,
    this.trabajoIdParaEditar,
    this.trabajoInicial,
  });

  @override
  State<CrearTrabajoScreen> createState() => _CrearTrabajoScreenState();
}

class _CrearTrabajoScreenState extends State<CrearTrabajoScreen> {
  // Servicios
  final PlantillaTrabajoService _plantillaService = PlantillaTrabajoService();
  final TrabajoService _trabajoService = TrabajoService();
  final StorageService _storageService = StorageService(); // USAMOS EL SERVICIO DE STORAGE
  final ImagePicker _picker = ImagePicker(); 

  // Estados de Formulario y UI
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  int _currentStep = 0;
  bool _isSaving = false; // Estado para el botón de Publicar/Guardar
  
  // Estado de Datos
  List<TrabajoPlantilla> _plantillas = [];
  bool _cargandoPlantillas = false;
  
  // ESTADO DE IMAGEN
  File? _imagenPrincipal; // Archivo local seleccionado
  String? _imagenPrincipalUrlExistente; // URL si estamos en modo edición

  bool get _esModoEdicion => widget.trabajoIdParaEditar != null;

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
  bool _sinFechaLimite = false;

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
  void initState() {
    super.initState();
    _cargarPlantillas(silent: true);
    if (_esModoEdicion && widget.trabajoInicial != null) {
      _cargarDatosParaEdicion(widget.trabajoInicial!);
    }
  }

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
  
  // --- LÓGICA DE CARGA PARA EDICIÓN ---
  
  DateTime? _getDateTimeFromTimestamp(dynamic value) {
    if (value != null && value.runtimeType.toString() == 'Timestamp') {
      return (value as Timestamp).toDate();
    }
    return null;
  }
  
  TimeOfDay? _getTimeOfDayFromDateTime(DateTime? dateTime) {
    if (dateTime == null) return null;
    return TimeOfDay.fromDateTime(dateTime);
  }

  void _cargarDatosParaEdicion(Map<String, dynamic> data) {
    // Paso 1
    _tituloController.text = data['titulo'] ?? '';
    _descripcionController.text = data['descripcion'] ?? '';
    _empresaController.text = data['empresa'] ?? '';
    
    // Cargar URL de imagen existente
    _imagenPrincipalUrlExistente = data['imagenPrincipalUrl'] as String?;

    // Paso 2 (Mismo código de ubicación, fechas y precio)
    final ubicacion = data['ubicacion'] as Map<String, dynamic>?;
    if (ubicacion != null) {
      _ubicacionDireccionCtrl.text = ubicacion['direccion'] ?? '';
      _ubicacionCiudadCtrl.text = ubicacion['ciudad'] ?? '';
      _ubicacionPaisCtrl.text = ubicacion['pais'] ?? '';

      final coords = extractLatLngFromUbicacion(ubicacion);
      if (coords != null) {
        _ubicacionLatLng = coords;
      }
    }

    final fechaInicioTrabajo = _getDateTimeFromTimestamp(data['fechaInicioTrabajo']);
    final fechaFinTrabajo = _getDateTimeFromTimestamp(data['fechaFinTrabajo']);

    if (fechaInicioTrabajo != null) {
      _fechaTrabajo = DateTime(fechaInicioTrabajo.year, fechaInicioTrabajo.month, fechaInicioTrabajo.day);
      _horaInicio = _getTimeOfDayFromDateTime(fechaInicioTrabajo);
    }
    if (fechaFinTrabajo != null) {
      _horaFin = _getTimeOfDayFromDateTime(fechaFinTrabajo);
    }

    final precio = data['precio'];
    if (precio is num) {
      _precioCtrl.text = precio.toString();
    }

    final fechaLimite = _getDateTimeFromTimestamp(data['fechaLimite']) ??
        _getDateTimeFromTimestamp(data['fechaLimitePostulacion']);
    _sinFechaLimite = data['sinFechaLimite'] == true || fechaLimite == null;

    // Paso 3 (Mismo código de contacto y uniforme)
    final contacto = data['contacto'] as Map<String, dynamic>?;
    if (contacto != null) {
      _contactoNombreController.text = (contacto['nombre'] as String?) ?? '';
      _contactoNumeroController.text = (contacto['numero'] as String?) ?? '';
    }

    _requiereUniforme = data['requiereUniforme'] == true;
    _implementosSeleccionados.addAll(((data['implementosUniforme'] as List?) ?? []).map((e) => e.toString()));
    _instruccionesController.text = data['instrucciones'] ?? '';
    
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  // --- LÓGICA DE SUBIDA DE IMAGEN ---

  Future<void> _seleccionarImagenPrincipal() async {
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

    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 70, // Optimización de calidad
    );

    if (image != null && mounted) {
      setState(() {
        _imagenPrincipal = File(image.path);
        // Limpiamos la URL existente ya que tenemos una nueva imagen local
        _imagenPrincipalUrlExistente = null; 
      });
    }
  }

  // --- OTRAS LÓGICAS (Mantenidas) ---

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

  void _showError(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cargarPlantillas({bool silent = false}) async {
    if (!mounted) return;
    if (_esModoEdicion) return; 

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
      if (!silent) {
        _showError('No se pudieron cargar las plantillas. Intenta nuevamente.');
      }
    }
  }

  Future<void> _abrirCrearPlantilla() async {
    final created = await Navigator.of(context).pushNamed('crear_plantilla');
    if (created == true) {
      await _cargarPlantillas(silent: true);
    }
  }

  TimeOfDay? _timeOfDayFromData(dynamic value) {
    if (value is Map) {
      final hour = value['h'] ?? value['hour'];
      final minute = value['m'] ?? value['minute'];
      if (hour is num && minute is num) {
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
      }
    } else if (value is List && value.length >= 2) {
      final hour = value[0];
      final minute = value[1];
      if (hour is num && minute is num) {
        return TimeOfDay(hour: hour.toInt(), minute: minute.toInt());
      }
    } else if (value is String && value.contains(':')) {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
    return null;
  }

  void _aplicarPlantilla(TrabajoPlantilla plantilla) {
    final data = plantilla.data;
    setState(() {
      _tituloController.text = (data['titulo'] as String?)?.trim() ?? '';
      _descripcionController.text = (data['descripcion'] as String?)?.trim() ?? '';
      _empresaController.text = (data['empresa'] as String?)?.trim() ?? '';
      _imagenPrincipal = null; 
      _imagenPrincipalUrlExistente = data['imagenPrincipalUrl'] as String?;

      // UBICACIÓN Y COORDS (Mantenido)
      _ubicacionDireccionCtrl.text =
          (data['ubicacionDireccion'] as String?)?.trim() ?? '';
      _ubicacionCiudadCtrl.text =
          (data['ubicacionCiudad'] as String?)?.trim() ?? '';
      _ubicacionPaisCtrl.text =
          (data['ubicacionPais'] as String?)?.trim() ?? '';

      final dynamic lat = data['ubicacionLat'];
      final dynamic lng = data['ubicacionLng'];
      final dynamic geo = data['ubicacion'];

      if (geo is GeoPoint) {
        _ubicacionLatLng = LatLng(geo.latitude, geo.longitude);
      } else if (geo is Map<String, dynamic>) {
        _ubicacionLatLng = extractLatLngFromUbicacion(geo);
      } else if (lat is num && lng is num) {
        _ubicacionLatLng = LatLng(lat.toDouble(), lng.toDouble());
      } else {
        _ubicacionLatLng = null;
      }

      // FECHA Y HORA (Mantenido)
      final dynamic fecha = data['fechaTrabajo']; 
      
      if (fecha != null && fecha.runtimeType.toString() == 'Timestamp') {
        _fechaTrabajo = (fecha as Timestamp).toDate();
      } else if (fecha is String) {
        _fechaTrabajo = DateTime.tryParse(fecha);
      } else {
        _fechaTrabajo = null;
      }

      _horaInicio = _timeOfDayFromData(data['horaInicio']);
      _horaFin = _timeOfDayFromData(data['horaFin']);

      final dynamic precio = data['precio'];
      if (precio is num) {
        _precioCtrl.text = precio.toString();
      } else if (precio is String) {
        _precioCtrl.text = precio;
      } else {
        _precioCtrl.clear();
      }

      _sinFechaLimite = data['sinFechaLimite'] == true;

      // CONTACTO (Mantenido)
      final contacto = data['contacto'] as Map<String, dynamic>?;
      if (contacto != null) {
        _contactoNombreController.text = (contacto['nombre'] as String?) ?? '';
        _contactoNumeroController.text = (contacto['numero'] as String?) ?? '';
      }

      _requiereUniforme = data['requiereUniforme'] == true;
      _implementosSeleccionados
        ..clear()
        ..addAll(((data['implementosUniforme'] as List?) ?? [])
            .map((e) => e.toString()));

      _instruccionesController.text =
          (data['instrucciones'] as String?)?.trim() ?? '';
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text('Plantilla "${plantilla.nombre}" aplicada.')),
    );
  }

  Future<void> _mostrarSelectorPlantillas() async {
    await _cargarPlantillas();
    if (!mounted) return;

    if (_esModoEdicion) {
      _showError('No se puede aplicar una plantilla en modo edición.');
      return;
    }

    final resultado = await showDialog<_PlantillaDialogResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plantillas disponibles'),
        content: SizedBox(
          width: double.maxFinite,
          child: _cargandoPlantillas
              ? const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _plantillas.isEmpty
                  ? const Text('Aún no tienes plantillas guardadas.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _plantillas.length,
                      itemBuilder: (context, index) {
                        final plantilla = _plantillas[index];
                        final descripcion =
                            (plantilla.data['descripcion'] as String?) ?? '';
                        return ListTile(
                          title: Text(plantilla.nombre),
                          subtitle: descripcion.isEmpty
                              ? null
                              : Text(
                                  descripcion,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(ctx)
                              .pop(_PlantillaDialogResult.aplicar(plantilla)),
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

    if (resultado.crearNueva) {
      final created = await Navigator.of(context).pushNamed('crear_plantilla');
      if (created == true) {
        await _cargarPlantillas(silent: true);
      }
    } else if (resultado.plantilla != null) {
      _aplicarPlantilla(resultado.plantilla!);
    }
  }

  bool _validarFormularioPaso(int step) {
    final formState = _formKeys[step].currentState;
    if (formState == null) {
      return true;
    }
    final validation = formState.validate();
    
    // NUEVA VALIDACIÓN: Foto principal en el paso 1
    final hasImage = _imagenPrincipal != null || _imagenPrincipalUrlExistente != null;

    if (step == 0 && !hasImage) {
        // Mantenemos la validación básica del formulario, pero avisamos del error de la imagen
        if (!validation) return false; 
        
        _showError('Debe subir una imagen principal para el trabajo.');
        return false;
    }
    
    return validation;
  }

  String? _mensajeValidacionPaso(int step) {
    if (step == 1) {
      final hasAddress =
          _ubicacionDireccionCtrl.text.isNotEmpty && _ubicacionCiudadCtrl.text.isNotEmpty;

      if (_ubicacionLatLng == null && !hasAddress) {
        return 'Debe ingresar una dirección completa o seleccionarla en el mapa.';
      }
      if (_fechaTrabajo == null) {
        return 'Debe seleccionar la fecha del trabajo.';
      }
      if (_horaInicio == null || _horaFin == null) {
        return 'Debe seleccionar la hora de inicio y fin.';
      }
      final ini = _horaInicio!.hour * 60 + _horaInicio!.minute;
      final fin = _horaFin!.hour * 60 + _horaFin!.minute;
      if (ini >= fin) {
        return 'La hora de inicio debe ser anterior a la de fin.';
      }
    }

    if (step == 2 && _requiereUniforme && _implementosSeleccionados.isEmpty) {
      return 'Debe seleccionar al menos un implemento de uniforme.';
    }

    return null;
  }

  Future<bool> _mostrarDialogoPasoIncompleto(String? detalle) async {
    if (!mounted) return false;
    const mensajeBase =
        'Hay campos obligatorios sin completar en este paso. Completa la información antes de continuar.';
    final texto = detalle == null ? mensajeBase : '$mensajeBase\n\nDetalle: $detalle';

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paso incompleto'),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir editando'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    return resultado ?? false;
  }

  Future<bool> _puedeAvanzarDesdePaso(int step) async {
    final formularioValido = _validarFormularioPaso(step);
    final mensaje = _mensajeValidacionPaso(step);
    if (formularioValido && mensaje == null) {
      return true;
    }
    return _mostrarDialogoPasoIncompleto(mensaje);
  }

  bool _validarTodoFormulario() {
    for (var i = 0; i < _formKeys.length; i++) {
      final formularioValido = _validarFormularioPaso(i); 
      final mensaje = _mensajeValidacionPaso(i);
      
      if (!formularioValido || mensaje != null) {
        if (mensaje != null) {
          _showError(mensaje);
        }
        setState(() => _currentStep = i);
        return false;
      }
    }
    return true;
  }

  Future<void> _irAlPaso(int step) async {
    if (step == _currentStep) return;
    if (step < 0 || step >= _getSteps().length) return;

    if (step < _currentStep) {
      setState(() => _currentStep = step);
      return;
    }

    if (await _puedeAvanzarDesdePaso(_currentStep)) {
      if (!mounted) return;
      setState(() => _currentStep = step);
    }
  }

  Future<void> _onStepContinue() async {
    if (_currentStep < _getSteps().length - 1) {
      await _irAlPaso(_currentStep + 1);
    } else {
      await _guardarTrabajo();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  // --- LÓGICA DE GUARDADO/ACTUALIZACIÓN ---
  Future<void> _guardarTrabajo() async {
    if (!_validarTodoFormulario()) {
      return;
    }
    
    setState(() => _isSaving = true);
    String? finalImageUrl; // URL final que se guardará en Firestore
    DocumentReference<Map<String, dynamic>>? nuevoTrabajoRef;
    bool documentoTemporalCreado = false;
    String? trabajoId = widget.trabajoIdParaEditar;

    try {
      // 1. Manejo de la IMAGEN PRINCIPAL (Sube o mantiene la existente)
      // Solo subimos si hay un archivo local nuevo.
      if (_imagenPrincipal != null) {
        if (trabajoId == null) {
          // Creamos un documento preliminar para obtener un ID válido y respetar las reglas de Storage.
          nuevoTrabajoRef = FirebaseFirestore.instance.collection('trabajos').doc();
          trabajoId = nuevoTrabajoRef.id;
          await nuevoTrabajoRef.set({
            'estado': 'creando',
            'creadoEn': FieldValue.serverTimestamp(),
          });
          documentoTemporalCreado = true;
        }

        finalImageUrl = await _storageService.subirImagenPrincipal(
          trabajoId: trabajoId,
          imagen: _imagenPrincipal!,
        );

        if (finalImageUrl == null) {
          throw Exception('No se pudo subir la imagen principal a Storage. Intenta nuevamente.');
        }
      } else if (_esModoEdicion) {
        // En edición, si no se seleccionó una nueva imagen, conservamos la URL anterior.
        finalImageUrl = _imagenPrincipalUrlExistente; 
      } else {
         // En modo creación, si llega aquí sin imagen, es un error de validación grave.
         throw Exception('La imagen principal es obligatoria.');
      }

      if (!_esModoEdicion && trabajoId == null) {
        throw Exception('No se pudo preparar el identificador del trabajo.');
      }   

      // 2. Preparar los datos restantes (Fechas, Horarios, Coordenadas)
      if (_fechaTrabajo == null || _horaInicio == null || _horaFin == null) {
        throw Exception('Falta la información de fecha/horario.');
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

      final DateTime? fechaLimiteFinal = _sinFechaLimite
        ? null
        : trabajoDateTimeStart.subtract(const Duration(hours: 1));
      
      // Obtener coordenadas finales
      LatLng? coords = _ubicacionLatLng;
      if (coords == null && 
          (_ubicacionDireccionCtrl.text.isNotEmpty || _ubicacionCiudadCtrl.text.isNotEmpty || _ubicacionPaisCtrl.text.isNotEmpty)) {
        coords = await _obtenerCoords(
            _ubicacionDireccionCtrl.text,
            _ubicacionCiudadCtrl.text,
            _ubicacionPaisCtrl.text);
        if (coords == null) {
          throw Exception('No se pudo encontrar la ubicación de la dirección proporcionada.');
        }
      } else if (coords == null) {
          throw Exception('Debe proporcionar o seleccionar la ubicación del trabajo.');
      }

      final ubicacionData = buildUbicacionPayload(
        direccion: _ubicacionDireccionCtrl.text,
        ciudad: _ubicacionCiudadCtrl.text,
        pais: _ubicacionPaisCtrl.text,
        coordenadas: coords,
      );

      final contactoData = {
        'nombre': _contactoNombreController.text,
        'numero': _contactoNumeroController.text,
      };

      // 3. Llamar al servicio de trabajo con la URL
      if (_esModoEdicion && widget.trabajoIdParaEditar != null) {
        await _trabajoService.actualizarTrabajo(
          trabajoId: widget.trabajoIdParaEditar!,
          titulo: _tituloController.text,
          descripcion: _descripcionController.text,
          empresa: _empresaController.text,
          ubicacion: ubicacionData,
          fechaLimite: fechaLimiteFinal,
          fechaInicioTrabajo: trabajoDateTimeStart,
          fechaFinTrabajo: trabajoDateTimeEnd,
          precio: double.tryParse(_precioCtrl.text) ?? 0,
          instrucciones: _instruccionesController.text,
          requiereUniforme: _requiereUniforme,
          implementosUniforme: _implementosSeleccionados.toList(),
          contacto: contactoData,
          sinFechaLimite: _sinFechaLimite,
          imagenPrincipalUrl: finalImageUrl, // ENVIAR URL
        );
         if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Trabajo actualizado con éxito.')));
            Navigator.pop(context, true); 
          }
      } else {
        await _trabajoService.crearTrabajo(
          titulo: _tituloController.text,
          descripcion: _descripcionController.text,
          empresa: _empresaController.text,
          ubicacion: ubicacionData,
          fechaLimite: fechaLimiteFinal,
          fechaInicioTrabajo: trabajoDateTimeStart,
          fechaFinTrabajo: trabajoDateTimeEnd,
          precio: double.tryParse(_precioCtrl.text) ?? 0,
          instrucciones: _instruccionesController.text,
          requiereUniforme: _requiereUniforme,
          implementosUniforme: _implementosSeleccionados.toList(),
          contacto: contactoData,
          sinFechaLimite: _sinFechaLimite,
          imagenPrincipalUrl: finalImageUrl, // ENVIAR URL
          trabajoId: trabajoId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Trabajo publicado con éxito.')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (documentoTemporalCreado && nuevoTrabajoRef != null) {
        await nuevoTrabajoRef.delete().catchError((_) {});
      }
      if (mounted) {
        _showError('Error al guardar el trabajo: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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

  // --- WIDGETS DE PASOS (Contenido) ---

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NUEVO: Campo de Selección de Imagen
        _buildImagePickerField(),
        const SizedBox(height: 20),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('titulo'),
            controller: _tituloController,
            decoration: const InputDecoration(labelText: 'Nombre de trabajo / Puesto'),
            validator: (value) {
              return value == null || value.isEmpty ? 'Requerido' : null;
            },
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
            validator: (value) {
              return value == null || value.isEmpty ? 'Requerido' : null;
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('empresa'),
            controller: _empresaController,
            decoration: const InputDecoration(labelText: 'Empresa o Cliente'),
            maxLength: 30,
            validator: (value) {
              return value == null || value.isEmpty ? 'Requerido' : null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImagePickerField() {
    final hasLocalImage = _imagenPrincipal != null;
    final hasExistingUrl = _imagenPrincipalUrlExistente != null && _imagenPrincipalUrlExistente!.isNotEmpty;
    final showNetwork = !hasLocalImage && hasExistingUrl;
    
    Widget imageWidget;
    
    if (hasLocalImage) {
      // Muestra la imagen recién seleccionada
      imageWidget = Image.file(_imagenPrincipal!, fit: BoxFit.cover);
    } else if (showNetwork) {
      // Muestra la imagen existente si está en modo edición
      imageWidget = Image.network(_imagenPrincipalUrlExistente!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
        return const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey, size: 50));
      });
    } else {
      // Muestra el placeholder
      imageWidget = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 40, color: Colors.white70),
            SizedBox(height: 8),
            Text('Añadir Imagen Principal', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _isSaving ? null : _seleccionarImagenPrincipal,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasLocalImage || hasExistingUrl ? Colors.transparent : _errorColor,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            // Overlay de carga
            if (_isSaving)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 8),
                      Text('Guardando imagen...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            
            // Botón de cámara flotante
            Positioned(
              bottom: 8,
              right: 8,
              child: FloatingActionButton.small(
                onPressed: _isSaving ? null : _seleccionarImagenPrincipal,
                child: const Icon(Icons.edit, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Content() {
    // Calculamos la hora límite (1 hora antes de la fecha de inicio del trabajo)
    DateTime? fechaLimiteAuto;
    if (!_sinFechaLimite && _fechaTrabajo != null && _horaInicio != null) {
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
              onPressed: _isSaving ? null : () async {
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
              onPressed: _isSaving ? null : () async {
                // Simulación de pantalla de mapa
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

        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _sinFechaLimite
                  ? _primaryColor
                  : Colors.grey.shade300,
            ),
            color: _sinFechaLimite
                ? _primaryColor.withOpacity(0.08)
                : Colors.grey.shade100,
          ),
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: Icon(
              _sinFechaLimite ? Icons.lock_open_rounded : Icons.schedule_rounded,
              color: _sinFechaLimite ? _primaryColor : Colors.grey.shade700,
            ),
            value: _sinFechaLimite,
            onChanged: _isSaving ? null : (value) {
              FocusScope.of(context).unfocus();
              setState(() {
                _sinFechaLimite = value;
              });
            },
            title: Text(
              'Mantener postulaciones abiertas',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Activa esta opción para crear trabajos de prueba sin fecha límite de postulación.',
            ),
          ),
        ),

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
                  _sinFechaLimite
                      ? '🔓 Las postulaciones permanecerán abiertas hasta que cierres el trabajo manualmente.'
                      : (fechaLimiteAuto == null
                          ? 'La fecha límite de postulación aparecerá aquí (ej: 1 hora antes del inicio).'
                          : '📅 Límite de Postulación: ${_formatFechaHora(fechaLimiteAuto)}.'),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 30),

        // --- PAGO ---
        Text('Remuneración', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: _primaryColor)),
        
        // Pago a trabajador
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
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
            enabled: !_isSaving,
            decoration: const InputDecoration(labelText: 'Nombre de contacto'),
            validator: (value) {
              return value == null || value.isEmpty ? 'Requerido' : null;
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextFormField(
            key: const ValueKey('contacto_numero'),
            controller: _contactoNumeroController,
            enabled: !_isSaving,
            decoration: const InputDecoration(labelText: 'Número de contacto (Ej: +569...)'),
            keyboardType: TextInputType.phone,
            validator: (value) {
              return value == null || value.isEmpty ? 'Requerido' : null;
            },
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
                  onChanged: _isSaving ? null : (v) => setState(() {
                    _requiereUniforme = v;
                    if (!v) _implementosSeleccionados.clear();
                  }),
                  activeThumbColor: _primaryColor,
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
              onSelected: _isSaving ? null : (v) => setState(() {
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
            enabled: !_isSaving,
            decoration: const InputDecoration(labelText: 'Instrucciones/Notas especiales (Máx 1000 caracteres)'),
            maxLines: 4,
            maxLength: 1000,
            validator: (value) {
              return value == null || value.isEmpty ? 'Requerido' : null;
            },
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
        onTap: _isSaving ? null : () async {
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
        onTap: _isSaving ? null : () async {
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
      physics: const ClampingScrollPhysics(), 
      onStepTapped: (step) {
        _irAlPaso(step);
      },
      steps: _getSteps(),
      controlsBuilder: (context, details) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _primaryColor = Theme.of(context).colorScheme.primary;
    _secondaryColor = Theme.of(context).colorScheme.secondary;
    _errorColor = Theme.of(context).colorScheme.error;
    
    final isLast = _currentStep == _getSteps().length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(_esModoEdicion ? 'Editar Oferta de Trabajo' : 'Crear Nueva Oferta de Trabajo'),
        actions: [
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
              itemBuilder: (context) {
                return const [
                  PopupMenuItem(
                    value: _MenuPlantillaOption.aplicar,
                    child: Text('Aplicar plantilla'),
                  ),
                  PopupMenuItem(
                    value: _MenuPlantillaOption.crear,
                    child: Text('Crear plantilla'),
                  ),
                ];
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            Expanded(child: _buildCustomStepper()),
          ],
        ),
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
              onPressed: _isSaving ? null : _onStepCancel,
              child: Text(
                _currentStep == 0 ? 'CANCELAR' : 'ATRÁS',
                style: TextStyle(
                  color: _currentStep == 0 ? _errorColor : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Botón Siguiente/Publicar
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () async {
                await _onStepContinue();
              },
              icon: _isSaving 
                  ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(
                      isLast ? Icons.save : Icons.arrow_forward,
                      color: Colors.white,
                    ),
              label: Text(
                isLast 
                  ? (_esModoEdicion ? 'GUARDAR CAMBIOS' : 'PUBLICAR TRABAJO') 
                  : 'SIGUIENTE',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isLast ? (_esModoEdicion ? Colors.green.shade600 : _primaryColor) : _primaryColor,
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
