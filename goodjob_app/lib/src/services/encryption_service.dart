import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

class EncryptionService {
  // Instancia de Cloud Functions
  final FirebaseFunctions _functions;

  // Callable functions
  late final HttpsCallable _encryptCallable;
  late final HttpsCallable _decryptCallable;

  EncryptionService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance {
    _encryptCallable = _functions.httpsCallable('encryptData');
    _decryptCallable = _functions.httpsCallable('decryptData');
  }

  /// Encripta un texto usando la Cloud Function
  Future<String> encrypt(String? text) async {
    final sanitized = text?.trim();
    if (sanitized == null || sanitized.isEmpty) {
      return '';
    }

    try {
      final result = await _encryptCallable.call({'text': sanitized});
      final data = result.data;
      final encrypted = data['encrypted'];
      if (encrypted is String) {
        return encrypted;
      }
      throw const FormatException('Respuesta inválida al encriptar');
    } on FirebaseFunctionsException catch (e) {
      final lowerMessage = e.message?.toLowerCase();
      if (e.code == 'invalid-argument' ||
          (lowerMessage != null && lowerMessage.contains('no text provided'))) {
        return '';
      }
      throw Exception('Error encrypting data: ${e.message ?? e.code}');
    } on PlatformException catch (e) {
      throw Exception('Error encrypting data: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Error encrypting data: $e');
    }
  }

  /// Desencripta un texto cifrado usando la Cloud Function
  Future<String> decrypt(String? encryptedText) async {
    final sanitized = encryptedText?.trim();
    if (sanitized == null || sanitized.isEmpty) {
      return sanitized ?? '';
    }

    try {
      final result = await _decryptCallable.call({'encrypted': sanitized});
      final data = result.data;
      final decrypted = data['decrypted'];
      if (decrypted is String) {
        return decrypted;
      }
      throw const FormatException('Respuesta inválida al desencriptar');
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error decrypting data: ${e.message ?? e.code}');
    } on PlatformException catch (e) {
      throw Exception('Error decrypting data: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Error decrypting data: $e');
    }
  }
}