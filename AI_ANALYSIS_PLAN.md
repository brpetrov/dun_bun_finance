# AI-Powered Bank Statement Analysis — Implementation Plan

## Overview

Import a bank statement (CSV or PDF), use Google Gemini AI (free tier) to compare it against existing tracked expenses, and let the user approve suggested changes — adding missing expenses, fixing mismatches, or removing phantom ones.

**AI Provider:** Google Gemini — free tier (15 req/min, 1M tokens/day), official Flutter SDK.

---

## Phase 0 — Add Categories to Expenses

Before building the AI feature, add a `category` field to expenses. This helps the AI match bank transactions to app expenses more accurately (e.g. knowing "Netflix" is a "Subscription" helps match it to "NETFLIX.COM 1234567"). It also improves the app's organisation for the user.

### Step 0.1: Update Firestore schema

Add `category` (String, optional) to expense documents. Existing expenses without a category will default to "Other".

**Updated Firestore expense document:**

```
{ name, cost, isLoan, loanStartDate, loanEndDate, category, createdAt }
```

### Step 0.2: Update `lib/models/expense.dart`

Add `String category = 'Other'` field to the Expense class.

### Step 0.3: Update `lib/services/firestore_service.dart`

- `createExpense()` — add `category` parameter
- `getExpenses()` — include category in returned maps (default to "Other" if missing)
- `updateExpense()` — no change needed (already accepts a map)

### Step 0.4: Update `lib/home_screen/sections/expense_section.dart`

- Add a dropdown to the expense dialog for selecting category
- Predefined categories: "Subscription", "Utilities", "Insurance", "Loan", "Rent/Mortgage", "Transport", "Food & Groceries", "Entertainment", "Health & Fitness", "Other"
- Show category as a small chip/label on each expense tile in the list
- Pre-select "Loan" category when the loan checkbox is ticked

### Step 0.5: Update CLAUDE.md

Add `category` to the Firestore data structure section.

**Files modified:**

- `lib/models/expense.dart`
- `lib/services/firestore_service.dart`
- `lib/home_screen/sections/expense_section.dart`
- `CLAUDE.md`

---

## Phase 1 — Foundation (no AI yet)

### Step 1.1: Add dependencies to `pubspec.yaml`

Add these under `dependencies:`:

```yaml
google_generative_ai: ^0.4.6 # Gemini Flutter SDK
file_picker: ^8.0.0 # Cross-platform file picker (Windows + Android)
csv: ^6.0.0 # CSV parsing
syncfusion_flutter_pdf: ^27.1.0 # PDF text extraction (free community license)
```

Then run `flutter pub get`.

### Step 1.2: Create `lib/models/statement_transaction.dart`

Simple model for a parsed bank transaction:

- `description` (String) — transaction description from statement
- `amount` (double) — transaction amount
- `date` (DateTime?) — transaction date
- `toJson()` method for sending to AI

### Step 1.3: Create `lib/models/analysis_suggestion.dart`

Model for an AI suggestion:

- `type` — enum: `missing`, `mismatch`, `phantom`
- `description` (String) — human-readable explanation
- `matchedExpenseId` (String?) — ID of existing expense (for mismatch/phantom)
- `suggestedName` (String?) — for missing expenses
- `suggestedCost` (double?) — suggested amount
- `suggestedCategory` (String?) — suggested category for missing expenses
- `suggestedIsLoan` (bool) — whether it's a loan
- `confidence` (String) — "high", "medium", or "low"
- `accepted` (bool) — user toggle in review UI
- `fromJson()` factory constructor

### Step 1.4: Create `lib/services/statement_parser_service.dart`

CSV parsing with heuristic column detection:

- `parseFile(String filePath)` — detect CSV vs PDF, delegate
- `parseCsv(String filePath)` — parse CSV locally
  - Heuristic header detection for common UK bank formats
  - Date columns: "date", "transaction date", "posting date"
  - Description columns: "description", "narrative", "details", "memo"
  - Amount columns: "amount", "value", "debit", "money out", "paid out"
  - Handle single-amount and split debit/credit formats
  - Strip currency symbols (£), handle negatives

---

## Phase 2 — Gemini Integration

### Step 2.1: Create `lib/services/gemini_service.dart`

Static service (same pattern as BiometricService):

- `saveApiKey(String key)` — store via flutter_secure_storage
- `getApiKey()` — retrieve stored key
- `hasApiKey()` — check if key exists
- `analyzeStatement(transactions, currentExpenses)` — core method:
  1. Build prompt with current expenses (including IDs + categories) + parsed transactions
  2. Send to Gemini with `responseMimeType: 'application/json'`
  3. Parse JSON response into `List<AnalysisSuggestion>`
  4. Strip markdown code fences if present, retry once on malformed JSON

### AI Prompt — Full Specification

**System instruction:**

```
You are a financial analysis assistant for a personal budgeting app that tracks
recurring monthly expenses in GBP (£). You MUST respond with valid JSON only,
no markdown, no explanation outside the JSON structure.
```

**User prompt template:**

```
I have a list of recurring expenses tracked in my budgeting app, and a list of
transactions from my bank statement. Analyze them and identify discrepancies.

=== IMPORTANT CONTEXT ===

In this app, expenses flagged as "Contract" (field: isLoan) are NOT
necessarily loans. They are recurring payments with a start and end date
— for example electricity bills, phone contracts, insurance policies,
gym memberships, or actual loans. The "Contract" flag simply means the
payment has a defined period the user wants to track. Treat them the
same as any other recurring expense when matching against bank transactions.

=== MATCHING RULES ===

1. NAMES WILL NOT MATCH EXACTLY. Bank statements use merchant codes,
   abbreviations, and reference numbers. Match by meaning, not by string.
   Examples:
   - "Netflix" matches "NETFLIX.COM 1234567890"
   - "Car Insurance" matches "ADMIRAL INS CO LTD"
   - "Phone Bill" matches "EE LIMITED DD"
   - "Gym" matches "PUREGYM 01onal LONDON GB"
   - "Rent" matches "MR J SMITH STANDING ORDER"

2. Match by AMOUNT first, then confirm by name/description similarity.
   If an app expense of £15.99 named "Netflix" exists and the bank shows
   "NETFLIX.COM" for £15.99, that is a HIGH confidence match.

3. Use the expense CATEGORY to help matching. A "Subscription" expense
   is more likely to match a recurring digital service charge. An "Insurance"
   expense is more likely to match an insurer's merchant code.

4. For AMOUNT mismatches: if the name/description is clearly the same
   service but the amount differs, flag as MISMATCH with both the app
   amount and the bank amount.

5. RECURRING detection: a transaction is likely recurring if it appears
   multiple times with similar amounts, or if it is a Direct Debit (DD)
   or Standing Order (SO). One-off purchases (groceries, fuel, restaurants,
   ATM withdrawals, one-time shops) should be IGNORED completely.

6. STANDING ORDERS and DIRECT DEBITS are almost always recurring expenses.
   Pay special attention to these.

7. When suggesting names for MISSING expenses, use a clean human-friendly
   name, NOT the raw bank description.
   Example: suggest "Pure Gym" not "PUREGYM 01onal LONDON GB"

8. When suggesting a category for MISSING expenses, pick from this list:
   Subscription, Utilities, Insurance, Contract, Rent/Mortgage, Transport,
   Food & Groceries, Entertainment, Health & Fitness, Other

9. CONFIDENCE levels:
   - HIGH: amount matches exactly AND name is clearly the same service
   - MEDIUM: amount is close (within £2) OR name is similar but not certain
   - LOW: possible match but uncertain (e.g. generic description like
     "CARD PAYMENT" or very different amounts)

=== FIND THESE THREE TYPES ===

1. MISSING: Recurring transactions in the bank statement that are NOT
   tracked as expenses in the app. Only include genuinely recurring
   monthly costs (subscriptions, bills, insurance, etc.), NOT one-off
   purchases.

2. MISMATCH: Expenses in the app where the amount differs from what
   the bank statement shows for the same service. Include both the
   current app amount and the bank amount in the description.

3. PHANTOM: Expenses tracked in the app that do NOT appear anywhere
   in the bank statement — possibly cancelled subscriptions or services
   the user no longer pays for.

=== MY APP EXPENSES ===
{json array: [{id, name, cost, category, isLoan}]}

=== BANK STATEMENT TRANSACTIONS ===
{json array: [{description, amount, date}]}

=== RESPOND WITH THIS EXACT JSON STRUCTURE ===
{
  "suggestions": [
    {
      "type": "missing" | "mismatch" | "phantom",
      "description": "Human-readable explanation of what was found",
      "matched_expense_id": "string or null",
      "suggested_name": "string or null",
      "suggested_cost": number or null,
      "suggested_category": "string or null",
      "suggested_is_loan": false,
      "confidence": "high" | "medium" | "low"
    }
  ],
  "summary": "Brief 1-2 sentence overall summary of findings"
}
```

### PDF structuring prompt (separate call for PDFs only):

```
Extract all financial transactions from the following bank statement text.
Return ONLY a JSON array where each element has:
{"description": "...", "amount": 0.00, "date": "YYYY-MM-DD", "type": "debit"|"credit"}

Only include debit transactions (money going out). Ignore credits/deposits.
Amounts should be positive numbers in GBP.

=== BANK STATEMENT TEXT ===
{raw text from PDF extraction}
```

### Step 2.2: Create `lib/home_screen/dialogs/api_key_dialog.dart`

Simple dialog (follows existing dialog pattern):

- TextField for pasting Gemini API key
- "Save" button → calls `GeminiService.saveApiKey()`
- Instructional text: "Get a free API key from aistudio.google.com"
- Shows if key already exists with option to update

### Step 2.3: Add `applyAnalysisSuggestions()` to `lib/services/firestore_service.dart`

New method using Firestore batch writes for atomicity:

- `missing` suggestions → `batch.set()` new expense docs (include category)
- `mismatch` suggestions → `batch.update()` existing expense docs
- `phantom` suggestions → `batch.delete()` existing expense docs
- `await batch.commit()` — all or nothing

---

## Phase 3 — UI

### Step 3.1: Create `lib/home_screen/dialogs/analysis_review_dialog.dart`

Review dialog showing AI results:

- Header: AI summary text
- Three collapsible sections:
  - **Missing** (green) — expenses to add, each with CheckboxListTile
  - **Mismatches** (orange) — expenses to update
  - **Phantom** (red) — expenses to remove
- Each suggestion shows: name, amount, category, confidence badge (colour-coded)
- "Apply Selected" button at bottom
- Returns list of accepted suggestions

### Step 3.2: Add AppBar button to `lib/home_screen/home_screen.dart`

Add `IconButton(icon: Icon(Icons.auto_awesome))` to AppBar actions.

`onPressed` flow:

1. Check `GeminiService.hasApiKey()` → if not, show `ApiKeyDialog`
2. Open file picker: `FilePicker.platform.pickFiles(allowedExtensions: ['csv', 'pdf'])`
3. Show loading dialog
4. Parse file via `StatementParserService.parseFile()`
5. Fetch current expenses via `FirestoreService.getExpenses()`
6. Call `GeminiService.analyzeStatement()`
7. Dismiss loading, show `AnalysisReviewDialog`
8. On apply: call `FirestoreService.applyAnalysisSuggestions()`
9. Call `_refreshData()` + recalculate totals
10. Show SnackBar: "Applied X changes"

---

## Phase 4 — PDF Support

### Step 4.1: Add PDF text extraction to `StatementParserService`

- `parsePdf(String filePath)` — use `syncfusion_flutter_pdf` to extract text
- If extracted text is empty/very short → warn user (image-based PDF)
- Send extracted text to Gemini with the PDF structuring prompt

### Step 4.2: Add PDF structuring prompt to `GeminiService`

New method `structurePdfText(String rawText)`:

- Prompt asks Gemini to extract debit transactions from raw PDF text
- Returns `List<StatementTransaction>`
- Only includes money going out (debits), ignores credits/deposits

---

## Phase 5 — Polish

### Step 5.1: Error handling

| Scenario              | Response                                      |
| --------------------- | --------------------------------------------- |
| No API key            | Show ApiKeyDialog                             |
| Invalid API key       | SnackBar: "Invalid API key"                   |
| Rate limited (429)    | SnackBar: "Rate limit reached, wait a minute" |
| Unparseable CSV       | SnackBar: "Could not parse this CSV format"   |
| Image-based PDF       | SnackBar: "Could not read PDF, try CSV"       |
| Invalid AI response   | Retry once, then SnackBar error               |
| No transactions found | SnackBar: "No transactions found"             |
| Firestore batch fails | SnackBar: "Failed to apply changes"           |

### Step 5.2: Settings option to manage API key

Add a way for the user to update or remove their Gemini API key (e.g. long-press on the analysis button, or a settings menu).

---

## Files Summary

### New files (6):

- `lib/models/statement_transaction.dart`
- `lib/models/analysis_suggestion.dart`
- `lib/services/gemini_service.dart`
- `lib/services/statement_parser_service.dart`
- `lib/home_screen/dialogs/api_key_dialog.dart`
- `lib/home_screen/dialogs/analysis_review_dialog.dart`

### Modified files (Phase 0 + Phases 1-5):

- `lib/models/expense.dart` — add `category` field
- `lib/services/firestore_service.dart` — add `category` to createExpense + add `applyAnalysisSuggestions()`
- `lib/home_screen/sections/expense_section.dart` — add category dropdown + category chip on tiles
- `pubspec.yaml` — add 4 dependencies
- `lib/home_screen/home_screen.dart` — add AppBar button + analysis flow
- `CLAUDE.md` — update Firestore schema

---

## Prerequisites

1. Get a free Gemini API key from https://aistudio.google.com
2. Have a bank statement CSV or PDF ready for testing

---

## Predefined Categories

Used in expense dialog dropdown and AI suggestions:

- Subscription
- Utilities
- Insurance
- Contract
- Rent/Mortgage
- Transport
- Food & Groceries
- Entertainment
- Health & Fitness
- Other (default)

---

## Current Progress

- [ ] Phase 0 — Add Categories
  - [ ] Step 0.1: Update Firestore schema
  - [ ] Step 0.2: Update Expense model
  - [ ] Step 0.3: Update FirestoreService
  - [ ] Step 0.4: Update ExpensesSection UI (dropdown + chips)
  - [ ] Step 0.5: Update CLAUDE.md
- [ ] Phase 1 — Foundation
  - [ ] Step 1.1: Add dependencies
  - [ ] Step 1.2: StatementTransaction model
  - [ ] Step 1.3: AnalysisSuggestion model
  - [ ] Step 1.4: StatementParserService
- [ ] Phase 2 — Gemini Integration
  - [ ] Step 2.1: GeminiService
  - [ ] Step 2.2: ApiKeyDialog
  - [ ] Step 2.3: applyAnalysisSuggestions in FirestoreService
- [ ] Phase 3 — UI
  - [ ] Step 3.1: AnalysisReviewDialog
  - [ ] Step 3.2: HomeScreen AppBar button + wiring
- [ ] Phase 4 — PDF Support
  - [ ] Step 4.1: PDF text extraction
  - [ ] Step 4.2: PDF structuring prompt
- [ ] Phase 5 — Polish
  - [ ] Step 5.1: Error handling
  - [ ] Step 5.2: API key management
