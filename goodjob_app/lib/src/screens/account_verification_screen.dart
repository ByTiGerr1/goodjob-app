import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/encryption_service.dart';
import '../services/firebase_service.dart';

class AccountVerificationScreen extends StatefulWidget {
  const AccountVerificationScreen({super.key});

  @override
  State<AccountVerificationScreen> createState() =>
      _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends State<AccountVerificationScreen> {
  final Auth _auth = Auth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _bankFormKey = GlobalKey<FormState>();

  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();

  User? _user;
  bool _isEmailVerified = false;
  bool _isSendingVerification = false;
  bool _isCheckingVerification = false;
  bool _verificationEmailSent = false;

  bool _loadingBankInfo = true;
  bool _editingBankData = false;
  bool _savingBankData = false;
  bool _hasBankData = false;

  final List<String> _accountTypes = [
    'Cuenta corriente',
    'Cuenta vista',
    'Cuenta de ahorro',
    'Cuenta RUT',
  ];
  String? _selectedAccountType;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _isEmailVerified = _user?.emailVerified ?? false;
    _loadBankData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUser();
    });
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _refreshUser() async {
    if (_user == null) return;
    try {
      await _user!.reload();
      final refreshedUser = _auth.currentUser;
      if (!mounted) return;
      setState(() {
        _user = refreshedUser;
        _isEmailVerified = refreshedUser?.emailVerified ?? false;
        if (_isEmailVerified) {
          _verificationEmailSent = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('No pudimos actualizar el estado de verificación: $e'),
        ),
      );
    }
  }

  Future<void> _sendVerificationEmail() async {
    final user = _user;
    if (user == null) return;
    setState(() {
      _isSendingVerification = true;
      _verificationEmailSent = false;
    });
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _verificationEmailSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Te enviamos un correo de verificación. Revisa tu bandeja de entrada.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos enviar el correo de verificación: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_user == null) return;
    setState(() {
      _isCheckingVerification = true;
    });
    await _refreshUser();
    if (!mounted) return;
    setState(() {
      _isCheckingVerification = false;
    });
    if (_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Tu correo ya está verificado!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aún no se ha verificado el correo. Revisa tu bandeja o intenta nuevamente.',
          ),
        ),
      );
    }
  }

  Future<void> _loadBankData() async {
    final user = _user;
    if (user == null) {
      setState(() {
        _loadingBankInfo = false;
        _hasBankData = false;
      });
      return;
    }

    setState(() {
      _loadingBankInfo = true;
    });

    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        if (!mounted) return;
        setState(() {
          _hasBankData = false;
          _editingBankData = true;
        });
        return;
      }

      final data = doc.data()!;
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
      if ((bankName == null || bankName.trim().isEmpty) &&
          bankData is Map<String, dynamic>) {
        bankName = await decryptField(bankData['banco'] ?? bankData['bankName']);
        accountNumber = await decryptField(
          bankData['numeroCuenta'] ?? bankData['accountNumber'],
        );
        accountType = await decryptField(
          bankData['tipoCuenta'] ?? bankData['accountType'],
        );
      }

      final completed = data['datosBancariosCompletos'] == true ||
          ((bankName != null && bankName.trim().isNotEmpty) &&
              (accountNumber != null && accountNumber.trim().isNotEmpty) &&
              (accountType != null && accountType.trim().isNotEmpty));

      if (!mounted) return;
      setState(() {
        _bankNameController.text = bankName ?? '';
        _accountNumberController.text = accountNumber ?? '';
        if (accountType != null && accountType.isNotEmpty) {
          if (!_accountTypes.contains(accountType)) {
            _accountTypes.add(accountType);
          }
          _selectedAccountType = accountType;
        }
        _hasBankData = completed;
        _editingBankData = !completed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasBankData = false;
        _editingBankData = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos cargar tus datos bancarios: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingBankInfo = false;
        });
      }
    }
  }

  Future<void> _saveBankDetails() async {
    if (!_bankFormKey.currentState!.validate()) {
      return;
    }
    final user = _user;
    if (user == null) return;

    setState(() {
      _savingBankData = true;
    });

    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountType = _selectedAccountType ?? '';

    try {
      final encryption = EncryptionService();
      final encryptedBank = await encryption.encrypt(bankName);
      final encryptedAccountNumber = await encryption.encrypt(accountNumber);
      final encryptedAccountType = await encryption.encrypt(accountType);

      await _firestore.collection('usuarios').doc(user.uid).set({
        'banco': encryptedBank,
        'numeroCuenta': encryptedAccountNumber,
        'tipoCuenta': encryptedAccountType,
        'datosBancarios': {
          'banco': encryptedBank,
          'numeroCuenta': encryptedAccountNumber,
          'tipoCuenta': encryptedAccountType,
        },
        'datosBancariosCompletos': true,
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _hasBankData = true;
        _editingBankData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos bancarios actualizados.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos guardar tus datos bancarios: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingBankData = false;
        });
      }
    }
  }

  String _maskAccountNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 4) return trimmed;
    final lastDigits = trimmed.substring(trimmed.length - 4);
    return '••••$lastDigits';
  }

  Widget _buildEmailVerificationCard(ThemeData theme) {
    final statusColor = _isEmailVerified ? Colors.green : Colors.orange;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _isEmailVerified ? Icons.verified : Icons.email_outlined,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verificación de correo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEmailVerified
                            ? 'Tu correo está verificado. ¡Gracias por mantener tu cuenta segura!'
                            : 'Verifica tu correo electrónico para habilitar todas las funciones y postular a ofertas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (_verificationEmailSent && !_isEmailVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Te enviamos un nuevo correo de verificación. Revisa tu bandeja de entrada o el correo no deseado.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isEmailVerified) ...[
              FilledButton.icon(
                onPressed: _isSendingVerification ? null : _sendVerificationEmail,
                icon: _isSendingVerification
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.mail_outline),
                label: Text(
                  _isSendingVerification ? 'Enviando correo...' : 'Enviar correo de verificación',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isCheckingVerification ? null : _checkVerificationStatus,
                icon: _isCheckingVerification
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _isCheckingVerification
                      ? 'Verificando...'
                      : 'Ya verifiqué mi correo',
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Correo verificado',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSummary(ThemeData theme) {
    final accountType = _selectedAccountType ?? '';
    final accountNumber = _accountNumberController.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Banco: ${_bankNameController.text}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text('Tipo de cuenta: $accountType',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text('Número de cuenta: ${_maskAccountNumber(accountNumber)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Widget _buildBankDetailsCard(ThemeData theme) {
    final statusColor = _hasBankData ? Colors.green : Colors.orange;
    final statusText = _hasBankData
        ? 'Tus datos bancarios están completos. Puedes actualizarlos cuando quieras.'
        : 'Registra los datos de tu cuenta bancaria para recibir tus pagos.';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Datos bancarios',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingBankInfo)
              const Center(child: CircularProgressIndicator())
            else if (_editingBankData)
              Form(
                key: _bankFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del banco',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el nombre del banco';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAccountType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de cuenta',
                      ),
                      items: _accountTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Selecciona el tipo de cuenta';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Número de cuenta',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el número de cuenta';
                        }
                        if (value.trim().length < 6) {
                          return 'Ingresa un número de cuenta válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _savingBankData ? null : _saveBankDetails,
                        icon: _savingBankData
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _savingBankData
                              ? 'Guardando datos...'
                              : 'Guardar datos bancarios',
                        ),
                      ),
                    ),
                    if (_hasBankData)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: _savingBankData
                              ? null
                              : () {
                                  setState(() {
                                    _editingBankData = false;
                                  });
                                },
                          icon: const Icon(Icons.close),
                          label: const Text('Cancelar'),
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              _buildBankSummary(theme),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _editingBankData = true;
                  });
                },
                icon: const Icon(Icons.edit),
                label: const Text('Actualizar datos bancarios'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi registro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valida tu información',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Para postular a las ofertas debes completar estos pasos. ¡Estás muy cerca!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildEmailVerificationCard(theme),
              _buildBankDetailsCard(theme),
            ],
          ),
        ),
      ),
    );
  }
}