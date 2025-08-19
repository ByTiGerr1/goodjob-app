import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/register_screen.dart';
import 'src/screens/welcome_screen.dart';
import 'src/screens/admin_home_screen.dart';
import 'src/screens/crear_trabajo_screen.dart';
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
      initialRoute: 'welcome',
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