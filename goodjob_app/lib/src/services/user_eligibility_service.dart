import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserEligibilityStatus {
  const UserEligibilityStatus({
    required this.isEligible,
    required this.isAuthenticated,
    required this.emailVerified,
    required this.hasBankDetails,
    this.errorMessage,
    this.userId,
  });

  final bool isEligible;
  final bool isAuthenticated;
  final bool emailVerified;
  final bool hasBankDetails;
  final String? errorMessage;
  final String? userId;

  bool get hasError => errorMessage != null;
}

class UserEligibilityService {
  UserEligibilityService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<UserEligibilityStatus> fetchStatus() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return const UserEligibilityStatus(
        isEligible: false,
        isAuthenticated: false,
        emailVerified: false,
        hasBankDetails: false,
        errorMessage: 'Debes iniciar sesión para continuar.',
      );
    }

    try {
      await user.reload();
      user = _auth.currentUser;
    } catch (_) {
      return const UserEligibilityStatus(
        isEligible: false,
        isAuthenticated: true,
        emailVerified: false,
        hasBankDetails: false,
        errorMessage:
            'No pudimos actualizar el estado de tu cuenta. Intenta nuevamente.',
      );
    }

    if (user == null) {
      return const UserEligibilityStatus(
        isEligible: false,
        isAuthenticated: false,
        emailVerified: false,
        hasBankDetails: false,
        errorMessage: 'Tu sesión ha expirado. Inicia sesión nuevamente.',
      );
    }

    final bool emailVerified = user.emailVerified;
    bool hasBankDetails = false;
    String? errorMessage;

    try {
      final snapshot = await _firestore.collection('usuarios').doc(user.uid).get();
      final data = snapshot.data();
      hasBankDetails = _hasBankInformation(data);
    } catch (_) {
      errorMessage =
          'No pudimos comprobar tus datos bancarios. Intenta nuevamente.';
    }

    final isEligible = emailVerified && hasBankDetails && errorMessage == null;

    return UserEligibilityStatus(
      isEligible: isEligible,
      isAuthenticated: true,
      emailVerified: emailVerified,
      hasBankDetails: hasBankDetails,
      errorMessage: isEligible ? null : errorMessage,
      userId: user.uid,
    );
  }

  bool _hasBankInformation(Map<String, dynamic>? data) {
    if (data == null) return false;

    final hasDirectFields =
        _valueHasContent(data['banco']) &&
            _valueHasContent(data['numeroCuenta']) &&
            _valueHasContent(data['tipoCuenta']);

    if (hasDirectFields) return true;

    final dynamic bankData = data['datosBancarios'];
    if (bankData is Map<String, dynamic>) {
      final bankName = bankData['banco'] ?? bankData['bankName'];
      final accountNumber =
          bankData['numeroCuenta'] ?? bankData['accountNumber'];
      final accountType = bankData['tipoCuenta'] ?? bankData['accountType'];
      if (_valueHasContent(bankName) &&
          _valueHasContent(accountNumber) &&
          _valueHasContent(accountType)) {
        return true;
      }
    }

    if (data['datosBancariosCompletos'] == true) {
      return true;
    }

    return false;
  }

  bool _valueHasContent(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    return true;
  }
}

extension UserEligibilityStatusMessage on UserEligibilityStatus {
  String messageForAction(String actionDescription) {
    if (!isAuthenticated) {
      return 'Debes iniciar sesión para $actionDescription.';
    }

    if (errorMessage != null) {
      return errorMessage!;
    }

    if (!emailVerified && !hasBankDetails) {
      return 'Debes verificar tu correo y registrar tus datos bancarios '
          'para $actionDescription.';
    }

    if (!emailVerified) {
      return 'Debes verificar tu correo electrónico para $actionDescription.';
    }

    if (!hasBankDetails) {
      return 'Debes completar tus datos bancarios para $actionDescription.';
    }

    return 'No pudimos validar tu cuenta. Intenta nuevamente.';
  }
}