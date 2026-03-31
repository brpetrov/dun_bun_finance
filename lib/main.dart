// ignore_for_file: prefer_const_constructors

import 'package:dun_bun_finance/home_screen/home_screen.dart';
import 'package:dun_bun_finance/login_screen/login_screen.dart';
import 'package:dun_bun_finance/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dun_bun_finance/firebase_options.dart';
import 'package:flutter/foundation.dart'; // For checking platform
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize ffi for desktop platforms
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; // Set the factory for sqflite
  }

  final initialRoute = AuthService.currentUser != null ? '/home' : '/login';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.montserratTextTheme(),
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
