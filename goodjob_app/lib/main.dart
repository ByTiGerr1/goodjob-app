import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:goodjob_app/src/screens/onboarding.dart';
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
      theme: ThemeData(
        // Colores
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), 
        primaryColor: const Color(0xFF7B0997), // AppBar color
        colorScheme: const ColorScheme(
          primary: Color(0xFF7B0997),
          onPrimary: Colors.white,
          secondary: Color(0xFFFFD900),
          onSecondary: Colors.black,
          surface: Color(0xFFF5F5F5),
          onSurface: Color(0xFF1E1E1E),
          error: Color(0xFFFF0000),
          onError: Colors.white,
          brightness: Brightness.dark,
        ),
        // Colores appbar
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF7B0997),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        // Colores botones
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD900),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
        // Colores de texto
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Color(0xFF4C0082), fontSize: 14.0, fontFamily: 'Hind'),
          bodySmall: TextStyle(color: Colors.white70),
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        //Colores boton secundario con borde
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFBDBDBD), width: 2), // Color del borde
            foregroundColor: const Color.fromARGB(255, 13, 13, 13), // Color del texto
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
        //Colores boton secundario texto
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFBDBDBD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
        // Colores inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFAFAFA),
          labelStyle: const TextStyle(color: Color(0xFF757575)),
          hintStyle: const TextStyle(color: Color(0xFF757575)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Color(0xFF757575)),
          ),
          
        ),
        // Colores para la BottomNavigationBar
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF7B0997),
          selectedItemColor: Color(0xFFFFD900), // El ícono/texto seleccionado
          unselectedItemColor: Color.fromARGB(255, 255, 255, 255), // El ícono/texto no seleccionado
          type: BottomNavigationBarType.fixed, // Permite tener más de 3 elementos
          elevation: 8.0,
        ),

      ),
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
          return const OnboardingScreen();
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
