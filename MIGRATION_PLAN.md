# Dun Bun Finance — Migration Plan

## Overview
Migrate from Windows-only SQLite app with hardcoded login to a cross-platform (Windows + Android + iOS) app using Firebase Auth + Firestore, with synced per-user data.

---

## Phase 1: Cleanup & Prep
> Get the project into a clean state before adding anything new.

### Step 1.1 — Initialize Git
```bash
cd dun_bun_finance
git init
git add .
git commit -m "Initial commit: pre-migration snapshot"
```
This gives you a safe rollback point.

### Step 1.2 — Fix pubspec.yaml dependency placement
Several packages are incorrectly under `dev_dependencies` (they'll break in release builds). Move them to `dependencies`:
- `sqflite` (will be removed later, but fix now so nothing breaks mid-migration)
- `path_provider`
- `bitsdojo_window`

Remove `provider` entirely (unused). Remove `flutter_lints` and replace with `flutter_lints` or keep as-is under dev_dependencies (it's correct there).

**Result pubspec.yaml dependencies section should look like:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  sqflite_common_ffi: ^2.3.6
  sqflite: ^2.2.0+3
  path_provider: ^2.0.13
  bitsdojo_window: ^0.1.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

Then run: `flutter pub get`

### Step 1.3 — Delete duplicate Pot model
Delete `lib/pot.dart` (the duplicate). The canonical one is `lib/models/pot.dart`.
Check that nothing imports the deleted file:
- `db_helper.dart` imports `lib/models/pot.dart` — correct, no change needed.
- No other file imports `lib/pot.dart`.

### Step 1.4 — Add Google Fonts (Montserrat)
Add to `pubspec.yaml` dependencies:
```yaml
  google_fonts: ^6.1.0
```

Run `flutter pub get`.

Then in `lib/main.dart`, update `MainApp` to apply Montserrat globally:
```dart
import 'package:google_fonts/google_fonts.dart';

// Inside MaterialApp:
theme: ThemeData(
  textTheme: GoogleFonts.montserratTextTheme(),
),
```

This applies Montserrat to every Text widget in the app without changing any other file.

### Step 1.5 — Commit cleanup
```bash
git add .
git commit -m "Cleanup: fix deps, remove duplicate pot model, add Montserrat font"
```

---

## Phase 2: Firebase Project Setup
> Create the Firebase project and connect it to your Flutter app.

### Step 2.1 — Create Firebase project
1. Go to https://console.firebase.google.com
2. Click "Create a project"
3. Name it `dun-bun-finance` (or similar)
4. Disable Google Analytics (not needed, keeps it simpler)
5. Wait for project creation

### Step 2.2 — Enable Firebase Auth
1. In Firebase Console, go to **Build > Authentication**
2. Click "Get started"
3. Enable **Email/Password** sign-in provider
4. (Optional for later) Enable **Google** sign-in if you want that too

### Step 2.3 — Create Firestore database
1. In Firebase Console, go to **Build > Firestore Database**
2. Click "Create database"
3. Choose **Start in test mode** (we'll add security rules later)
4. Select a region close to you (e.g., `europe-west2` for UK)

### Step 2.4 — Install FlutterFire CLI and configure
```bash
dart pub global activate flutterfire_cli
```

Then from the `dun_bun_finance/` directory:
```bash
flutterfire configure --project=dun-bun-finance
```

This will:
- Ask which platforms to configure (select **Android, iOS, Windows**)
- Auto-register apps in Firebase Console
- Generate `lib/firebase_options.dart`
- For Android: download `google-services.json` and modify `android/` build files
- For iOS: download `GoogleService-Info.plist` and modify `ios/` config

**If it asks for Android package name**, use: `com.example.dun_bun_finance` (check `android/app/build.gradle` for the actual `applicationId`).

### Step 2.5 — Add Firebase dependencies to pubspec.yaml
```yaml
dependencies:
  # ... existing deps ...
  firebase_core: ^3.8.1
  firebase_auth: ^5.4.1
  cloud_firestore: ^5.6.1
```

Run `flutter pub get`.

### Step 2.6 — Initialize Firebase in main.dart
Update `lib/main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Keep existing desktop SQLite init (will remove in Phase 4)
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MainApp());
  // ... existing bitsdojo_window code ...
}
```

### Step 2.7 — Commit Firebase setup
```bash
git add .
git commit -m "Add Firebase project configuration"
```

### Step 2.8 — Verify it still runs
```bash
flutter run -d windows
```
The app should work exactly as before. Firebase is initialized but not used yet.

---

## Phase 3: Firebase Auth (Replace Hardcoded Login)
> Replace the hardcoded username/password with real Firebase email/password auth.

### Step 3.1 — Create an AuthService
Create `lib/services/auth_service.dart`:
```dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Sign up with email/password
  static Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with email/password
  static Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Listen to auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
```

### Step 3.2 — Rewrite LoginScreen
Update `lib/login_screen/login_screen.dart` to:
- Change username field to **email** field
- Add a **Sign Up** button alongside Login
- Call `AuthService.signIn()` / `AuthService.signUp()`
- On success, navigate to `/home`
- On error, show the Firebase error message in a snackbar
- Add a toggle between "Login" and "Sign Up" modes (a simple TextButton that switches a bool)

**Key changes:**
```dart
import 'package:dun_bun_finance/services/auth_service.dart';

// In _authenticate():
try {
  if (_isSignUp) {
    await AuthService.signUp(_emailController.text.trim(), _passwordController.text);
  } else {
    await AuthService.signIn(_emailController.text.trim(), _passwordController.text);
  }
  Navigator.of(context).pushReplacementNamed("/home");
} on FirebaseAuthException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message ?? 'Authentication failed'), backgroundColor: Colors.red),
  );
}
```

**Note:** Use `pushReplacementNamed` instead of `pushNamed` so the user can't press back to return to login.

### Step 3.3 — Pass display name to HomeScreen
**Option A (simplest): Use route arguments.**

In LoginScreen, after successful auth:
```dart
// After successful sign-in/sign-up:
final user = AuthService.currentUser;
Navigator.of(context).pushReplacementNamed(
  "/home",
  arguments: user?.displayName ?? user?.email?.split('@')[0] ?? 'User',
);
```

In `main.dart`, update the `/home` route to accept arguments:
```dart
routes: {
  '/login': (context) => const LoginScreen(),
},
onGenerateRoute: (settings) {
  if (settings.name == '/home') {
    final username = settings.arguments as String? ?? 'User';
    return MaterialPageRoute(
      builder: (context) => HomeScreen(username: username),
    );
  }
  return null;
},
```

In HomeScreen, add the `username` parameter:
```dart
class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});
  // ...
}
```

In the AppBar:
```dart
appBar: AppBar(
  title: Text("Hello, ${widget.username}"),
  // ... rest stays the same
),
```

### Step 3.4 — Add Sign Out button to HomeScreen
Add to the AppBar actions (next to the refresh button):
```dart
IconButton(
  icon: const Icon(Icons.logout),
  onPressed: () async {
    await AuthService.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  },
),
```

### Step 3.5 — Auto-login if already signed in
In `main.dart`, change the initial route logic:
```dart
// After Firebase.initializeApp():
final initialRoute = AuthService.currentUser != null ? '/home' : '/login';

// In MaterialApp:
initialRoute: initialRoute,
```

For auto-login, you'll need to handle the `/home` route with a default username from the current user:
```dart
// In onGenerateRoute, when arguments is null (auto-login case):
final username = settings.arguments as String?
    ?? AuthService.currentUser?.displayName
    ?? AuthService.currentUser?.email?.split('@')[0]
    ?? 'User';
```

### Step 3.6 — Set display name on sign-up
After creating a new account, set the display name so it persists:
```dart
// In LoginScreen, after successful signUp:
await AuthService.currentUser?.updateDisplayName(
  _emailController.text.split('@')[0],
);
```

### Step 3.7 — Commit auth changes
```bash
git add .
git commit -m "Replace hardcoded login with Firebase Auth"
```

### Step 3.8 — Test auth flow
1. Run the app
2. Sign up with a new email/password
3. Verify you land on HomeScreen with "Hello, {name}"
4. Close and reopen — should auto-login
5. Sign out — should return to login
6. Sign in with existing credentials
7. Try wrong password — should show error

---

## Phase 4: Replace SQLite with Firestore
> Move all data from local SQLite to cloud Firestore, scoped per user.

### Firestore Data Structure
```
users/
  {uid}/
    expenses/
      {expenseId}/
        name: "Rent"
        cost: 1200.0
        isLoan: false
        loanStartDate: null
        loanEndDate: null
        createdAt: Timestamp
    pots/
      {potId}/
        name: "Savings"
        percentage: 20
        createdAt: Timestamp
```

Each user's data lives under their `uid`, so it's completely isolated and synced across devices.

### Step 4.1 — Create FirestoreService
Create `lib/services/firestore_service.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dun_bun_finance/services/auth_service.dart';
import 'package:dun_bun_finance/models/expense.dart';
import 'package:dun_bun_finance/models/pot.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;

  // Get the current user's document reference
  static DocumentReference get _userDoc =>
      _firestore.collection('users').doc(AuthService.currentUser!.uid);

  // --- EXPENSES ---

  static CollectionReference get _expensesCol =>
      _userDoc.collection('expenses');

  static Future<void> createExpense(String name, double cost, bool isLoan,
      String? loanStartDate, String? loanEndDate) async {
    await _expensesCol.add({
      'name': name,
      'cost': cost,
      'isLoan': isLoan,
      'loanStartDate': loanStartDate,
      'loanEndDate': loanEndDate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final snapshot = await _expensesCol.orderBy('createdAt').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Use Firestore doc ID as the ID
      // Convert bool to int for compatibility with existing UI code
      data['isLoan'] = (data['isLoan'] == true) ? 1 : 0;
      return data;
    }).toList();
  }

  static Future<void> updateExpense(String docId, Map<String, dynamic> data) async {
    await _expensesCol.doc(docId).update(data);
  }

  static Future<void> deleteExpense(String docId) async {
    await _expensesCol.doc(docId).delete();
  }

  // --- POTS ---

  static CollectionReference get _potsCol => _userDoc.collection('pots');

  static Future<void> createPot(String name, int percentage) async {
    await _potsCol.add({
      'name': name,
      'percentage': percentage,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPots() async {
    final snapshot = await _potsCol.orderBy('createdAt').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  static Future<void> updatePot(String docId, Map<String, dynamic> data) async {
    await _potsCol.doc(docId).update(data);
  }

  static Future<void> deletePot(String docId) async {
    await _potsCol.doc(docId).delete();
  }
}
```

### Step 4.2 — Update models for Firestore
The current models use `int id`. Firestore uses `String` document IDs. Update both models:

**`lib/models/expense.dart`** — change `int id` to `String id` (default `''`).
**`lib/models/pot.dart`** — change `int id` to `String id` (default `''`).

Update `fromJson`/`toJson` accordingly. Remove SQLite-specific conversions (like `isLoan: 1/0` — Firestore stores real booleans).

### Step 4.3 — Replace SQLHelper calls with FirestoreService
Go through each file that calls `SQLHelper` and replace:

**`lib/home_screen/home_screen.dart`:**
```dart
// OLD:
pots = await SQLHelper.getPots();
var allExpenses = await SQLHelper.getExpenses();

// NEW:
pots = await FirestoreService.getPots();
var allExpenses = await FirestoreService.getExpenses();
```

**`lib/home_screen/sections/expense_section.dart`:**
```dart
// OLD:
await SQLHelper.createExpense(name, cost, isLoan, startDate, endDate);
await SQLHelper.updateExpense(expense);
await SQLHelper.deleteExpense(id);

// NEW:
await FirestoreService.createExpense(name, cost, isLoan, startDate, endDate);
await FirestoreService.updateExpense(docId, data);
await FirestoreService.deleteExpense(docId);
```

**Important:** Since Firestore IDs are Strings, update the `showExpensePopup` and `showPotPopup` methods to accept `String? id` instead of `int? id`. Same for delete methods.

**`lib/home_screen/sections/pot_section.dart`:**
Same pattern — replace `SQLHelper` calls with `FirestoreService` calls, change `int? id` to `String? id`.

### Step 4.4 — Remove SQLite dependencies
From `pubspec.yaml`, remove:
```yaml
  sqflite_common_ffi: ^2.3.6
  sqflite: ^2.2.0+3
  path_provider: ^2.0.13   # Keep if used elsewhere, but currently only used by db_helper
```

Delete `lib/db_helper.dart` entirely.

Remove SQLite initialization from `main.dart`:
```dart
// DELETE these lines:
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// ...
sqfliteFfiInit();
databaseFactory = databaseFactoryFfi;
```

Run `flutter pub get`.

### Step 4.5 — Commit Firestore migration
```bash
git add .
git commit -m "Replace SQLite with Firestore for cross-device sync"
```

### Step 4.6 — Test data operations
1. Run the app, sign in
2. Add an expense — verify it appears
3. Edit the expense — verify changes persist
4. Add a loan expense with dates — verify dates show correctly
5. Delete an expense — verify it's gone
6. Do the same for pots
7. Close app, reopen — all data should still be there
8. (Optional) Check Firebase Console > Firestore to see the data

---

## Phase 5: Firestore Security Rules
> Lock down the database so users can only read/write their own data.

### Step 5.1 — Set security rules
In Firebase Console > Firestore > Rules, replace with:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Click **Publish**.

This ensures:
- You must be signed in
- You can only access data under your own `uid`
- No one else can read or modify your data

---

## Phase 6: Platform-Guard Desktop Code
> Make the app run on Android/iOS without crashing on desktop-only code.

### Step 6.1 — Guard bitsdojo_window
In `main.dart`, the `bitsdojo_window` code is already guarded with a platform check:
```dart
if (defaultTargetPlatform == TargetPlatform.windows) { ... }
```
This is fine — it won't run on mobile.

However, the **import** itself can cause issues on mobile. Wrap it:
```dart
import 'dart:io' show Platform;

// Only import and use bitsdojo_window on desktop
// Option: use conditional imports or just keep the platform check
```

Actually, since `bitsdojo_window` is a Flutter plugin, the import alone won't crash mobile — Flutter handles this. The platform check around `doWhenWindowReady` is sufficient. **No changes needed here** unless you get build errors on Android/iOS.

### Step 6.2 — Test on Android
```bash
flutter run -d <android-device-or-emulator>
```

If you don't have an emulator set up:
1. Open Android Studio
2. Go to Device Manager
3. Create a virtual device (e.g., Pixel 7, API 34)
4. Start the emulator
5. Run `flutter run`

### Step 6.3 — Test on iOS (requires macOS)
```bash
flutter run -d <ios-simulator>
```

If you're on Windows, you can't build for iOS locally. Options:
- Use a Mac
- Use a CI service like Codemagic (has free tier)
- Skip iOS for now and test on Android + Windows

### Step 6.4 — Fix any mobile UI issues
The current UI uses `SizedBox(width: 500)` in dialogs which may be too wide for phones. Consider using `MediaQuery.of(context).size.width * 0.8` or removing fixed widths.

Check:
- [ ] `expense_section.dart` line 184: `SizedBox(width: 500)` — change to `constraints: BoxConstraints(maxWidth: 500)`
- [ ] `pot_section.dart` line 53: `SizedBox(width: 500)` — same fix
- [ ] `login_screen.dart` line 40: `padding: EdgeInsets.symmetric(horizontal: 50.0)` — may be too much on small screens, use `MediaQuery` or a max of 400px

### Step 6.5 — Commit platform fixes
```bash
git add .
git commit -m "Fix UI for mobile screens, platform-guard desktop code"
```

---

## Phase 7: Final Polish

### Step 7.1 — Add a loading/splash screen
While Firebase initializes and checks auth state, show a brief loading screen instead of a flash of the login screen.

### Step 7.2 — Persist monthly income to Firestore
Currently, monthly income is only in a `TextEditingController` and resets when you restart the app. Add a `monthlyIncome` field to the user's Firestore document:
```
users/{uid}/
  monthlyIncome: 3500.0    <-- new field on the user doc itself
  expenses/...
  pots/...
```

Load it on startup, save it when the user submits.

### Step 7.3 — Add `flutter analyze` check
```bash
flutter analyze
```
Fix any warnings or errors.

### Step 7.4 — Final commit
```bash
git add .
git commit -m "Final polish: splash screen, persist income, fix analysis warnings"
```

---

## Quick Reference: Files Changed Per Phase

| Phase | Files Created | Files Modified | Files Deleted |
|-------|--------------|----------------|---------------|
| 1. Cleanup | — | `pubspec.yaml`, `main.dart` | `lib/pot.dart` |
| 2. Firebase Setup | `lib/firebase_options.dart` (auto-generated) | `pubspec.yaml`, `main.dart`, android/ios configs | — |
| 3. Auth | `lib/services/auth_service.dart` | `login_screen.dart`, `home_screen.dart`, `main.dart` | — |
| 4. Firestore | `lib/services/firestore_service.dart` | `expense.dart`, `pot.dart`, `home_screen.dart`, `expense_section.dart`, `pot_section.dart`, `pubspec.yaml` | `lib/db_helper.dart` |
| 5. Security Rules | — | Firebase Console only | — |
| 6. Platform | — | `expense_section.dart`, `pot_section.dart`, `login_screen.dart` | — |
| 7. Polish | — | `main.dart`, `home_screen.dart`, `monthly_income_section.dart` | — |

---

## Firebase Free Tier Limits (for reference)

| Service | Free Limit | Your Expected Usage |
|---------|-----------|-------------------|
| Auth | Unlimited email/password users | 1-5 users |
| Firestore Storage | 1 GiB | < 1 MB |
| Firestore Reads | 50,000/day | < 100/day |
| Firestore Writes | 20,000/day | < 50/day |
| Firestore Deletes | 20,000/day | < 20/day |

You will not pay a penny.
