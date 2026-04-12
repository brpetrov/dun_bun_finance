import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeController {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  static final notifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> init() async {
    try {
      final stored = await _storage.read(key: _key);
      notifier.value = stored == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      notifier.value = ThemeMode.dark;
    }
  }

  static Future<void> toggle() async {
    final next =
        notifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifier.value = next;
    try {
      await _storage.write(
          key: _key, value: next == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }

  static bool get isDark => notifier.value == ThemeMode.dark;
}
