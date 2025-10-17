import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:goodjob_app/src/screens/onboard/benefit_slides_screen.dart';
import 'package:goodjob_app/src/screens/onboard/splash_screen.dart';
import 'package:goodjob_app/src/screens/onboard/welcome_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/register_screen.dart';
import 'src/screens/admin/admin_home_screen.dart';
import 'src/screens/admin/crear_trabajo_screen.dart';
import 'src/screens/crear_plantilla_screen.dart';
import 'src/screens/account_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/firebase_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Ubuntu',
        // Aseguramos que los colores del tema sean los correctos
        primaryColor: const Color(0xFF601272),
        colorScheme: const ColorScheme(
          primary: Color(0xFF601272), // Púrpura
          onPrimary: Colors.white,
          secondary: Color(0xFFFFD900), // Amarillo
          onSecondary: Colors.black,
          surface: Color(0xFFF5F5F5),
          onSurface: Color(0xFF1E1E1E),
          error: Color(0xFFFF1507),
          onError: Colors.white,
          brightness: Brightness.light,
        ),

        appBarTheme: const AppBarTheme(
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF601272),
            fontFamily: 'Ubuntu',
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD900),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Ubuntu',
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF601272), width: 2),
            foregroundColor: const Color(0xFF601272),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Ubuntu',
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            textStyle: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              fontFamily: 'Ubuntu',
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color.fromARGB(255, 255, 255, 255),
          labelStyle: const TextStyle(
            color: Color.fromARGB(255, 27, 27, 28),
            fontFamily: 'Ubuntu',
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF757575),
            fontFamily: 'Ubuntu',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5.0),
            borderSide: const BorderSide(color: Color(0xFF757575)),
          ),
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF601272),
          selectedItemColor: Color(0xFFFFD900),
          unselectedItemColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 8.0,
        ),

        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Ubuntu',
          ),
          headlineSmall: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.w600,
            fontFamily: 'Ubuntu',
          ),
          bodyMedium: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w400,
            fontFamily: 'Ubuntu',
          ),
          bodySmall: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w300,
            fontFamily: 'Ubuntu',
          ),
          labelLarge: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
            fontFamily: 'Ubuntu',
          ),
        ),
      ),

      home: const AuthGate(),
      routes: {
        // Rutas de Onboarding
        'splash': (_) => const SplashScreen(), // Pantalla Splash
        'benefit_slides': (_) =>
            const BenefitSlidesScreen(), // Diapositivas de valor (NUEVA)
        'welcome': (_) =>
            const WelcomeScreen(), // Pantalla de decisión Login/Register
        // Rutas de Autenticación
        'login': (_) => const LoginScreen(),
        'register': (_) => const RegisterScreen(),
        // Rutas de la Aplicación
        'home': (_) => const HomeScreen(),
        'admin_home': (_) => const AdminHomeScreen(),
        'crear_trabajo': (_) => const CrearTrabajoScreen(),
        'crear_plantilla': (_) => const CrearPlantillaScreen(),
        'account_verification': (_) => const AccountVerificationScreen(),
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
          // Si no hay usuario, mostramos la Splash Screen
          return const SplashScreen();
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
