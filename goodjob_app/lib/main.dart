import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/register_screen.dart';
import 'src/screens/welcome_screen.dart';
import 'src/screens/admin_home_screen.dart';
import 'src/screens/crear_trabajo_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/firebase_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        'welcome': (_) => const WelcomeScreen(),
        'login': (_) => const LoginScreen(),
        'register': (_) => const RegisterScreen(),
        'home': (_) => const HomeScreen(),
        'admin_home': (_) => const AdminHomeScreen(),
        'crear_trabajo': (_) => const CrearTrabajoScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const WelcomeScreen();
        }
        return FutureBuilder<String?>(
          future: Auth().getUserRole(user.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final role = roleSnap.data;
            if (role == 'admin') {
              return const AdminHomeScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}