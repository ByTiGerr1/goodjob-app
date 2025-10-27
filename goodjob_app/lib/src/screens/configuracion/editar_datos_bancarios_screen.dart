import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goodjob_app/theme/app_colors.dart';
import '../../utils/rut_input_formatter.dart';
import '../../utils/rut_utils.dart';

import '../../services/encryption_service.dart';

// Constantes de color para mantener la estetica
const Color _PRIMARY_COLOR = AppColors.primary;
const Color _ACCENT_COLOR = AppColors.accent;

class EditarDatosBancariosScreen extends StatefulWidget {
  const EditarDatosBancariosScreen({super.key});

  @override
  State<EditarDatosBancariosScreen> createState() => _EditarDatosBancariosScreenState();
}

class _EditarDatosBancariosScreenState extends State<EditarDatosBancariosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  final _numeroCuentaController = TextEditingController();
  final _rutController = TextEditingController();

  final List<String> _banks = [
    'Banco Estado',
    'Banco de Chile',
    'Banco Santander',
    'Banco BCI',
    'Banco Itaú',
    'Scotiabank',
    'Banco Security',
    'Banco Falabella',
    'Banco Ripley',
    'Banco Consorcio',
    'Banco Internacional',
    'Banco BICE',
  ];

  final List<String> _baseAccountTypes = [
    'Cuenta corriente',
    'Cuenta vista',
    'Cuenta de ahorro',
  ];
  static const String _rutAccountType = 'Cuenta RUT';

  String? _selectedBankName;
  String? _selectedAccountType;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _hasUnsavedChanges = false;
  bool _isInitializingControllers = false;

  String _initialBanco = '';
  String _initialTipoCuenta = '';
  String _initialNumeroCuenta = '';
  String _initialRut = '';

  @override
  void initState() {
    super.initState();
    _numeroCuentaController.addListener(_handleFormChanges);
     _rutController.addListener(_onRutChanged);
    _cargarDatosBancarios();
  }

  @override
  void dispose() {
    _numeroCuentaController.dispose();
    _rutController.dispose();
    super.dispose();
  }

  List<String> _accountTypeOptionsForBank(String? bank, {String? includeType}) {
    final options = List<String>.from(_baseAccountTypes);
    if (bank == 'Banco Estado') {
      options.add(_rutAccountType);
    }
    if (includeType != null && includeType.isNotEmpty && !options.contains(includeType)) {
      options.add(includeType);
    }
    return options;
  }

  Future<void> _cargarDatosBancarios() async {
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

      String? normalizedBankName;
      String? normalizedAccountNumber;
      String? normalizedAccountType;

      if (data != null) {
        final String rut = data['rut'] is String ? data['rut'] as String : '';
        _rutController.text = RutUtils.format(rut);

        final encryption = EncryptionService();

        Future<String?> decryptField(dynamic value) async {
          if (value == null) return null;
          if (value is! String) return value.toString();
          if (value.trim().isEmpty) return value;
          try {
            return await encryption.decrypt(value);
          } catch (_) {
            return value;
          }
        }

        String? bankName = await decryptField(data['banco']);
        String? accountNumber = await decryptField(data['numeroCuenta']);
        String? accountType = await decryptField(data['tipoCuenta']);

        final dynamic bankData = data['datosBancarios'];
        if ((bankName == null || bankName.trim().isEmpty) && bankData is Map<String, dynamic>) {
          bankName = await decryptField(bankData['banco'] ?? bankData['bankName']);
          accountNumber = await decryptField(bankData['numeroCuenta'] ?? bankData['accountNumber']);
          accountType = await decryptField(bankData['tipoCuenta'] ?? bankData['accountType']);
        }

        normalizedBankName = (bankName != null && bankName.trim().isNotEmpty) ? bankName.trim() : null;
        normalizedAccountNumber = accountNumber != null ? accountNumber.trim() : null;
        normalizedAccountType = (accountType != null && accountType.trim().isNotEmpty) ? accountType.trim() : null;
      } else {
        _rutController.text = '';
        normalizedBankName = null;
        normalizedAccountNumber = null;
        normalizedAccountType = null;
      }

      if (normalizedBankName != null && !_banks.contains(normalizedBankName)) {
        _banks.add(normalizedBankName);
      }

      _numeroCuentaController.text = normalizedAccountNumber ?? '';

      if (!mounted) return;
      setState(() {
        _selectedBankName = normalizedBankName;
        _selectedAccountType = normalizedAccountType;
      });

      _syncAccountNumberWithRut();
      _setInitialValues();
    } catch (e) {
      debugPrint('Error al cargar los datos: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ocurrio un error al cargar su informacion bancaria.';
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

  Future<void> _guardarDatosBancarios() async {
    if (!_formKey.currentState!.validate() || _user == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final encryption = EncryptionService();

      final rutNormalizado = RutUtils.normalize(_rutController.text);
      final bankName = _selectedBankName?.trim() ?? '';
      final accountType = _selectedAccountType?.trim() ?? '';
      final accountNumber = _selectedAccountType == _rutAccountType
          ? RutUtils.bodyWithoutVerifier(_rutController.text)
          : _numeroCuentaController.text.trim();

      if (_selectedAccountType == _rutAccountType) {
        _numeroCuentaController.text = accountNumber;
      }
      final encryptedBank = await encryption.encrypt(bankName);
      final encryptedAccountType = await encryption.encrypt(accountType);
      final encryptedAccountNumber = await encryption.encrypt(accountNumber);

      final bankDataToSave = {
        'rut': rutNormalizado,
        'banco': encryptedBank,
        'numeroCuenta': encryptedAccountNumber,
        'tipoCuenta': encryptedAccountType,
        'datosBancarios': {
          'banco': encryptedBank,
          'tipoCuenta': encryptedAccountType,
          'numeroCuenta': encryptedAccountNumber,
        },
        'datosBancariosCompletos':
            bankName.isNotEmpty && accountType.isNotEmpty && accountNumber.isNotEmpty,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('usuarios').doc(_user.uid).set(bankDataToSave, SetOptions(merge: true));

      if (mounted) {
        _setInitialValues();
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos bancarios actualizados con exito!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al guardar los datos: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Actualizar Datos Bancarios', style: TextStyle(fontWeight: FontWeight.bold)),
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
                           _buildTextField(
                            controller: _rutController,
                            label: 'RUT / Identificacion',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            autocorrect: false,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9kK]')),
                              RutInputFormatter(),
                            ],
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'Ingresa el RUT';
                              }
                              if (!RutUtils.isValid(trimmed)) {
                                return 'Ingresa un RUT válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildBankDropdown(),
                          const SizedBox(height: 16),
                          _buildAccountTypeDropdown(),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _numeroCuentaController,
                            label: 'Numero de Cuenta',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            readOnly: _selectedAccountType == _rutAccountType,
                            validator: (value) {
                              if (_selectedAccountType == _rutAccountType) {
                                final rutBody = RutUtils.bodyWithoutVerifier(_rutController.text);
                                if (rutBody.isEmpty) {
                                  return 'Ingresa un RUT válido para generar la Cuenta RUT';
                                }
                                return null;
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa el numero de cuenta';
                              }
                              if (value.trim().length < 6) {
                                return 'Ingresa un numero de cuenta valido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _guardarDatosBancarios,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _PRIMARY_COLOR,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'GUARDAR DATOS BANCARIOS',
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
    String? Function(String?)? validator,
     bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool autocorrect = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      decoration: _inputDecoration(label, icon),
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo es obligatorio';
        }
        return null;
      },
    );
  }

  Widget _buildBankDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBankName,
      decoration: _inputDecoration('Nombre del Banco', Icons.account_balance),
      items: _banks
          .map(
            (bank) => DropdownMenuItem(
              value: bank,
              child: Text(bank),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedBankName = value;
          final validTypes = _accountTypeOptionsForBank(value);
          if (_selectedAccountType != null && !validTypes.contains(_selectedAccountType)) {
            _selectedAccountType = null;
          }
        });
        _handleFormChanges();
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Selecciona el banco';
        }
        return null;
      },
    );
  }

  Widget _buildAccountTypeDropdown() {
    final options = _accountTypeOptionsForBank(
      _selectedBankName,
      includeType: _selectedAccountType,
    );

    return DropdownButtonFormField<String>(
      value: _selectedAccountType,
      decoration: _inputDecoration('Tipo de Cuenta', Icons.account_tree_outlined),
      items: options
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(type),
            ),
          )
          .toList(),
      onChanged: _selectedBankName == null
          ? null
          : _onAccountTypeChanged,
      validator: (value) {
        if (_selectedBankName == null || _selectedBankName!.trim().isEmpty) {
          return 'Selecciona el banco';
        }
        if (value == null || value.trim().isEmpty) {
          return 'Selecciona el tipo de cuenta';
        }
        if (value == _rutAccountType && _selectedBankName != 'Banco Estado') {
          return 'La Cuenta RUT solo esta disponible para Banco Estado';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _PRIMARY_COLOR),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _PRIMARY_COLOR, width: 2),
      ),
    );
  }

  void _setInitialValues() {
    _initialBanco = _selectedBankName ?? '';
    _initialTipoCuenta = _selectedAccountType ?? '';
    _initialNumeroCuenta = _numeroCuentaController.text;
    _initialRut = _rutController.text;
  }

  void _onRutChanged() {
    if (_isInitializingControllers) return;
    if (_selectedAccountType == _rutAccountType) {
      _syncAccountNumberWithRut();
    }
    _handleFormChanges();
  }

  void _syncAccountNumberWithRut() {
    if (_selectedAccountType != _rutAccountType) {
      return;
    }
    final rutBody = RutUtils.bodyWithoutVerifier(_rutController.text);
    if (_numeroCuentaController.text != rutBody) {
      _numeroCuentaController.text = rutBody;
    }
  }

  void _onAccountTypeChanged(String? value) {
    setState(() {
      _selectedAccountType = value;
    });
    _syncAccountNumberWithRut();
    _handleFormChanges();
  }

  void _handleFormChanges() {
    if (_isInitializingControllers) return;
    if (!mounted) return;

    final hasChanges = (_selectedBankName ?? '') != _initialBanco ||
        (_selectedAccountType ?? '') != _initialTipoCuenta ||
        _numeroCuentaController.text != _initialNumeroCuenta ||
        _rutController.text != _initialRut;

    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_isSaving) {
      return false;
    }

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