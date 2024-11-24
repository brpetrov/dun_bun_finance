// ignore_for_file: prefer_const_constructors

import 'package:dun_bun_finance/home_screen/home_screen.dart';
import 'package:dun_bun_finance/login_screen/login_screen.dart';
import 'package:flutter/foundation.dart'; // For checking platform
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ffi for desktop platforms
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; // Set the factory for sqflite
  }

  runApp(const MainApp());

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
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
