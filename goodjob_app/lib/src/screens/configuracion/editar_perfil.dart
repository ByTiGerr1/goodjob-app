import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import 'package:collection/collection.dart';

// Constantes de color para mantener la estética
const Color _PRIMARY_COLOR = AppColors.primary;
const Color _ACCENT_COLOR = AppColors.accent;

// MODIFICADO: Modelo de datos para Experiencia (versión "Chill")
class Experiencia {
  String rol; // Antes 'puesto'
  String lugarOProyecto; // Antes 'empresa'
  String descripcion;

  Experiencia({
    required this.rol,
    required this.lugarOProyecto,
    required this.descripcion,
  });

  // Convierte un objeto Experiencia a un Mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'rol': rol,
      'lugarOProyecto': lugarOProyecto,
      'descripcion': descripcion,
    };
  }

  // Crea un objeto Experiencia desde un Mapa de Firestore
  // Con retrocompatibilidad para leer campos antiguos si los nuevos no existen
  factory Experiencia.fromMap(Map<String, dynamic> map) {
    return Experiencia(
      rol: map['rol'] ?? map['puesto'] ?? '',
      lugarOProyecto: map['lugarOProyecto'] ?? map['empresa'] ?? '',
      descripcion: map['descripcion'] ?? '',
    );
  }
}

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  // Controladores de campos básicos
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();

  // Controladores de campos de perfil
  final _descripcionController = TextEditingController();
  final _carreraController = TextEditingController();
  // NUEVO: Controlador para el campo 'Otro' de ocupación
  final _otraOcupacionController = TextEditingController();

  // --- Estado para Ocupación ---
  String? _selectedOcupacion;
  final List<String> _opcionesOcupacion = [
    'Estudiante',
    'Empleado',
    'Independiente',
    'Desempleado',
    'Otro'
  ];

  // --- Estado para Habilidades ---
  final _habilidadController = TextEditingController();
  List<String> _habilidades = [];

  // --- Estado para Experiencia ---
  List<Experiencia> _experiencias = [];

  bool _isLoading = true;
  String? _errorMessage;
  bool _hasUnsavedChanges = false;
  bool _isInitializingControllers = false;

  // Valores iniciales para detectar cambios
  String _initialNombre = '';
  String _initialApellido = '';
  String _initialTelefono = '';
  String _initialDescripcion = '';
  String _initialOcupacion = '';
  String _initialCarrera = '';
  // NUEVO: Valor inicial para 'Otra Ocupación'
  String _initialOtraOcupacion = '';
  List<String> _initialHabilidades = [];
  List<Experiencia> _initialExperiencias = [];

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(_checkForChanges);
    _apellidoController.addListener(_checkForChanges);
    _telefonoController.addListener(_checkForChanges);
    _descripcionController.addListener(_checkForChanges);
    _carreraController.addListener(_checkForChanges);
    // NUEVO: Listener para el nuevo controlador
    _otraOcupacionController.addListener(_checkForChanges);
    _cargarDatosUsuario();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _descripcionController.dispose();
    _carreraController.dispose();
    // NUEVO: dispose del nuevo controlador
    _otraOcupacionController.dispose();
    _habilidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    if (_user == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Usuario no autenticado.';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('usuarios').doc(_user.uid).get();
      final data = doc.data();

      _isInitializingControllers = true;

      if (data != null) {
        // Cargar datos básicos
        _nombreController.text = data['nombre'] ?? '';
        _apellidoController.text = data['apellido'] ?? '';
        _telefonoController.text = data['telefono'] ?? '';
        _descripcionController.text = data['descripcion'] ?? '';
        _carreraController.text = data['carrera'] ?? '';
        
        // NUEVO: Cargar 'otraOcupacion'
        _otraOcupacionController.text = data['otraOcupacion'] ?? '';

        // Cargar ocupación (Dropdown)
        String? ocupacionCargada = data['ocupacion'];
        if (ocupacionCargada != null &&
            _opcionesOcupacion.contains(ocupacionCargada)) {
          _selectedOcupacion = ocupacionCargada;
        }

        // Cargar habilidades (Lista de Strings)
        if (data['habilidades'] != null && data['habilidades'] is List) {
          _habilidades = List<String>.from(data['habilidades']);
        }

        // Cargar experiencias (Lista de Mapas)
        if (data['experiencias'] != null && data['experiencias'] is List) {
          _experiencias = (data['experiencias'] as List)
              .map((e) => Experiencia.fromMap(e as Map<String, dynamic>))
              .toList();
        }
      }

      _setInitialValues();
    } catch (e) {
      debugPrint('Error al cargar los datos: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ocurrió un error al cargar su información.';
        });
      }
    } finally {
      _isInitializingControllers = false;
      if (!mounted) return;
      _checkForChanges();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate() || _user == null) return;

    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final userData = {
        'nombre': _nombreController.text.trim(),
        'apellido': _apellidoController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        
        'ocupacion': _selectedOcupacion ?? '',
        
        // NUEVO: Lógica condicional para guardar 'carrera' y 'otraOcupacion'
        // Solo guarda 'carrera' si es Estudiante, si no, guarda vacío.
        'carrera': _selectedOcupacion == 'Estudiante'
            ? _carreraController.text.trim()
            : '',
        // Solo guarda 'otraOcupacion' si es Otro, si no, guarda vacío.
        'otraOcupacion': _selectedOcupacion == 'Otro'
            ? _otraOcupacionController.text.trim()
            : '',
            
        'habilidades': _habilidades,
        'experiencias': _experiencias.map((e) => e.toMap()).toList(),
      };

      await _firestore
          .collection('usuarios')
          .doc(_user.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        _setInitialValues();
        setState(() {
          _hasUnsavedChanges = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado con éxito!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar el perfil: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar Perfil',
              style: TextStyle(fontWeight: FontWeight.bold)),
          leading: BackButton(
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ),
        body: _isLoading && _errorMessage == null
            ? const Center(
                child: CircularProgressIndicator(color: _PRIMARY_COLOR))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Error: $_errorMessage',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SECCIÓN INFORMACIÓN PERSONAL ---
                          _buildSectionTitle('Información Personal'),
                          _buildTextField(
                            controller: _nombreController,
                            label: 'Nombre(s)',
                            icon: Icons.person_outline,
                          ),
                          _buildTextField(
                            controller: _apellidoController,
                            label: 'Apellido(s)',
                            icon: Icons.person_outline,
                          ),
                          _buildTextField(
                            controller: _telefonoController,
                            label: 'Teléfono',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            isOptional: true, // MODIFICADO: Ahora es opcional
                          ),
                          const SizedBox(height: 20),

                          // --- SECCIÓN PERFIL PROFESIONAL ---
                          _buildSectionTitle('Perfil Profesional'),
                          _buildTextField(
                            controller: _descripcionController,
                            label: 'Sobre mí (Descripción)',
                            icon: Icons.notes,
                            maxLines: 4,
                            isOptional: true, // MODIFICADO: Ahora es opcional
                          ),
                          _buildOcupacionDropdown(),

                          // NUEVO: Campo condicional para 'Otro'
                          if (_selectedOcupacion == 'Otro')
                            _buildTextField(
                              controller: _otraOcupacionController,
                              label: 'Especifica tu ocupación',
                              icon: Icons.description_outlined,
                            ),

                          // Campo condicional para 'Estudiante'
                          if (_selectedOcupacion == 'Estudiante')
                            _buildTextField(
                              controller: _carreraController,
                              label: 'Carrera / Estudios',
                              icon: Icons.school_outlined,
                              isOptional: true, // Carrera también es opcional
                            ),

                          // --- SECCIÓN HABILIDADES ---
                          const SizedBox(height: 20),
                          _buildSectionTitle('Habilidades'),
                          _buildHabilidadesSection(), // Es opcional por diseño

                          // --- SECCIÓN EXPERIENCIA ---
                          const SizedBox(height: 20),
                          // MODIFICADO: Título "Chill"
                          _buildSectionTitle('Mi Experiencia'), 
                          _buildExperienciaSection(), // Es opcional por diseño

                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed:
                                _isLoading || !_hasUnsavedChanges
                                    ? null
                                    : _guardarPerfil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _PRIMARY_COLOR,
                              disabledBackgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'GUARDAR CAMBIOS',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // Widget para títulos de sección
  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _PRIMARY_COLOR,
          ),
        ),
        const Divider(color: _PRIMARY_COLOR),
      ],
    );
  }

  // MODIFICADO: _buildTextField ahora soporta 'isOptional'
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isOptional = false, // Permite que el campo sea opcional
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _PRIMARY_COLOR),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _PRIMARY_COLOR, width: 2),
          ),
        ),
        validator: (value) {
          // MODIFICADO: Solo valida si no es opcional
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'Este campo es obligatorio';
          }
          return null;
        },
      ),
    );
  }

  // Widget para el Dropdown de Ocupación
  Widget _buildOcupacionDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: DropdownButtonFormField<String>(
        value: _selectedOcupacion,
        hint: const Text('Selecciona tu ocupación'),
        icon: const Icon(Icons.arrow_drop_down),
        decoration: InputDecoration(
          labelText: 'Ocupación principal',
          prefixIcon: const Icon(Icons.work_outline, color: _PRIMARY_COLOR),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _PRIMARY_COLOR, width: 2),
          ),
        ),
        items: _opcionesOcupacion.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            _selectedOcupacion = newValue;
          });
          _checkForChanges();
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Este campo es obligatorio';
          }
          return null;
        },
      ),
    );
  }

  // --- Métodos para Habilidades ---

  Widget _buildHabilidadesSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _habilidadController,
                decoration: InputDecoration(
                  labelText: 'Añadir habilidad (ej: Liderazgo)',
                  prefixIcon:
                      const Icon(Icons.star_border, color: _PRIMARY_COLOR),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onFieldSubmitted: (_) =>
                    _addHabilidad(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: _PRIMARY_COLOR),
              onPressed: _addHabilidad,
              tooltip: 'Añadir habilidad',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _habilidades.map((habilidad) {
              return Chip(
                label: Text(habilidad),
                backgroundColor: _PRIMARY_COLOR.withOpacity(0.1),
                deleteIconColor: _PRIMARY_COLOR,
                onDeleted: () => _removeHabilidad(habilidad),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _addHabilidad() {
    final nuevaHabilidad = _habilidadController.text.trim();
    if (nuevaHabilidad.isNotEmpty && !_habilidades.contains(nuevaHabilidad)) {
      setState(() {
        _habilidades.add(nuevaHabilidad);
        _habilidadController.clear();
      });
      _checkForChanges();
    }
  }

  void _removeHabilidad(String habilidad) {
    setState(() {
      _habilidades.remove(habilidad);
    });
    _checkForChanges();
  }

  // --- Métodos para Experiencia ---

  Widget _buildExperienciaSection() {
    return Column(
      children: [
        if (_experiencias.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
                child: Text('Aún no has añadido experiencia.',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _experiencias.length,
            itemBuilder: (context, index) {
              return _buildExperienciaCard(_experiencias[index], index);
            },
          ),
        TextButton.icon(
          icon: const Icon(Icons.add, color: _PRIMARY_COLOR),
          label:
              const Text('Añadir Experiencia', style: TextStyle(color: _PRIMARY_COLOR)),
          onPressed: () => _showExperienciaDialog(),
        ),
      ],
    );
  }

  // MODIFICADO: Tarjeta de experiencia "Chill"
  Widget _buildExperienciaCard(Experiencia exp, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        title: Text(exp.rol, // Muestra 'rol'
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${exp.lugarOProyecto}\n${exp.descripcion}"), // Muestra 'lugarOProyecto'
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
              onPressed: () => _showExperienciaDialog(exp: exp, index: index),
              tooltip: 'Editar',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _removeExperiencia(index),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  void _removeExperiencia(int index) {
    setState(() {
      _experiencias.removeAt(index);
    });
    _checkForChanges();
  }

  // MODIFICADO: Diálogo de experiencia "Chill"
  Future<void> _showExperienciaDialog({Experiencia? exp, int? index}) async {
    final dialogFormKey = GlobalKey<FormState>();
    final rolController = TextEditingController(text: exp?.rol);
    final lugarController = TextEditingController(text: exp?.lugarOProyecto);
    final descripcionController = TextEditingController(text: exp?.descripcion);

    final bool isEditing = exp != null;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Experiencia' : 'Añadir Experiencia'),
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: rolController,
                    decoration:
                        const InputDecoration(labelText: 'Rol o Actividad'), // Etiqueta
                    validator: (v) =>
                        v!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: lugarController,
                    decoration:
                        const InputDecoration(labelText: 'Lugar o Proyecto'), // Etiqueta
                    validator: (v) =>
                        v!.isEmpty ? 'Campo obligatorio' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descripcionController,
                    decoration:
                        const InputDecoration(labelText: 'Descripción (Opcional)'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _PRIMARY_COLOR),
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  final nuevaExp = Experiencia(
                    rol: rolController.text.trim(),
                    lugarOProyecto: lugarController.text.trim(),
                    descripcion: descripcionController.text.trim(),
                  );
                  setState(() {
                    if (isEditing && index != null) {
                      _experiencias[index] = nuevaExp;
                    } else {
                      _experiencias.add(nuevaExp);
                    }
                  });
                  _checkForChanges();
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // --- Métodos para detectar cambios ---

  void _setInitialValues() {
    _initialNombre = _nombreController.text;
    _initialApellido = _apellidoController.text;
    _initialTelefono = _telefonoController.text;
    _initialDescripcion = _descripcionController.text;
    _initialCarrera = _carreraController.text;
    _initialOcupacion = _selectedOcupacion ?? '';
    // NUEVO: Guardar estado inicial de 'otraOcupacion'
    _initialOtraOcupacion = _otraOcupacionController.text;
    _initialHabilidades = List.from(_habilidades);
    _initialExperiencias =
        _experiencias.map((e) => Experiencia.fromMap(e.toMap())).toList();
  }

  // MODIFICADO: Comprueba todos los campos, incluyendo 'otraOcupacion'
  void _checkForChanges() {
    if (_isInitializingControllers) return;
    if (!mounted) return;

    final bool textFieldsChanged = _nombreController.text != _initialNombre ||
        _apellidoController.text != _initialApellido ||
        _telefonoController.text != _initialTelefono ||
        _descripcionController.text != _initialDescripcion ||
        _carreraController.text != _initialCarrera ||
        // NUEVO: Comprobar 'otraOcupacion'
        _otraOcupacionController.text != _initialOtraOcupacion;

    final bool ocupacionChanged =
        (_selectedOcupacion ?? '') != _initialOcupacion;

    final bool skillsChanged =
        !const ListEquality().equals(_habilidades, _initialHabilidades);

    final bool expChanged = !const DeepCollectionEquality().equals(
        _experiencias.map((e) => e.toMap()).toList(),
        _initialExperiencias.map((e) => e.toMap()).toList());

    final hasChanges =
        textFieldsChanged || ocupacionChanged || skillsChanged || expChanged;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          'Tienes cambios sin guardar. ¿Deseas descartar los cambios o seguir editando?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }
}
