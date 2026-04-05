// ignore_for_file: prefer_const_constructors

import 'package:dun_bun_finance/home_screen/home_screen.dart';
import 'package:dun_bun_finance/login_screen/login_screen.dart';
import 'package:dun_bun_finance/services/auth_service.dart';
import 'package:dun_bun_finance/services/biometric_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dun_bun_finance/firebase_options.dart';
import 'package:flutter/foundation.dart'; // For checking platform
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  String initialRoute = '/login';

  if (AuthService.currentUser != null) {
    initialRoute = '/home';
  } else {
    // Try biometric login if enabled
    final biometricEnabled = await BiometricService.isEnabled();
    if (biometricEnabled) {
      final credentials = await BiometricService.authenticate();
      if (credentials != null) {
        try {
          await AuthService.signIn(credentials.$1, credentials.$2);
          final user = AuthService.currentUser;
          if (user != null && user.emailVerified) {
            initialRoute = '/home';
          }
        } catch (_) {
          // Biometric login failed, fall through to login screen
        }
      }
    }
  }

  runApp(MainApp(initialRoute: initialRoute));

  if (defaultTargetPlatform == TargetPlatform.windows) {
    doWhenWindowReady(() {
      final initialSize = Size(900, 900); // Initial window size
      appWindow.size = initialSize;
      appWindow.minSize = const Size(800, 600); // Minimum window size
      appWindow.alignment = Alignment.center;
      appWindow.title = "Dun Bun Finance"; // Set window title
      appWindow.show();
    });
  }
}

class MainApp extends StatelessWidget {
  final String initialRoute;
  const MainApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00BCD4), // cyan accent
      brightness: Brightness.dark,
      surface: const Color(0xFF121218),
      onSurface: const Color(0xFFE2E2E9),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: const Color(0xFF121218),
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1A1A24),
          foregroundColor: darkScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withValues(alpha: 0.06),
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkScheme.primary, width: 1.5),
          ),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkScheme.primary,
            foregroundColor: darkScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkScheme.primary,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E1E2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return darkScheme.primary;
            }
            return Colors.transparent;
          }),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2A2A36),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: darkScheme.primary,
          foregroundColor: darkScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white70,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final username = settings.arguments as String? ??
              AuthService.currentUser?.displayName ??
              AuthService.currentUser?.email?.split('@')[0] ??
              'User';
          return MaterialPageRoute(
            builder: (context) => HomeScreen(username: username),
          );
        }
        return null;
      },
    );
  }
}
