import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'encryption_service.dart';
import 'notification_service.dart';

// Manejo de la autenticación y registro de usuarios
class RequiresRecentLoginException implements Exception {
  const RequiresRecentLoginException([
    this.message =
        'Por seguridad, vuelve a iniciar sesión e inténtalo nuevamente.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();
  NotificationService? _notificationService;


  // Obtener el usuario current
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream para escuchar cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _firebaseAuth.userChanges();

  // Login con correo electrónico y contraseña
  Future<void> login(String email, String password) async {
    try{
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        _notificationService = NotificationService(uid: user.uid);
        await _initializeNotificationService();
      }
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'El correo electrónico no es válido.';
          break;
        case 'user-not-found':
          message = 'No existe un usuario registrado con ese correo.';
          break;
        default:
          message = e.message ?? e.code;
      }
      throw Exception('No se pudo enviar el correo de restablecimiento: $message');
    } catch (e) {
      throw Exception('No se pudo enviar el correo de restablecimiento: $e');
    }
  }

  Future<void> _initializeNotificationService() async {
    final service = _notificationService;
    if (service == null) return;
    try {
      await service.init();
    } catch (e, stackTrace) {
      debugPrint('No se pudieron inicializar las notificaciones: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }


  // Método para cerrar sesión del usuario actual
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    try {
      final userDocRef = _firestore.collection('usuarios').doc(user.uid);

      final batch = _firestore.batch();
      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        batch.delete(userDocRef);

        final tokensSnapshot = await userDocRef.collection('fcm_tokens').get();
        for (final doc in tokensSnapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();

      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const RequiresRecentLoginException();
      }
      throw Exception('No se pudo eliminar la cuenta: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('No se pudo eliminar la cuenta: $e');
    }
  }

  Future<void> reauthenticateWithPassword(String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception(
        'No se pudo reautenticar porque tu cuenta no tiene un correo asociado.',
      );
    }

    final credential =
        EmailAuthProvider.credential(email: email, password: password);

    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
          message = 'La contraseña ingresada no es correcta.';
          break;
        case 'too-many-requests':
          message =
              'Demasiados intentos fallidos. Intenta nuevamente más tarde.';
          break;
        default:
          message = e.message ?? e.code;
      }
      throw Exception('No se pudo reautenticar: $message');
    } catch (e) {
      throw Exception('No se pudo reautenticar: $e');
    }
  }
  
  // Obtener el rol del usuario actual a partir de Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      return doc['rol'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Registro de usuario con correo electrónico y contraseña
  Future<void> registerUser(
    String nombre,
    String email,
    String password,
    String banco,
    String numeroCuenta,
    String tipoCuenta,
  ) async {
    try {
      // Crear usuario en Firebase Authentication
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Obtener el UID del usuario creado
      String uid = userCredential.user?.uid ?? '';

      // Enviar correo de verificación
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
      }

      // Encriptar datos bancarios
      final encryptedBankName = await _encryptionService.encrypt(banco);
      final encryptedAccountNumber = await _encryptionService.encrypt(numeroCuenta);
      final encryptedAccountType = await _encryptionService.encrypt(tipoCuenta);

      // Crear documento en la colección "usuarios" en Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': nombre,
        'email': email,
        'rol': 'usuario',
        'banco': encryptedBankName,
        'numeroCuenta': encryptedAccountNumber,
        'tipoCuenta': encryptedAccountType,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }

  Future<void> registerUserWithDetails({
    required String email,
    required String password,
    required String name,
    required String lastName,
    required String rut,
    required DateTime birthDate,
    required String phoneNumber,
    required String gender,
    required String nationality,
    required bool hasDisability,
    required String region,
    required String street,
    required String streetNumber,
  }) async {
    try {
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
        final userData = {
          'email': email,
          'nombre': name,
          'apellido': lastName,
          'rut': rut,
          'fechaNacimiento': Timestamp.fromDate(birthDate),
          'telefono': phoneNumber,
          'genero': gender,
          'nacionalidad': nationality,
          'discapacidad': hasDisability,
          'region': region,
          'calle': street,
          'numero': streetNumber,
          'rol': 'usuario',
          'creadoEn': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('usuarios').doc(user.uid).set(userData);
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('An error occurred during registration: $e');
    }
  }


  // Método para actualizar el token del admin antes de realizar consultas.
  Future<void> actualizarAdminToken() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.getIdToken(true); // Forzar la actualización del token
    }
  }
}
