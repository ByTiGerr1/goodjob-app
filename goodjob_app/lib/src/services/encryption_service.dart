import 'package:cloud_functions/cloud_functions.dart';

class EncryptionService {
  // Instancia de Cloud Functions
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Callable functions
  late final HttpsCallable _encryptCallable;
  late final HttpsCallable _decryptCallable;

  EncryptionService() {
    _encryptCallable = _functions.httpsCallable('encryptData');
    _decryptCallable = _functions.httpsCallable('decryptData');
  }

  /// Encripta un texto usando la Cloud Function
  Future<String> encrypt(String text) async {
    try {
      final result = await _encryptCallable.call({'text': text});
      return result.data['encrypted'] as String;
    } catch (e) {
      throw Exception('Error encrypting data: $e');
    }
  }

  /// Desencripta un texto cifrado usando la Cloud Function
  Future<String> decrypt(String encryptedText) async {
    try {
      final result = await _decryptCallable.call({'encrypted': encryptedText});
      return result.data['decrypted'] as String;
    } catch (e) {
      throw Exception('Error decrypting data: $e');
    }
  }
}