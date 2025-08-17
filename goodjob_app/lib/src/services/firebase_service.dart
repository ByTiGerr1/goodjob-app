import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// Manejo de la autenticación y registro de usuarios
class Auth {
  
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  
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

  // Registro de usuario con correo electrónico y contraseña
  Future<void> registerUser(String nombre, String email, String password) async {
    try {
      // Crear usuario en Firebase Authentication
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Obtener el UID del usuario creado
      String uid = userCredential.user?.uid ?? '';

      // Crear documento en la colección "usuarios" en Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': nombre,
        'email': email,
        'rol': 'usuario',
        'creadoEn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }
}