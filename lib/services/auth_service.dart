import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Re-authenticates then permanently deletes the Firebase Auth account.
  static Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('No signed-in user');
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    await user.delete();
  }

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
