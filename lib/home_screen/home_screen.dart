import 'package:dun_bun_finance/db_helper.dart';
import 'package:dun_bun_finance/home_screen/sections/expense_section.dart';
import 'package:dun_bun_finance/home_screen/sections/monthly_income_section.dart';
import 'package:dun_bun_finance/home_screen/sections/pot_section.dart';
import 'package:dun_bun_finance/home_screen/sections/totals_section.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  Future<void> _initializeData() async {
    await _refreshData();
    calculateTotalExpenses();
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    try {
      pots = await SQLHelper.getPots();
      var allExpenses = await SQLHelper.getExpenses();
      final loanItems =
          allExpenses.where((item) => item['isLoan'] == 1).toList();
      final nonLoanItems =
          allExpenses.where((item) => item['isLoan'] != 1).toList();
      expenses = [...loanItems, ...nonLoanItems];
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading data: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void calculateTotalExpenses() {
    totalExpenses =
        expenses.fold(0.0, (sum, item) => sum + (item['cost'] as double));
  }

  void calculateIncomeAfterExpenses() {
    double monthlyIncome =
        double.tryParse(_monthlyIncomeController.text) ?? 0.0;

    setState(() {
      incomeAfterExpenses = monthlyIncome - totalExpenses < 0
          ? 0.0
          : monthlyIncome - totalExpenses;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dun Bun Finance"),
        backgroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _refreshData();
              calculateTotalExpenses();
              calculateIncomeAfterExpenses();
            },
          ),
        ],
      ),
      body: isLoading
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
                        onExpenseUpdated: () async {
                          await _refreshData();
                          calculateTotalExpenses();
                        }),
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
    );
  }
}
