import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/theme/app_colors.dart';

// Constantes de color para mantener la estética
const Color _PRIMARY_COLOR = AppColors.primary; 
const Color _ACCENT_COLOR = AppColors.accent;

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

  // Controladores de nuevos campos solicitados
  final _descripcionController = TextEditingController();
  final _ocupacionController = TextEditingController();
  final _carreraController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  bool _hasUnsavedChanges = false;
  bool _isInitializingControllers = false;

  String _initialNombre = '';
  String _initialApellido = '';
  String _initialTelefono = '';
  String _initialDescripcion = '';
  String _initialOcupacion = '';
  String _initialCarrera = '';

  @override
  void initState() {
    super.initState();
    _nombreController.addListener(_handleFormChanges);
    _apellidoController.addListener(_handleFormChanges);
    _telefonoController.addListener(_handleFormChanges);
    _descripcionController.addListener(_handleFormChanges);
    _ocupacionController.addListener(_handleFormChanges);
    _carreraController.addListener(_handleFormChanges);
    _cargarDatosUsuario();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _descripcionController.dispose();
    _ocupacionController.dispose();
    _carreraController.dispose();
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

        // Cargar nuevos datos
        _descripcionController.text = data['descripcion'] ?? '';
        _ocupacionController.text = data['ocupacion'] ?? '';
        _carreraController.text = data['carrera'] ?? '';
      }

      _setInitialValues();
    } catch (e) {
      // Usamos debugPrint o log en lugar de asignar al mensaje de error de la UI
      debugPrint('Error al cargar los datos: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ocurrió un error al cargar su información.';
        });
      }
    } finally {
      _isInitializingControllers = false;
      if (!mounted) return;
      _handleFormChanges();
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
        
        // Guardar nuevos datos
        'descripcion': _descripcionController.text.trim(),
        'ocupacion': _ocupacionController.text.trim(),
        'carrera': _carreraController.text.trim(),
      };

      await _firestore.collection('usuarios').doc(_user.uid).set(userData, SetOptions(merge: true));

      if (mounted) {
        _setInitialValues();
        setState(() {
          _hasUnsavedChanges = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado con exito!')),
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
          title: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
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
            ? const Center(child: CircularProgressIndicator(color: _PRIMARY_COLOR))
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
                          const Text(
                            'Información Personal',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _PRIMARY_COLOR,
                            ),
                          ),
                          const Divider(color: _PRIMARY_COLOR),
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
                            label: 'Telefono',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),
                          // --- SECCIÓN PERFIL PROFESIONAL ---
                          const Text(
                            'Perfil Profesional',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _PRIMARY_COLOR,
                            ),
                          ),
                          const Divider(color: _PRIMARY_COLOR),
                          _buildTextField(
                            controller: _descripcionController,
                            label: 'Sobre mí (Descripción)',
                            icon: Icons.notes,
                            maxLines: 4,
                          ),
                          _buildTextField(
                            controller: _ocupacionController,
                            label: 'Ocupación principal',
                            icon: Icons.work_outline,
                          ),
                          _buildTextField(
                            controller: _carreraController,
                            label: 'Carrera / Estudios',
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _guardarPerfil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _PRIMARY_COLOR,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
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
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1, // Añadido para soportar la descripción
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines, // Utiliza el parámetro maxLines
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
          if (value == null || value.isEmpty) {
            return 'Este campo es obligatorio';
          }
          return null;
        },
      ),
    );
  }

  void _setInitialValues() {
    _initialNombre = _nombreController.text;
    _initialApellido = _apellidoController.text;
    _initialTelefono = _telefonoController.text;
    _initialDescripcion = _descripcionController.text;
    _initialOcupacion = _ocupacionController.text;
    _initialCarrera = _carreraController.text;
  }

  void _handleFormChanges() {
    if (_isInitializingControllers) return;
    if (!mounted) return;

    final hasChanges = _nombreController.text != _initialNombre ||
        _apellidoController.text != _initialApellido ||
        _telefonoController.text != _initialTelefono ||
        _descripcionController.text != _initialDescripcion ||
        _ocupacionController.text != _initialOcupacion ||
        _carreraController.text != _initialCarrera;

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
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }
}