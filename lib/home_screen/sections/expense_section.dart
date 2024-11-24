import 'package:dun_bun_finance/db_helper.dart';
import 'package:dun_bun_finance/models/expense.dart';
import 'package:flutter/material.dart';

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
        final rawLoanStartDate = expense['loanStartDate'];
        final rawLoanEndDate = expense['loanEndDate'];

        loanStartDate =
            (rawLoanStartDate != null && rawLoanStartDate.isNotEmpty)
                ? DateTime.tryParse(rawLoanStartDate)
                : null;

        loanEndDate = (rawLoanEndDate != null && rawLoanEndDate.isNotEmpty)
            ? DateTime.tryParse(rawLoanEndDate)
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
                        ? const Row(
                            children: [
                              Icon(
                                Icons.add,
                              ),
                              Text('Add Expense'),
                            ],
                          )
                        : const Row(
                            children: [
                              Icon(
                                Icons.edit,
                              ),
                              Text('Edit Expense'),
                            ],
                          ),
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
                content: SizedBox(
                  width: 500,
                  child: Column(
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
                        title: const Text("Loan"),
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
      final startDate =
          loanStartDate != null ? DateTime.parse(loanStartDate) : null;
      final today = DateTime.now();
      final timeToExpiry = endDate != null ? endDate.difference(today) : null;

      Color dateColor = Colors.black;

      if (timeToExpiry != null && timeToExpiry.isNegative) {
        dateColor = Colors.red;
      } else if (timeToExpiry != null && timeToExpiry.inDays <= 60) {
        dateColor = Colors.orange;
      }

      return Column(
        children: [
          Text(
            startDate != null ? "Start: ${_formatDate(startDate)}" : "No Date",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            endDate != null ? "End: ${_formatDate(endDate)}" : "No Date",
            style: TextStyle(
                color: dateColor, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
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
                icon: const Icon(Icons.add),
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
