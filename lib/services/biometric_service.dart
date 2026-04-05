import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

  static const _keyEnabled = 'biometric_enabled';
  static const _keyEmail = 'biometric_email';
  static const _keyPassword = 'biometric_password';

  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    try {
      final val = await _storage.read(key: _keyEnabled);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> enable(String email, String password) async {
    await _storage.write(key: _keyEnabled, value: 'true');
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
  }

  static Future<void> disable() async {
    await _storage.deleteAll();
  }

  /// Returns [email, password] if biometric auth succeeds, null otherwise.
  static Future<(String, String)?> authenticate() async {
    try {
      final success = await _auth.authenticate(
        localizedReason: 'Log in to Dun Bun Finance',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!success) return null;
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      if (email == null || password == null) return null;
      return (email, password);
    } on PlatformException {
      return null;
    }
  }
}
