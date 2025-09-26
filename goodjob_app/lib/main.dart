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
import 'src/screens/account_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'src/services/firebase_service.dart';

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
        primaryColor: const Color(0xFF601272),
        fontFamily: 'Ubuntu',

        colorScheme: const ColorScheme(
          primary: Color(0xFF601272),
          onPrimary: Colors.white,
          secondary: Color(0xFF00C896),
          onSecondary: Colors.black,
          surface: Color(0xFFF5F5F5),
          onSurface: Color(0xFF1E1E1E),
          error: Color(0xFFFF1507),
          onError: Colors.white,
          brightness: Brightness.light,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F5),
          foregroundColor: Color(0xFF601272),
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
            side: const BorderSide(color: Color(0xFF00C896), width: 2),
            foregroundColor: const Color(0xFF00C896),
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
            foregroundColor: const Color.fromARGB(255, 254, 254, 254),
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

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          labelStyle: const TextStyle(
            color: Color(0xFF1A75D2),
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
            color: Color(0xFF1E1E1E),
          ),
          bodySmall: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w300,
            fontFamily: 'Ubuntu',
            color: Colors.white70,
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
        'welcome': (_) => const WelcomeScreen(),
        'login': (_) => const LoginScreen(),
        'register': (_) => const RegisterScreen(),
        'home': (_) => const HomeScreen(),
        'admin_home': (_) => const AdminHomeScreen(),
        'crear_trabajo': (_) => const CrearTrabajoScreen(),
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
