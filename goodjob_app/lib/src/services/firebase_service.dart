import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';

// Manejo de la autenticación y registro de usuarios
class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();

  // Obtener el usuario current
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream para escuchar cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _firebaseAuth.userChanges();

  // Login con correo electrónico y contraseña
  Future<void> login(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Método para cerrar sesión del usuario actual
  Future<void> logout() async {
    await _firebaseAuth.signOut();
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

  Future<void> registerUserWithOptionalData({
    required String email,
    required String password,
    String? name,
    String? lastName,
    String? rut,
    String? birthDate,
    String? gender,
    String? nationality,
    String? activity,
    String? career,
    String? aboutYou,
    String? bankName,
    String? accountType,
    String? bankAccountNumber,
    required bool siiStarted,
  }) async {
    try {
      // 1. Create the user in Firebase Authentication
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Get the user's unique ID from the newly created account
      User? user = userCredential.user;

      if (user != null) {
        // 2. Prepare the user data to save to Firestore
        Map<String, dynamic> userData = {
          'email': email,
          'rol': 'usuario', // Use 'rol' as per your schema
          'creadoEn': FieldValue.serverTimestamp(), // Add timestamp field
        };

        // Add optional fields to the userData map only if they are not null
        if (name != null && name.isNotEmpty) userData['nombre'] = name;
        if (lastName != null && lastName.isNotEmpty)
          userData['apellido'] = lastName;
        if (rut != null && rut.isNotEmpty) userData['rut'] = rut;
        if (birthDate != null && birthDate.isNotEmpty)
          userData['fechaNacimiento'] = birthDate;
        if (gender != null && gender.isNotEmpty) userData['genero'] = gender;
        if (nationality != null && nationality.isNotEmpty)
          userData['nacionalidad'] = nationality;
        if (activity != null && activity.isNotEmpty)
          userData['actividad'] = activity;
        if (career != null && career.isNotEmpty) userData['carrera'] = career;
        if (aboutYou != null && aboutYou.isNotEmpty)
          userData['descripcion'] = aboutYou;
        if (bankName != null && bankName.isNotEmpty)
          userData['banco'] = await _encryptionService.encrypt(bankName);
        if (accountType != null && accountType.isNotEmpty)
          userData['tipoCuenta'] = await _encryptionService.encrypt(accountType);
        if (bankAccountNumber != null && bankAccountNumber.isNotEmpty)
          userData['numeroCuenta'] = await _encryptionService.encrypt(bankAccountNumber);
        userData['siiIniciado'] = siiStarted;

        // 3. Save the user data to a new document in the 'usuarios' collection
        await _firestore.collection('usuarios').doc(user.uid).set(userData);
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      throw Exception(e.message);
    } catch (e) {
      // Handle any other errors
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
