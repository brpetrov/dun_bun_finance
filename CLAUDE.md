# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dun Bun Finance is a personal finance Flutter desktop app (primarily Windows) for tracking monthly expenses, loans, and income allocation via percentage-based "pots." Uses SQLite for local persistence.

## Build & Run Commands

All commands run from the `dun_bun_finance/` subdirectory:

```bash
cd dun_bun_finance
flutter pub get          # Install dependencies
flutter run -d windows   # Run on Windows
flutter analyze          # Static analysis (uses flutter_lints)
flutter test             # Run all tests (no tests exist yet)
```

## Architecture

**Entry point:** `lib/main.dart` — initializes sqflite_common_ffi for desktop, configures bitsdojo_window (900x900, min 800x600), sets up named routes (`/login` → `/home`).

**Screens & routing:**
- `/login` → `LoginScreen` — hardcoded credential auth (local only, no backend)
- `/home` → `HomeScreen` — main dashboard, stateful, owns all data loading and calculation logic

**Data flow:** HomeScreen is the single source of truth. It loads expenses/pots from SQLite, calculates totals, and passes data + callbacks down to four section widgets:
- `MonthlyIncomeInput` — text field for income entry
- `ExpensesSection` — CRUD for expenses (supports loan flag with start/end dates)
- `TotalSection` — displays computed totals
- `PotsSection` — CRUD for pots; each pot gets a percentage of income-after-expenses

**Database:** `lib/db_helper.dart` (`SQLHelper`) — static methods for all CRUD. Two tables: `expenses` (with loan fields) and `pots`. DB stored at `getApplicationDocumentsDirectory()/dun_bun_finance.db`.

**Models:** `lib/models/expense.dart` and `lib/models/pot.dart` — plain Dart classes with `fromJson`/`toJson` for SQLite row mapping. Note: there is also a duplicate `lib/pot.dart` with a slightly different implementation.

## Key Dependencies

- `sqflite` + `sqflite_common_ffi` — SQLite (ffi variant for desktop)
- `path_provider` — app documents directory for DB path
- `bitsdojo_window` — custom window sizing on Windows
- `provider` — declared but not yet used in code

## Conventions

- Currency displayed in GBP (£)
- Expenses are sorted with loans first, then non-loans
- Loan end dates use color coding: red if expired, orange if within 60 days
- Section widgets (ExpensesSection, PotsSection) are collapsible and manage their own CRUD dialogs
