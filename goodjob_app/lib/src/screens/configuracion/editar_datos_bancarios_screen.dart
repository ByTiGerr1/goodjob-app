import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constantes de color para mantener la estetica
const Color _PRIMARY_COLOR = Color(0xFF7B0997); 
const Color _ACCENT_COLOR = Color(0xFFFFD900);

class EditarDatosBancariosScreen extends StatefulWidget {
  const EditarDatosBancariosScreen({super.key});

  @override
  State<EditarDatosBancariosScreen> createState() => _EditarDatosBancariosScreenState();
}

class _EditarDatosBancariosScreenState extends State<EditarDatosBancariosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  // Controladores de información bancaria
  final _bancoController = TextEditingController();
  final _tipoCuentaController = TextEditingController();
  final _numeroCuentaController = TextEditingController();
  final _rutController = TextEditingController(); // RUT (ahora top-level)

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatosBancarios();
  }

  @override
  void dispose() {
    _bancoController.dispose();
    _tipoCuentaController.dispose();
    _numeroCuentaController.dispose();
    _rutController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosBancarios() async {
    if (_user == null) {
      setState(() {
        _errorMessage = 'Usuario no autenticado.';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('usuarios').doc(_user.uid).get();
      final data = doc.data();

      if (data != null) {
        // 1. Cargar RUT desde el nivel superior (top-level)
        // El RUT no está cifrado y puede ser cargado.
        _rutController.text = data['rut'] ?? ''; 
        
        // 2. OMITIR CARGA DE DATOS BANCARIOS CIFRADOS:
        // Si los datos bancarios estan cifrados, no se pueden mostrar
        // al usuario. Los campos del banco se inicializaran vacios.
        
        // La logica anterior que causaba problemas se ha eliminado:
        /*
        final dynamic rawBankDetails = data['datosBancarios'];
        final Map<String, dynamic>? bankDetails = 
            (rawBankDetails is Map<String, dynamic>) ? rawBankDetails : null;
        
        if (bankDetails != null) {
          _bancoController.text = bankDetails['banco'] ?? ''; 
          _tipoCuentaController.text = bankDetails['tipoCuenta'] ?? '';
          _numeroCuentaController.text = bankDetails['numeroCuenta'] ?? '';
        }
        */
      }
    } catch (e) {
      debugPrint('Error al cargar los datos: $e'); 
      _errorMessage = 'Ocurrio un error al cargar su informacion bancaria.';
    } finally {
      // Reconstruir la UI para mostrar los datos cargados o el error
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarDatosBancarios() async {
    if (!_formKey.currentState!.validate() || _user == null) return;

    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final bankDataToSave = {
        // 1. Guardar RUT en el nivel superior
        'rut': _rutController.text.trim(), 
        
        // 2. Guardar datos bancarios anidados bajo 'datosBancarios'
        // Estos datos se guardan en texto plano y se asume que el backend los cifra.
        'datosBancarios': {
          'banco': _bancoController.text.trim(),
          'tipoCuenta': _tipoCuentaController.text.trim(),
          'numeroCuenta': _numeroCuentaController.text.trim(),
        },
      };

      await _firestore.collection('usuarios').doc(_user.uid).set(bankDataToSave, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos bancarios actualizados con exito!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al guardar los datos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualizar Datos Bancarios', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading && _errorMessage == null
          ? const Center(child: CircularProgressIndicator(color: _PRIMARY_COLOR))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('Error: $_errorMessage', style: TextStyle(color: Colors.red.shade700)),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SECCION DATOS BANCARIOS ---
                        
                        _buildTextField(
                          controller: _rutController,
                          label: 'RUT / Identificacion',
                          icon: Icons.badge_outlined,
                        ),
                        _buildTextField(
                          controller: _bancoController,
                          label: 'Nombre del Banco',
                          icon: Icons.account_balance,
                        ),
                        _buildTextField(
                          controller: _tipoCuentaController,
                          label: 'Tipo de Cuenta (ej: Corriente)',
                          icon: Icons.account_tree_outlined,
                        ),
                        _buildTextField(
                          controller: _numeroCuentaController,
                          label: 'Numero de Cuenta',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 40),

                        // --- BOTON DE GUARDAR ---
                        ElevatedButton(
                          onPressed: _isLoading ? null : _guardarDatosBancarios,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _PRIMARY_COLOR,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('GUARDAR DATOS BANCARIOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
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
}
