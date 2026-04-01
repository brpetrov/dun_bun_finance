# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dun Bun Finance is a cross-platform personal finance Flutter app (Windows primary, Android and iOS supported) for tracking monthly expenses, loans, and income allocation via percentage-based "pots." Uses Firebase Auth for authentication and Cloud Firestore for per-user data storage.

## Build & Run Commands

All commands run from the `dun_bun_finance/` subdirectory:

```bash
cd dun_bun_finance
flutter pub get          # Install dependencies
flutter run -d windows   # Run on Windows
flutter run -d android   # Run on Android
flutter analyze          # Static analysis (uses flutter_lints)
flutter test             # Run all tests (no tests exist yet)
```

## Architecture

**Entry point:** `lib/main.dart` — initialises Firebase, attempts biometric auto-login if enabled, configures bitsdojo_window (900x900, min 800x600) on Windows only, sets up named routes (`/login` → `/home`).

**Screens & routing:**
- `/login` → `LoginScreen` — Firebase Auth email/password login and registration with email verification flow
- `/home` → `HomeScreen` — main dashboard, stateful, owns all data loading and calculation logic; routed via `onGenerateRoute` so it can receive a `username` argument

**Auth flow:**
- Register: creates account → sends verification email → signs out → redirects to login. Unverified logins are blocked with an orange snackbar and a "Resend" action.
- Login: signs in → checks `emailVerified` → if first time with biometrics available, offers biometric enrollment → navigates to home.
- Auto-login on startup: if `AuthService.currentUser != null` routes directly to `/home`; otherwise if biometric is enabled, prompts biometric → signs in with stored credentials.

**Data flow:** HomeScreen is the single source of truth. It loads expenses/pots from Firestore, calculates totals, and passes data + callbacks down to four section widgets:
- `MonthlyIncomeInput` — text field for income entry
- `ExpensesSection` — CRUD for expenses (supports loan flag with start/end dates)
- `TotalSection` — displays computed totals
- `PotsSection` — CRUD for pots; each pot gets a percentage of income-after-expenses

**Services (`lib/services/`):**
- `auth_service.dart` (`AuthService`) — thin wrapper around `FirebaseAuth`. Static methods: `signUp`, `signIn`, `signOut`, `currentUser`, `authStateChanges`.
- `firestore_service.dart` (`FirestoreService`) — all Firestore CRUD scoped to `users/{uid}/expenses` and `users/{uid}/pots`. Methods: `createExpense`, `getExpenses`, `updateExpense`, `deleteExpense`, `createPot`, `getPots`, `updatePot`, `deletePot`, `clearAll`.
- `biometric_service.dart` (`BiometricService`) — wraps `local_auth` + `flutter_secure_storage`. Stores encrypted email/password on-device. Methods: `isAvailable`, `isEnabled`, `enable`, `disable`, `authenticate` (returns `(email, password)` record on success).

**Firestore data structure:**
```
users/
  {uid}/
    expenses/
      {docId}: { name, cost, isLoan, loanStartDate, loanEndDate, createdAt }
    pots/
      {docId}: { name, percentage, createdAt }
```

**Models (`lib/models/`):** `expense.dart` and `pot.dart` — plain Dart classes. IDs are `String` (Firestore document IDs).

**Deprecated:** `lib/db_helper.dart` — old SQLite helper, fully commented out. Do not use or restore.

## Key Dependencies

- `firebase_core`, `firebase_auth`, `cloud_firestore` — Firebase backend
- `local_auth` — biometric authentication (fingerprint/face on Android; Windows Hello on Windows)
- `flutter_secure_storage` — encrypted on-device storage for biometric credentials
- `bitsdojo_window` — custom window sizing on Windows
- `google_fonts` — Montserrat font

## Conventions

- Currency displayed in GBP (£)
- Expenses sorted: loans first, then non-loans
- Loan end dates colour-coded: red if expired, orange if within 60 days
- Section widgets (ExpensesSection, PotsSection) are collapsible and manage their own CRUD dialogs
- Dialogs use `SingleChildScrollView` to prevent keyboard overflow on mobile
- HomeScreen body wrapped in `SafeArea`
- Login fields wrapped in `AutofillGroup` for OS credential suggestions
- AppBar background: `Theme.of(context).colorScheme.onSecondaryContainer` (dark teal), foreground white

## Firestore Security Rules (to be set in Firebase Console)

Rules should restrict read/write to authenticated users accessing only their own data:

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
