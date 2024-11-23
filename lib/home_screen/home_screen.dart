// ignore_for_file: use_build_context_synchronously

import 'package:dun_bun_finance/db_helper.dart';
import 'package:dun_bun_finance/expense.dart';
import 'package:dun_bun_finance/models/pot.dart';
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
      expenses = await SQLHelper.getExpenses();
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
    );
  }
}

class MonthlyIncomeInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const MonthlyIncomeInput({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Enter Monthly Income",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.money),
        ),
        onSubmitted: (value) => onSubmit(),
      ),
    );
  }
}

class ExpensesSection extends StatefulWidget {
  final List<Map<String, dynamic>> expenses;
  final VoidCallback onExpenseUpdated;

  const ExpensesSection({
    super.key,
    required this.expenses,
    required this.onExpenseUpdated,
  });

  @override
  State<ExpensesSection> createState() => _ExpensesSectionState();
}

class _ExpensesSectionState extends State<ExpensesSection> {
  bool isExpanded = true; // State to manage expand/collapse

  @override
  Widget build(BuildContext context) {
    final TextEditingController expenseNameController = TextEditingController();
    final TextEditingController expenseCostController = TextEditingController();
    bool isLoan = false;
    DateTime? loanStartDate;
    DateTime? loanEndDate;

    Future<void> addExpense() async {
      try {
        await SQLHelper.createExpense(
          expenseNameController.text,
          double.parse(expenseCostController.text),
          isLoan,
          loanStartDate?.toIso8601String(),
          loanEndDate?.toIso8601String(),
        );
        widget.onExpenseUpdated();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error adding expense: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    Future<void> updateExpense(Expense expense) async {
      try {
        await SQLHelper.updateExpense(expense);
        widget.onExpenseUpdated();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating expense: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    Future<void> deleteExpense(int id) async {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Expense Deleted"),
            backgroundColor: Colors.redAccent,
          ),
        );
        await SQLHelper.deleteExpense(id);
        widget.onExpenseUpdated();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting expense: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    void showExpensePopup(BuildContext context, int? id) {
      if (id != null) {
        final expense =
            widget.expenses.firstWhere((element) => element['id'] == id);
        expenseNameController.text = expense['name'];
        expenseCostController.text = expense['cost'].toString();
        isLoan = (expense['isLoan'] == 1); // Convert 0/1 to false/true
        loanStartDate = expense['loanStartDate'] != null
            ? DateTime.parse(expense['loanStartDate'])
            : null;
        loanEndDate = expense['loanEndDate'] != null
            ? DateTime.parse(expense['loanEndDate'])
            : null;
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              Future<void> pickDate(BuildContext context, bool isStart) async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    if (isStart) {
                      loanStartDate = pickedDate;
                      if (loanEndDate != null &&
                          loanEndDate!.isBefore(pickedDate)) {
                        loanEndDate = null;
                      }
                    } else {
                      loanEndDate = pickedDate;
                    }
                  });
                }
              }

              String? validateFields() {
                if (isLoan) {
                  if (loanStartDate == null) {
                    return "Loan start date is required.";
                  }
                  if (loanEndDate == null) {
                    return "Loan end date is required.";
                  }
                  if (loanEndDate!.isBefore(loanStartDate!)) {
                    return "Loan end date cannot be earlier than the start date.";
                  }
                }
                if (expenseNameController.text.isEmpty) {
                  return "Expense name cannot be empty.";
                }
                if (expenseCostController.text.isEmpty ||
                    double.tryParse(expenseCostController.text) == null) {
                  return "Invalid cost value.";
                }
                return null;
              }

              return AlertDialog(
                title: Row(
                  children: [
                    id == null
                        ? const Text('Add Expense')
                        : const Text('Edit Expense'),
                    const Spacer(),
                    if (id != null)
                      IconButton(
                        onPressed: () {
                          deleteExpense(id);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: expenseNameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: expenseCostController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      title: const Text("Is Loan"),
                      value: isLoan,
                      onChanged: (value) {
                        setState(() {
                          isLoan = value!;
                          if (!isLoan) {
                            loanStartDate = null;
                            loanEndDate = null;
                          }
                        });
                      },
                    ),
                    if (isLoan) ...[
                      ListTile(
                        title: const Text("Loan Start Date"),
                        subtitle: Text(
                          loanStartDate != null
                              ? "${loanStartDate!.toLocal()}".split(' ')[0]
                              : "Pick a date",
                        ),
                        onTap: () => pickDate(context, true),
                      ),
                      ListTile(
                        title: const Text("Loan End Date"),
                        subtitle: Text(
                          loanEndDate != null
                              ? "${loanEndDate!.toLocal()}".split(' ')[0]
                              : "Pick a date",
                        ),
                        onTap: () => pickDate(context, false),
                      ),
                    ],
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () async {
                      final validationError = validateFields();
                      if (validationError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(validationError),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      if (id == null) {
                        await addExpense();
                      } else {
                        await updateExpense(Expense(
                          id: id,
                          name: expenseNameController.text,
                          cost: double.parse(expenseCostController.text),
                          createdAt: DateTime.now(),
                          isLoan: isLoan,
                          loanStartDate: loanStartDate,
                          loanEndDate: loanEndDate,
                        ));
                      }
                      expenseNameController.clear();
                      expenseCostController.clear();
                      Navigator.of(context).pop();
                    },
                    child: const Text("Save"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel"),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    String _formatDate(DateTime date) {
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }

    Widget _buildExpenseTrailing(
        String? loanEndDate, String? loanStartDate, bool isLoan) {
      if (!isLoan) return const SizedBox();

      final endDate = loanEndDate != null ? DateTime.parse(loanEndDate) : null;
      final today = DateTime.now();
      final timeToExpiry = endDate != null ? endDate.difference(today) : null;

      Color dateColor = Colors.black;

      if (timeToExpiry != null && timeToExpiry.isNegative) {
        dateColor = Colors.red;
      } else if (timeToExpiry != null && timeToExpiry.inDays <= 60) {
        dateColor = Colors.orange;
      }

      return Text(
        endDate != null ? "End: ${_formatDate(endDate)}" : "No Date",
        style: TextStyle(color: dateColor, fontWeight: FontWeight.bold),
      );
    }

    return Column(
      children: [
        ListTile(
          title: const Text(
            "Expenses",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: () => showExpensePopup(context, null),
              ),
            ],
          ),
        ),
        if (isExpanded)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.expenses.length,
            itemBuilder: (context, index) {
              final expense = widget.expenses[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.attach_money)),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(expense['name']),
                    if (expense['isLoan'] == 1)
                      const Text("Loan",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                subtitle: Text("£${expense['cost']}"),
                trailing: _buildExpenseTrailing(
                  expense['loanEndDate'],
                  expense['loanStartDate'],
                  expense['isLoan'] == 1,
                ),
                onTap: () => showExpensePopup(context, expense['id']),
              );
            },
          ),
      ],
    );
  }
}

class PotsSection extends StatefulWidget {
  final List<Map<String, dynamic>> pots;
  final VoidCallback onPotUpdated;
  final double incomeAfterExpenses;

  const PotsSection({
    super.key,
    required this.pots,
    required this.onPotUpdated,
    required this.incomeAfterExpenses,
  });

  @override
  State<PotsSection> createState() => _PotsSectionState();
}

class _PotsSectionState extends State<PotsSection> {
  bool isExpanded = true; // State to manage expand/collapse

  void showPotPopup(BuildContext context, int? id) {
    final TextEditingController potNameController = TextEditingController();
    final TextEditingController potPercentageController =
        TextEditingController();

    if (id != null) {
      final pot = widget.pots.firstWhere((element) => element['id'] == id);
      potNameController.text = pot['name'];
      potPercentageController.text = pot['percentage'].toString();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              id == null ? const Text('Add Pot') : const Text('Edit Pot'),
              const Spacer(),
              if (id != null)
                IconButton(
                  onPressed: () {
                    deletePot(id);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: potNameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: potPercentageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Percentage',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final name = potNameController.text.trim();
                final percentageText = potPercentageController.text.trim();

                if (name.isEmpty || percentageText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill out all fields'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final percentage = int.tryParse(percentageText);
                if (percentage == null || percentage < 0 || percentage > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Percentage must be between 0 and 100'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                if (id == null) {
                  await addPot(name, percentage);
                } else {
                  await updatePot(Pot(
                    id: id,
                    name: name,
                    percentage: percentage,
                    createdAt: DateTime.now(),
                  ));
                }

                Navigator.of(context).pop();
              },
              child: Text(id == null ? 'Add' : 'Update'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> addPot(String name, int percentage) async {
    try {
      await SQLHelper.createPot(name, percentage);
      widget.onPotUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error adding pot: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> updatePot(Pot pot) async {
    try {
      await SQLHelper.updatePot(pot);
      widget.onPotUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating pot: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> deletePot(int id) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pot Deleted"),
          backgroundColor: Colors.redAccent,
        ),
      );
      await SQLHelper.deletePot(id);
      widget.onPotUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting pot: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text(
            "Pots",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.blue),
                onPressed: () => showPotPopup(context, null),
              ),
            ],
          ),
        ),
        if (isExpanded)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.pots.length,
            itemBuilder: (context, index) {
              final pot = widget.pots[index];
              final percentage = pot['percentage'] as int;
              final potValue = widget.incomeAfterExpenses * (percentage / 100);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.savings)),
                title: Text(pot['name']),
                subtitle: Text("$percentage%"),
                trailing: Text(
                  '£${potValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 17,
                  ),
                ),
                onTap: () => showPotPopup(context, pot['id']),
              );
            },
          ),
      ],
    );
  }
}

class TotalSection extends StatelessWidget {
  final double totalExpenses;
  final double incomeAfterExpenses;

  const TotalSection({
    super.key,
    required this.totalExpenses,
    required this.incomeAfterExpenses,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Expenses",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text("£${totalExpenses.toStringAsFixed(2)}"),
          const SizedBox(height: 10),
          const Text(
            "Income After Expenses",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            "£${incomeAfterExpenses.toStringAsFixed(2)}",
            style: TextStyle(
              color: incomeAfterExpenses >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
