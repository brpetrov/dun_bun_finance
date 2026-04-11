# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dun Bun Finance is a cross-platform personal finance Flutter app (Windows primary, Android and iOS supported) for tracking monthly expenses, loans, savings, and income allocation via percentage-based "pots." Uses Firebase Auth for authentication and Cloud Firestore for per-user data storage. Includes Gemini AI-powered bank statement analysis.

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
- Register: creates account → writes Firestore user profile (`role: 'user'`) → sends verification email → signs out → redirects to login. Unverified logins are blocked with an orange snackbar and a "Resend" action.
- Login: signs in → checks `emailVerified` → if first time with biometrics available, offers biometric enrollment → navigates to home.
- Auto-login on startup: if `AuthService.currentUser != null` routes directly to `/home`; otherwise if biometric is enabled, prompts biometric → signs in with stored credentials.

**Data flow:** HomeScreen is the single source of truth. It loads expenses/pots from Firestore, calculates totals, and passes data + callbacks down to four section widgets:
- `MonthlyIncomeInput` — text field for income entry
- `ExpensesSection` — CRUD for expenses grouped by type with collapsible sections
- `TotalSection` — displays computed totals and per-type subtotals
- `PotsSection` — CRUD for pots; each pot gets a percentage of income-after-expenses

**AppBar:** Single `PopupMenuButton` (3-dot menu) replaces individual icon buttons. Admin-only items (Analyze Statement, Export Data) are only shown when `_userRole == 'admin'`. A role badge is shown next to the username in the title.

**Services (`lib/services/`):**
- `auth_service.dart` (`AuthService`) — thin wrapper around `FirebaseAuth`. Static methods: `signUp`, `signIn`, `signOut`, `currentUser`, `authStateChanges`.
- `firestore_service.dart` (`FirestoreService`) — all Firestore CRUD. Methods include: `createExpense`, `getExpenses`, `updateExpense`, `deleteExpense`, `createPot`, `getPots`, `updatePot`, `deletePot`, `clearAll`, `migrateExpenseTypes`, `applyAnalysisSuggestions`, `getUserProfile`, `createUserProfile`, `getUserRole`.
- `biometric_service.dart` (`BiometricService`) — wraps `local_auth` + `flutter_secure_storage`. Stores encrypted email/password on-device. Methods: `isAvailable`, `isEnabled`, `enable`, `disable`, `authenticate` (returns `(email, password)` record on success).
- `gemini_service.dart` (`GeminiService`) — sends parsed transactions + current expenses to Gemini AI and returns `(List<AnalysisSuggestion>, String summary)`. Admin-only feature.
- `statement_parser_service.dart` (`StatementParserService`) — parses CSV bank statement exports into a list of `StatementTransaction` objects.

**Dialogs (`lib/home_screen/dialogs/`):**
- `analysis_review_dialog.dart` — shows Gemini AI suggestions; user can accept/reject each, minimize to a FAB, or apply all accepted changes.
- `data_export_dialog.dart` — shows current expenses and pots in a copyable/exportable format. Admin-only.

**Models (`lib/models/`):**
- `expense.dart` — `Expense` class + `ExpenseType` enum (`debt`, `bill`, `savings`, `budget`). Each type has `.label`, `.icon`, `.color`. `Expense.typeDisplayOrder` defines section render order. `Expense.categories` is the list of category strings.
- `pot.dart` — `Pot` class.
- `analysis_suggestion.dart` — `AnalysisSuggestion` + `SuggestionType` enum (`missing`, `mismatch`, `phantom`, `insight`).
- `statement_transaction.dart` — `StatementTransaction` class for parsed CSV rows.

**Deprecated:** `lib/db_helper.dart` — old SQLite helper, fully commented out. Do not use or restore.

## Firestore Data Structure

```
users/
  {uid}/                          ← user profile doc: { role, displayName, createdAt }
    expenses/
      {docId}: {
        name, cost, category,
        expenseType,              ← 'debt' | 'bill' | 'savings' | 'budget'
        isVariable,               ← bool: true for credit cards / amounts that change monthly
        isLoan,                   ← bool: true for contracts with start/end dates
        loanStartDate,
        loanEndDate,
        createdAt,
        updatedAt                 ← used to detect if a variable expense needs this month's update
      }
    pots/
      {docId}: { name, percentage, createdAt }
```

## User Roles

Roles are stored in `users/{uid}.role` (string). Default on registration: `'user'`.

| Role    | Capabilities |
|---------|-------------|
| `admin` | Full access: CRUD expenses/pots, Analyze Statement (Gemini AI), Export Data |
| `user`  | CRUD expenses/pots, Refresh, Logout |

To promote a user to admin: set `role: "admin"` directly in the Firebase Console on their `users/{uid}` document. Existing accounts without a `role` field are auto-assigned `'user'` on next app load via `getUserRole()`.

## Expense Types & Variable Expenses

Expenses are classified into four types displayed in order: **Debt → Bills → Savings → Budget**.

- `expenseType` is stored as a string name matching the `ExpenseType` enum.
- `isVariable: true` marks expenses whose amount changes monthly (e.g. Barclaycard, Monzo Flex). These appear in a highlighted "Monthly Updates" section at the top of the expense list when `updatedAt` is from a prior month, prompting the user to enter this month's amount.
- Saving any update to a variable expense sets `updatedAt: FieldValue.serverTimestamp()`, which clears the stale prompt for the current month.
- `migrateExpenseTypes()` is called on app start to backfill `expenseType` on any legacy documents missing the field.

## Key Dependencies

- `firebase_core`, `firebase_auth`, `cloud_firestore` — Firebase backend
- `local_auth` — biometric authentication (fingerprint/face on Android; Windows Hello on Windows)
- `flutter_secure_storage` — encrypted on-device storage for biometric credentials
- `bitsdojo_window` — custom window sizing on Windows
- `google_fonts` — Montserrat font
- `file_picker` — used to pick CSV files for bank statement analysis
- `google_generative_ai` — Gemini AI SDK for statement analysis

## Conventions

- Currency displayed in GBP (£); cost fields show a `£` prefix inside the input
- Section widgets (ExpensesSection, PotsSection) are collapsible and manage their own CRUD dialogs
- Expense sections are further grouped by `ExpenseType`, each sub-section also collapsible with its own subtotal and add button
- Responsive layout: grids used at >900px (expenses/pots) and ≥500px (totals subtotals); lists below those thresholds
- Grid cards use `mainAxisExtent` (fixed height) not `childAspectRatio` — prevents cards scaling with screen width
- Expense type selector in dialogs uses a 2×2 `GridView.count` of `AnimatedContainer` tiles (not `SegmentedButton`)
- Dialogs use `SingleChildScrollView` to prevent keyboard overflow on mobile
- HomeScreen body wrapped in `SafeArea`
- Login fields wrapped in `AutofillGroup` for OS credential suggestions
- AppBar background: `Theme.of(context).colorScheme.onSecondaryContainer` (dark teal), foreground white

## Firestore Security Rules (to be set in Firebase Console)

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
