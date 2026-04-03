import 'package:dun_bun_finance/home_screen/dialogs/analysis_review_dialog.dart';
import 'package:dun_bun_finance/home_screen/sections/expense_section.dart';
import 'package:dun_bun_finance/home_screen/sections/monthly_income_section.dart';
import 'package:dun_bun_finance/home_screen/sections/pot_section.dart';
import 'package:dun_bun_finance/home_screen/sections/totals_section.dart';
import 'package:dun_bun_finance/models/analysis_suggestion.dart';
import 'package:dun_bun_finance/services/auth_service.dart';
import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:dun_bun_finance/services/gemini_service.dart';
import 'package:dun_bun_finance/services/statement_parser_service.dart';
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

  final TextEditingController _monthlyIncomeController =
      TextEditingController();

  double totalExpenses = 0.0;
  double incomeAfterExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _monthlyIncomeController.dispose();
    super.dispose();
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
      await _refreshData();
    } catch (error, stackTrace) {
      _logError('_initializeData', error, stackTrace);
      _showSnackBar(
        'Error initializing data: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final fetchedPots = await FirestoreService.getPots();
      final allExpenses = await FirestoreService.getExpenses();
      final loanItems =
          allExpenses.where((item) => item['isLoan'] == true).toList();
      final nonLoanItems =
          allExpenses.where((item) => item['isLoan'] != true).toList();
      final orderedExpenses = [...loanItems, ...nonLoanItems];
      final nextTotalExpenses = _calculateTotalExpensesFor(orderedExpenses);
      final nextIncomeAfterExpenses =
          _calculateIncomeAfterExpensesFor(nextTotalExpenses);

      if (!mounted) return;

      setState(() {
        pots = fetchedPots;
        expenses = orderedExpenses;
        totalExpenses = nextTotalExpenses;
        incomeAfterExpenses = nextIncomeAfterExpenses;
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

  Future<void> _analyzeStatement() async {
    var isLoadingDialogVisible = false;

    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) {
        debugPrint('[HomeScreen][_analyzeStatement] File selection cancelled.');
        return;
      }

      final selectedFile = pickerResult.files.single;
      final fileBytes = selectedFile.bytes;

      if (fileBytes == null || fileBytes.isEmpty) {
        throw const FormatException(
          'The selected file could not be read. Please try another CSV export.',
        );
      }

      if (!mounted) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      isLoadingDialogVisible = true;

      final transactions = await StatementParserService.parseFile(
        fileName: selectedFile.name,
        bytes: fileBytes,
      );

      final currentExpenses = await FirestoreService.getExpenses();
      final (suggestions, summary) = await GeminiService.analyzeStatement(
        transactions: transactions,
        currentExpenses: currentExpenses,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      isLoadingDialogVisible = false;

      final reviewedSuggestions = await showDialog<List<AnalysisSuggestion>>(
        context: context,
        builder: (_) => AnalysisReviewDialog(
          suggestions: suggestions,
          summary: summary,
        ),
      );

      if (reviewedSuggestions == null || !mounted) return;

      final count =
          await FirestoreService.applyAnalysisSuggestions(reviewedSuggestions);
      await _refreshData();

      _showSnackBar(
        'Applied $count changes successfully',
        backgroundColor: Colors.green,
      );
    } catch (error, stackTrace) {
      _logError('_analyzeStatement', error, stackTrace);

      if (mounted && isLoadingDialogVisible) {
        Navigator.of(context).pop();
      }

      _showSnackBar(
        'Analysis failed: $error',
        backgroundColor: Colors.redAccent,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${widget.username}'),
        backgroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Analyze Bank Statement',
            onPressed: _analyzeStatement,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
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
                        onExpenseUpdated: _refreshData,
                      ),
                      const Divider(),
                      TotalSection(
                        totalExpenses: totalExpenses,
                        incomeAfterExpenses: incomeAfterExpenses,
                      ),
                      const Divider(),
                      PotsSection(
                        pots: pots,
                        onPotUpdated: _refreshData,
                        incomeAfterExpenses: incomeAfterExpenses,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
