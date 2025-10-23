import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:goodjob_app/src/screens/onboard/benefit_slides_screen.dart';
import 'package:goodjob_app/src/screens/onboard/splash_screen.dart';
import 'package:goodjob_app/src/screens/onboard/welcome_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/auth/register_screen.dart';
import 'src/screens/admin/admin_home_screen.dart';
import 'src/screens/admin/crear_trabajo_screen.dart';
import 'src/screens/admin/crear_plantilla_screen.dart';
import 'src/screens/auth/account_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/firebase_service.dart';
import 'firebase_options.dart';
// import 'theme/app_colors.dart'; // No es necesario si se definen en ThemeData

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Colores base para mejor legibilidad
    const Color primaryPurple = Color(0xFF601272);
    const Color accentYellow = Color(0xFFFFD900);
    const Color backgroundGray = Color(0xFFF5F5F5);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Ubuntu',
        
        // 1. ColorScheme: Define la paleta central (fuente de verdad)
        colorScheme: const ColorScheme(
          primary: primaryPurple,
          onPrimary: Colors.white,
          secondary: accentYellow,
          onSecondary: Colors.black,
          surface: backgroundGray,
          onSurface: Color(0xFF1E1E1E), // Texto principal sobre fondo
          error: Color(0xFFFF1507),
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        
        // 2. Base Scaffold Color
        scaffoldBackgroundColor: backgroundGray,
        
        // 3. AppBar Theme
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white, // Color de íconos y texto
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Ubuntu',
          ),
        ),
        
        // 4. Button Themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentYellow,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            textStyle: const TextStyle(
              fontSize: 16, // Aumento de tamaño para CTA
              fontWeight: FontWeight.bold,
              fontFamily: 'Ubuntu',
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryPurple, width: 2),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryPurple, 
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),

        // 5. Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white, // Color de fondo del input más limpio
          labelStyle: const TextStyle(color: Color.fromARGB(255, 27, 27, 28), fontFamily: 'Ubuntu'),
          hintStyle: const TextStyle(color: Color(0xFF757575), fontFamily: 'Ubuntu'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Color(0xFF757575)),
          ),
        ),

        // 6. Bottom Navigation Bar Theme
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: primaryPurple,
          selectedItemColor: accentYellow,
          unselectedItemColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 8.0,
        ),

        // 7. Text Theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, fontFamily: 'Ubuntu'),
          headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600, fontFamily: 'Ubuntu'),
          bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w400, fontFamily: 'Ubuntu'),
          bodySmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w300, fontFamily: 'Ubuntu'),
          labelLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500, fontFamily: 'Ubuntu'),
        ),
      ),

      // Flujo de navegación principal
      home: const AuthGate(),
      routes: {
        // Rutas de Onboarding
        'splash': (_) => const SplashScreen(),
        'benefit_slides': (_) => const BenefitSlidesScreen(),
        'welcome': (_) => const WelcomeScreen(),
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
          // Usamos la SplashScreen mientras esperamos el estado de auth
          return const SplashScreen(); 
        }
        final user = snapshot.data;
        if (user == null) {
          // Si no hay usuario, mostramos el Onboarding principal
          return const BenefitSlidesScreen(); 
        }
        // Si hay usuario, verificamos su rol
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