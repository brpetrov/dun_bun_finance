import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:dun_bun_finance/models/statement_transaction.dart';
import 'package:dun_bun_finance/models/analysis_suggestion.dart';
import 'package:dun_bun_finance/config.dart';

class GeminiService {
  static Future<(List<AnalysisSuggestion>, String)> analyzeStatement({
    required List<StatementTransaction> transactions,
    required List<Map<String, dynamic>> currentExpenses,
  }) async {
    if (geminiApiKey.isEmpty || geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Gemini API key not configured in lib/config.dart');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: geminiApiKey,
      systemInstruction: Content.text(
        'You are a financial analysis assistant for a personal budgeting app '
        'that tracks recurring monthly expenses in GBP (£). You MUST respond '
        'with valid JSON only, no markdown, no explanation outside the JSON structure.',
      ),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final expensesJson = currentExpenses
        .map((e) => {
              'id': e['id'],
              'name': e['name'],
              'cost': e['cost'],
              'category': e['category'] ?? 'Other',
              'isContract': e['isLoan'] == true,
            })
        .toList();

    final transactionsJson = transactions.map((t) => t.toJson()).toList();

    final prompt = '''
I have a list of recurring expenses tracked in my budgeting app, and a list of transactions from my bank statement (exported from Monzo or similar UK bank). Analyze them and identify discrepancies.

=== IMPORTANT CONTEXT ===

In this app, expenses flagged as "Contract" (field: isContract) are NOT necessarily loans. They are recurring payments with a start and end date — for example electricity bills, phone contracts, insurance policies, gym memberships, or actual loans. The "Contract" flag simply means the payment has a defined period the user wants to track. Treat them the same as any other recurring expense when matching.

The bank statement transactions already have clean merchant names (e.g. "giffgaff", "E.ON Next", "Waggel") — they are NOT raw merchant codes. Match these directly against the app expense names.

=== MATCHING RULES ===

1. Match by NAME similarity first — the bank statement names are already clean and human-readable. "giffgaff" in the bank should match "Giffgaff" or "GiffGaff Phone" in the app. "E.ON Next" matches "EON" or "E.ON" or "Electricity".

2. Then confirm by AMOUNT. If an app expense of £22.49 named "Pet Insurance" exists and the bank shows "Waggel" for £22.49 monthly, that is a HIGH confidence match (Waggel is a pet insurer).

3. Use the expense CATEGORY to help matching. A "Subscription" expense is more likely to match a recurring digital service. An "Insurance" expense is more likely to match an insurer.

4. For AMOUNT mismatches: if the name/description is clearly the same service but the amount differs, flag as MISMATCH with both the app amount and the bank amount in the description.

5. RECURRING detection: look for transactions that appear multiple times in the statement with the same or very similar name and amount. Direct Debits and standing orders are almost always recurring.

6. One-off purchases should be IGNORED — things like groceries (Morrisons, Lidl, Tesco), eating out, shopping, ATM withdrawals, fuel, Uber rides, one-time transfers to people. Only flag genuinely recurring monthly costs.

7. When suggesting a category for MISSING expenses, pick from: Subscription, Utilities, Insurance, Contract, Rent/Mortgage, Transport, Food & Groceries, Entertainment, Health & Fitness, Other

8. CONFIDENCE levels:
   - HIGH: amount matches exactly AND name is clearly the same service
   - MEDIUM: amount is close (within £2) OR name is similar but not certain
   - LOW: possible match but uncertain

=== FIND THESE TYPES ===

1. MISSING: Recurring transactions in the bank statement that are NOT tracked as expenses in the app. Only include genuinely recurring monthly costs, NOT one-off purchases.

2. MISMATCH: Expenses in the app where the amount differs from what the bank statement shows. Include both amounts in the description.

3. PHANTOM: Expenses tracked in the app that do NOT appear anywhere in the bank statement — possibly cancelled or no longer active.

4. INSIGHT: Any useful observations about spending patterns. These are informational only and do not result in app changes.

=== MY APP EXPENSES ===
${jsonEncode(expensesJson)}

=== BANK STATEMENT TRANSACTIONS ===
${jsonEncode(transactionsJson)}

=== RESPOND WITH THIS EXACT JSON STRUCTURE ===
{
  "suggestions": [
    {
      "type": "missing|mismatch|phantom|insight",
      "description": "Human-readable explanation",
      "matched_expense_id": null,
      "suggested_name": null,
      "suggested_cost": null,
      "suggested_category": null,
      "suggested_is_loan": false,
      "confidence": "high|medium|low"
    }
  ],
  "summary": "Brief 1-2 sentence overall summary"
}
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final rawText = response.text ?? '';

    return _parseResponse(rawText);
  }

  static (List<AnalysisSuggestion>, String) _parseResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
    if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    final summary = json['summary'] as String? ?? 'Analysis complete.';
    final suggestionsJson = json['suggestions'] as List<dynamic>? ?? [];

    final suggestions = suggestionsJson
        .map((s) => AnalysisSuggestion.fromJson(s as Map<String, dynamic>))
        .toList();

    return (suggestions, summary);
  }
}
