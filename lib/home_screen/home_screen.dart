import 'package:dun_bun_finance/home_screen/dialogs/analysis_review_dialog.dart';
import 'package:dun_bun_finance/services/theme_controller.dart';
import 'package:dun_bun_finance/spending_history/spending_history_screen.dart';
import 'package:dun_bun_finance/home_screen/dialogs/data_export_dialog.dart';
import 'package:dun_bun_finance/home_screen/dialogs/debt_payoff_dialog.dart';
import 'package:dun_bun_finance/home_screen/sections/expense_section.dart';
import 'package:dun_bun_finance/home_screen/sections/monthly_income_section.dart';
import 'package:dun_bun_finance/home_screen/sections/pot_section.dart';
import 'package:dun_bun_finance/home_screen/sections/totals_section.dart';
import 'package:dun_bun_finance/models/analysis_suggestion.dart';
import 'package:dun_bun_finance/services/auth_service.dart';
import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:dun_bun_finance/services/gemini_service.dart';
import 'package:dun_bun_finance/services/statement_parser_service.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> pots = [];
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;
  String _userRole = 'user';

  final TextEditingController _monthlyIncomeController =
      TextEditingController();

  double totalExpenses = 0.0;
  double incomeAfterExpenses = 0.0;
  Map<String, double> subtotalsByType = {};

  // Analysis state
  List<AnalysisSuggestion>? _minimizedSuggestions;
  String? _minimizedSummary;
  bool _isAnalyzing = false;
  String _analysisStatus = '';
  int _analysisElapsed = 0;
  Timer? _analysisTimer;

  // Negotiation banner state (session-only)
  bool _negotiationBannerDismissed = false;

  // Overdue loan banner state (session-only)
  bool _loanOverdueBannerDismissed = false;

  double subscriptionsTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    ThemeController.notifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.notifier.removeListener(_onThemeChanged);
    _monthlyIncomeController.dispose();
    _analysisTimer?.cancel();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _logError(String source, Object error, StackTrace stackTrace) {
    debugPrint('[HomeScreen][$source] $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _initializeData() async {
    try {
      await FirestoreService.migrateExpenseTypes();
      final role = await FirestoreService.getUserRole();
      if (mounted) setState(() => _userRole = role);
      await _refreshData();
    } catch (error, stackTrace) {
      _logError('_initializeData', error, stackTrace);
      _showSnackBar(
        'Error initializing data: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _refreshData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final fetchedPots = await FirestoreService.getPots();
      final allExpenses = await FirestoreService.getExpenses();
      final nextTotalExpenses = _calculateTotalExpensesFor(allExpenses);
      final nextIncomeAfterExpenses =
          _calculateIncomeAfterExpensesFor(nextTotalExpenses);

      // Compute per-type subtotals
      final nextSubtotals = <String, double>{};
      for (final type in ['debt', 'bill', 'savings', 'budget']) {
        nextSubtotals[type] = allExpenses
            .where((e) => (e['expenseType'] ?? 'bill') == type)
            .fold(0.0, (acc, e) {
          final rawCost = e['cost'];
          return acc +
              (rawCost is num
                  ? rawCost.toDouble()
                  : double.tryParse(rawCost?.toString() ?? '') ?? 0.0);
        });
      }

      // Compute subscriptions subtotal
      double nextSubscriptionsTotal = 0.0;
      for (final e in allExpenses) {
        if ((e['category'] as String?) == 'Subscription') {
          final rawCost = e['cost'];
          nextSubscriptionsTotal += rawCost is num
              ? rawCost.toDouble()
              : double.tryParse(rawCost?.toString() ?? '') ?? 0.0;
        }
      }

      if (!mounted) return;

      // Save a snapshot for the current month
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final income =
          double.tryParse(_monthlyIncomeController.text.trim()) ?? 0.0;
      await FirestoreService.saveMonthlySnapshot(
        month: monthKey,
        totalExpenses: nextTotalExpenses,
        subtotalsByType: Map<String, double>.from(nextSubtotals),
        income: income,
      );

      if (!mounted) return;

      setState(() {
        pots = fetchedPots;
        expenses = allExpenses;
        totalExpenses = nextTotalExpenses;
        incomeAfterExpenses = nextIncomeAfterExpenses;
        subtotalsByType = nextSubtotals;
        subscriptionsTotal = nextSubscriptionsTotal;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      _logError('_refreshData', error, stackTrace);
      if (!mounted) return;

      setState(() => isLoading = false);
      _showSnackBar(
        'Error loading data: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  double _calculateTotalExpensesFor(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      final rawCost = item['cost'];
      final cost = rawCost is num
          ? rawCost.toDouble()
          : double.tryParse(rawCost?.toString() ?? '') ?? 0.0;
      return sum + cost;
    });
  }

  double _calculateIncomeAfterExpensesFor(double currentTotalExpenses) {
    final monthlyIncome =
        double.tryParse(_monthlyIncomeController.text.trim()) ?? 0.0;
    final remainingIncome = monthlyIncome - currentTotalExpenses;
    return remainingIncome < 0 ? 0.0 : remainingIncome;
  }

  void calculateTotalExpenses() {
    try {
      final nextTotalExpenses = _calculateTotalExpensesFor(expenses);
      if (!mounted) {
        totalExpenses = nextTotalExpenses;
        return;
      }

      setState(() {
        totalExpenses = nextTotalExpenses;
        incomeAfterExpenses = _calculateIncomeAfterExpensesFor(totalExpenses);
      });
    } catch (error, stackTrace) {
      _logError('calculateTotalExpenses', error, stackTrace);
      _showSnackBar(
        'Error calculating total expenses: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  void calculateIncomeAfterExpenses() {
    try {
      final nextIncomeAfterExpenses =
          _calculateIncomeAfterExpensesFor(totalExpenses);

      if (!mounted) {
        incomeAfterExpenses = nextIncomeAfterExpenses;
        return;
      }

      setState(() {
        incomeAfterExpenses = nextIncomeAfterExpenses;
      });
    } catch (error, stackTrace) {
      _logError('calculateIncomeAfterExpenses', error, stackTrace);
      _showSnackBar(
        'Error calculating income after expenses: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  void _startAnalysisTimer() {
    _analysisElapsed = 0;
    _analysisTimer?.cancel();
    _analysisTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _analysisElapsed++);
    });
  }

  void _stopAnalysisTimer() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
  }

  Future<void> _analyzeStatement() async {
    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) return;

      final selectedFile = pickerResult.files.single;
      final fileBytes = selectedFile.bytes;

      if (fileBytes == null || fileBytes.isEmpty) {
        throw const FormatException(
          'The selected file could not be read. Please try another CSV export.',
        );
      }

      if (!mounted) return;

      setState(() {
        _isAnalyzing = true;
        _analysisStatus = 'Parsing CSV...';
      });
      _startAnalysisTimer();

      final transactions = await StatementParserService.parseFile(
        fileName: selectedFile.name,
        bytes: fileBytes,
      );

      if (!mounted) return;
      setState(() => _analysisStatus =
          'Analyzing ${transactions.length} transactions with AI...');

      final currentExpenses = await FirestoreService.getExpenses();
      final (suggestions, summary) = await GeminiService.analyzeStatement(
        transactions: transactions,
        currentExpenses: currentExpenses,
      );

      _stopAnalysisTimer();
      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      await _showAnalysisReview(suggestions, summary);
    } catch (error, stackTrace) {
      _stopAnalysisTimer();
      _logError('_analyzeStatement', error, stackTrace);

      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSnackBar(
          'Analysis failed: $error',
          backgroundColor: Colors.redAccent,
        );
      }
    }
  }

  Future<void> _showAnalysisReview(
    List<AnalysisSuggestion> suggestions,
    String summary,
  ) async {
    final result = await showDialog(
      context: context,
      builder: (_) => AnalysisReviewDialog(
        suggestions: suggestions,
        summary: summary,
      ),
    );

    if (!mounted) return;

    // User tapped minimize — store results and show FAB
    if (result == 'minimize') {
      setState(() {
        _minimizedSuggestions = suggestions;
        _minimizedSummary = summary;
      });
      _showSnackBar('Analysis minimized — tap the button to reopen');
      return;
    }

    // User cancelled
    if (result == null) {
      setState(() {
        _minimizedSuggestions = null;
        _minimizedSummary = null;
      });
      return;
    }

    // User applied suggestions
    final reviewedSuggestions = result as List<AnalysisSuggestion>;
    final count =
        await FirestoreService.applyAnalysisSuggestions(reviewedSuggestions);
    await _refreshData(silent: true);

    setState(() {
      _minimizedSuggestions = null;
      _minimizedSummary = null;
    });

    _showSnackBar(
      'Applied $count changes successfully',
      backgroundColor: Colors.green,
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _refreshData();
    } catch (error, stackTrace) {
      _logError('_handleRefresh', error, stackTrace);
      _showSnackBar(
        'Refresh failed: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text('Delete Account'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This cannot be undone.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'All your expenses, pots, and account data will be permanently deleted from our servers.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your password to confirm:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final password = passwordController.text;
    passwordController.dispose();

    if (password.isEmpty) {
      _showSnackBar('Password is required', backgroundColor: Colors.redAccent);
      return;
    }

    try {
      if (mounted) setState(() => isLoading = true);
      await FirestoreService.deleteUserData();
      await AuthService.deleteAccount(password);

      if (!mounted) return;
      setState(() => isLoading = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.greenAccent, size: 22),
              SizedBox(width: 8),
              Text('Account Deleted'),
            ],
          ),
          content: Text(
            'Your account and all associated data have been permanently deleted.',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7)),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    } catch (error, stackTrace) {
      _logError('_handleDeleteAccount', error, stackTrace);
      if (mounted) setState(() => isLoading = false);
      _showSnackBar(
        error.toString().contains('wrong-password') ||
                error.toString().contains('invalid-credential')
            ? 'Incorrect password. Please try again.'
            : 'Failed to delete account: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (error, stackTrace) {
      _logError('_handleLogout', error, stackTrace);
      _showSnackBar(
        'Logout failed: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _showDataExportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => DataExportDialog(
        expenses: expenses,
        pots: pots,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wallet, size: 22, color: Colors.tealAccent),
            SizedBox(width: 10),
            Text('How It All Works'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AboutPoint(
                  icon: Icons.attach_money,
                  color: Colors.tealAccent,
                  title: '1 — Enter your monthly income',
                  body:
                      'Type your take-home pay at the top. Everything else is calculated from this number, so keep it up to date each month.',
                ),
                SizedBox(height: 12),
                _AboutPoint(
                  icon: Icons.receipt_long_outlined,
                  color: Colors.orangeAccent,
                  title: '2 — Add your expenses',
                  body:
                      'Log every regular outgoing — rent, subscriptions, debts, savings contributions. Expenses are grouped into four types: Debt, Bills, Savings, and Budget.',
                ),
                SizedBox(height: 12),
                _AboutPoint(
                  icon: Icons.sync,
                  color: Colors.amber,
                  title: '3 — Mark variable amounts monthly',
                  body:
                      'Credit cards and similar expenses change each month. Mark them as "Variable" and the app will remind you to update the amount at the start of each month.',
                ),
                SizedBox(height: 12),
                _AboutPoint(
                  icon: Icons.savings_outlined,
                  color: Colors.greenAccent,
                  title: '4 — Set up pots',
                  body:
                      'Pots split what\'s left after expenses. Assign each pot a percentage — for example 50% emergency fund, 30% holiday, 20% fun money — and the app calculates the exact pound amount automatically.',
                ),
                SizedBox(height: 12),
                _AboutPoint(
                  icon: Icons.handshake_outlined,
                  color: Colors.purpleAccent,
                  title: '5 — Review your bills regularly',
                  body:
                      'Bills older than a year without a review are flagged in amber. Tap "Mark Reviewed" after checking a bill to reset the timer and stay on top of better deals.',
                ),
                SizedBox(height: 12),
                _AboutPoint(
                  icon: Icons.trending_down,
                  color: Colors.redAccent,
                  title: '6 — Plan your debt payoff',
                  body:
                      'Use the Debt Payoff Plan (admin menu) to compare the Avalanche and Snowball strategies. Enter a monthly budget and see exactly when you\'ll be debt-free and how much interest you\'ll pay.',
                ),
                SizedBox(height: 16),
                Text(
                  'Your data is stored securely in the cloud and syncs across devices whenever you log in.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _openSpendingHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SpendingHistoryScreen(),
      ),
    );
  }

  Future<void> _openMaintenance() async {
    final hasItems = await FirestoreService.hasMaintenanceItems();
    if (!mounted) return;
    if (hasItems) {
      Navigator.of(context).pushNamed('/hub');
    } else {
      Navigator.of(context).pushNamed('/hub/setup');
    }
  }

  Future<void> _showDebtPayoffDialog() async {
    final debts =
        expenses.where((e) => (e['expenseType'] ?? 'bill') == 'debt').toList();
    await showDialog<void>(
      context: context,
      builder: (_) => DebtPayoffDialog(debts: debts),
    );
  }

  Future<void> _markReviewed(Map<String, dynamic> expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Review'),
        content: Text('Mark "${expense['name']}" as reviewed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Reviewed'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await FirestoreService.markExpenseReviewed(expense['id'] as String);
      await _refreshData(silent: true);
      _showSnackBar('${expense['name']} marked as reviewed');
    } catch (error, stackTrace) {
      _logError('_markReviewed', error, stackTrace);
      _showSnackBar('Failed to mark reviewed: $error',
          backgroundColor: Colors.redAccent);
    }
  }

  int _monthsSince(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return 0;
    final now = DateTime.now();
    return (now.year - dt.year) * 12 + (now.month - dt.month);
  }

  List<Map<String, dynamic>> get _staleNegotiations {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    return expenses.where((e) {
      if ((e['expenseType'] ?? 'bill') != 'bill') return false;
      final lastReviewed = e['lastNegotiatedAt'] as String?;
      if (lastReviewed != null) {
        // Previously reviewed — flag if over 12 months ago
        final dt = DateTime.tryParse(lastReviewed);
        return dt != null && dt.isBefore(cutoff);
      }
      // Never reviewed — flag if bill was created over 12 months ago
      final rawCreatedAt = e['createdAt'];
      if (rawCreatedAt == null) return false;
      final createdAt = DateTime.tryParse(rawCreatedAt.toString());
      return createdAt != null && createdAt.isBefore(cutoff);
    }).toList();
  }

  List<Map<String, dynamic>> get _overdueLoans {
    final now = DateTime.now();
    return expenses.where((e) {
      if (e['isLoan'] != true) return false;
      final endRaw = e['loanEndDate'];
      if (endRaw == null) return false;
      final endDate = DateTime.tryParse(endRaw.toString());
      return endDate != null && endDate.isBefore(now);
    }).toList();
  }

  Widget _buildLoanOverdueBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.redAccent),
                const SizedBox(width: 8),
                const Text(
                  'Overdue loans / contracts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16, color: Colors.redAccent),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _loanOverdueBannerDismissed = true),
                ),
              ],
            ),
          ),
          ..._overdueLoans.map((e) {
            final endRaw = e['loanEndDate'] as String?;
            final endDate = endRaw != null ? DateTime.tryParse(endRaw) : null;
            final daysOverdue =
                endDate != null ? DateTime.now().difference(endDate).inDays : 0;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.credit_card,
                  size: 18, color: Colors.redAccent),
              title: Text(e['name'] as String),
              subtitle: Text(
                'End date: ${endDate != null ? '${endDate.day}/${endDate.month}/${endDate.year}' : 'unknown'} · $daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNegotiationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                const Icon(Icons.handshake_outlined,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  'Bills to renegotiate',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.amber),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _negotiationBannerDismissed = true),
                ),
              ],
            ),
          ),
          ..._staleNegotiations.map((e) {
            final months = _monthsSince(e['lastNegotiatedAt'] as String);
            return ListTile(
              dense: true,
              title: Text(e['name'] as String),
              subtitle: Text(
                '$months months since last review · Renegotiating could save money',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ),
              trailing: FilledButton(
                onPressed: () => _markReviewed(e),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child:
                    const Text('Mark Reviewed', style: TextStyle(fontSize: 12)),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hello, ${widget.username}'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _userRole == 'admin'
                    ? Colors.amber.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _userRole == 'admin'
                      ? Colors.amber.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _userRole == 'admin' ? 'Admin' : 'User',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _userRole == 'admin'
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'analyze':
                  _analyzeStatement();
                case 'debt_plan':
                  _showDebtPayoffDialog();
                case 'toggle_theme':
                  ThemeController.toggle();
                case 'spending_history':
                  _openSpendingHistory();
                case 'maintenance':
                  _openMaintenance();
                case 'refresh':
                  _handleRefresh();
                case 'export':
                  _showDataExportDialog();
                case 'about':
                  _showAboutDialog();
                case 'logout':
                  _handleLogout();
                case 'delete_account':
                  _handleDeleteAccount();
              }
            },
            itemBuilder: (context) => [
              if (_userRole == 'admin') ...[
                const PopupMenuItem(
                  value: 'analyze',
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome),
                    title: Text('Analyze Statement'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'debt_plan',
                  child: ListTile(
                    leading: Icon(Icons.trending_down),
                    title: Text('Debt Payoff Plan'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.data_object),
                    title: Text('Export Data'),
                    dense: true,
                  ),
                ),
                const PopupMenuDivider(),
              ],
              PopupMenuItem(
                value: 'toggle_theme',
                child: ListTile(
                  leading: Icon(ThemeController.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                  title:
                      Text(ThemeController.isDark ? 'Light Mode' : 'Dark Mode'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'spending_history',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('Spending History'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'maintenance',
                child: ListTile(
                  leading: Icon(Icons.hub_outlined),
                  title: Text('Life Hub'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('How it Works'),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'delete_account',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _minimizedSuggestions != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAnalysisReview(
                _minimizedSuggestions!,
                _minimizedSummary!,
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Review Analysis'),
            )
          : null,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (!_loanOverdueBannerDismissed && _overdueLoans.isNotEmpty)
                    _buildLoanOverdueBanner(),
                  if (!_negotiationBannerDismissed &&
                      _staleNegotiations.isNotEmpty)
                    _buildNegotiationBanner(),
                  if (_isAnalyzing)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _analysisStatus,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '${_analysisElapsed}s',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonthlyIncomeInput(
                              controller: _monthlyIncomeController,
                              onSubmit: calculateIncomeAfterExpenses,
                            ),
                            const Divider(),
                            ExpensesSection(
                              expenses: expenses,
                              onExpenseUpdated: () =>
                                  _refreshData(silent: true),
                            ),
                            const Divider(),
                            TotalSection(
                              totalExpenses: totalExpenses,
                              incomeAfterExpenses: incomeAfterExpenses,
                              subtotalsByType: subtotalsByType,
                              subscriptionsTotal: subscriptionsTotal,
                            ),
                            const Divider(),
                            PotsSection(
                              pots: pots,
                              onPotUpdated: () => _refreshData(silent: true),
                              incomeAfterExpenses: incomeAfterExpenses,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AboutPoint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _AboutPoint({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
