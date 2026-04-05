import 'package:dun_bun_finance/models/expense.dart';
import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpensesSection extends StatefulWidget {
  final List<Map<String, dynamic>> expenses;
  final Future<void> Function() onExpenseUpdated;

  const ExpensesSection({
    super.key,
    required this.expenses,
    required this.onExpenseUpdated,
  });

  @override
  State<ExpensesSection> createState() => _ExpensesSectionState();
}

class _ExpensesSectionState extends State<ExpensesSection> {
  bool isExpanded = true;
  final Map<ExpenseType, bool> _sectionExpanded = {
    ExpenseType.debt: true,
    ExpenseType.bill: true,
    ExpenseType.savings: true,
    ExpenseType.budget: true,
  };

  void _logError(String source, Object error, StackTrace stackTrace) {
    debugPrint('[ExpensesSection][$source] $error');
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

  bool _needsMonthlyUpdate(Map<String, dynamic> expense) {
    if (expense['isVariable'] != true) return false;
    final rawUpdatedAt = expense['updatedAt'];
    if (rawUpdatedAt == null) return true;
    final updatedAt = DateTime.tryParse(rawUpdatedAt.toString());
    if (updatedAt == null) return true;
    final now = DateTime.now();
    return updatedAt.year != now.year || updatedAt.month != now.month;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController expenseNameController = TextEditingController();
    final TextEditingController expenseCostController = TextEditingController();
    var isLoan = false;
    var selectedCategory = 'Other';
    var selectedExpenseType = ExpenseType.bill;
    var isVariable = false;
    DateTime? loanStartDate;
    DateTime? loanEndDate;

    Future<bool> addExpense() async {
      try {
        await FirestoreService.createExpense(
          expenseNameController.text,
          double.parse(expenseCostController.text),
          isLoan,
          loanStartDate?.toIso8601String(),
          loanEndDate?.toIso8601String(),
          category: selectedCategory,
          expenseType: selectedExpenseType.name,
          isVariable: isVariable,
        );
        await widget.onExpenseUpdated();
        return true;
      } catch (error, stackTrace) {
        _logError('addExpense', error, stackTrace);
        _showSnackBar(
          'Error adding expense: $error',
          backgroundColor: Colors.redAccent,
        );
        return false;
      }
    }

    Future<bool> updateExpense(String id) async {
      try {
        await FirestoreService.updateExpense(id, {
          'name': expenseNameController.text,
          'cost': double.parse(expenseCostController.text),
          'category': selectedCategory,
          'expenseType': selectedExpenseType.name,
          'isVariable': isVariable,
          'isLoan': isLoan,
          'loanStartDate': loanStartDate?.toIso8601String(),
          'loanEndDate': loanEndDate?.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await widget.onExpenseUpdated();
        return true;
      } catch (error, stackTrace) {
        _logError('updateExpense', error, stackTrace);
        _showSnackBar(
          'Error updating expense: $error',
          backgroundColor: Colors.redAccent,
        );
        return false;
      }
    }

    Future<bool> deleteExpense(String id) async {
      try {
        await FirestoreService.deleteExpense(id);
        await widget.onExpenseUpdated();
        _showSnackBar(
          'Expense deleted',
          backgroundColor: Colors.redAccent,
        );
        return true;
      } catch (error, stackTrace) {
        _logError('deleteExpense', error, stackTrace);
        _showSnackBar(
          'Error deleting expense: $error',
          backgroundColor: Colors.redAccent,
        );
        return false;
      }
    }

    void showExpensePopup(BuildContext dialogContext, String? id,
        {ExpenseType? preselectedType}) {
      try {
        if (id != null) {
          final expense =
              widget.expenses.firstWhere((element) => element['id'] == id);
          expenseNameController.text = expense['name'];
          expenseCostController.text = expense['cost'].toString();
          selectedCategory = expense['category'] ?? 'Other';
          selectedExpenseType = ExpenseType.fromString(expense['expenseType']);
          isVariable = expense['isVariable'] == true;
          isLoan = expense['isLoan'] == true;
          final rawLoanStartDate = expense['loanStartDate'];
          final rawLoanEndDate = expense['loanEndDate'];

          loanStartDate =
              (rawLoanStartDate != null && rawLoanStartDate.isNotEmpty)
                  ? DateTime.tryParse(rawLoanStartDate)
                  : null;

          loanEndDate = (rawLoanEndDate != null && rawLoanEndDate.isNotEmpty)
              ? DateTime.tryParse(rawLoanEndDate)
              : null;
        } else {
          expenseNameController.clear();
          expenseCostController.clear();
          selectedCategory = 'Other';
          selectedExpenseType = preselectedType ?? ExpenseType.bill;
          isVariable = false;
          isLoan = false;
          loanStartDate = null;
          loanEndDate = null;
        }

        showDialog<void>(
          context: dialogContext,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                Future<void> pickDate(
                  BuildContext pickerContext,
                  bool isStart,
                ) async {
                  try {
                    final pickedDate = await showDatePicker(
                      context: pickerContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      setDialogState(() {
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
                  } catch (error, stackTrace) {
                    _logError('pickDate', error, stackTrace);
                    _showSnackBar(
                      'Error picking date: $error',
                      backgroundColor: Colors.redAccent,
                    );
                  }
                }

                String? validateFields() {
                  if (isLoan) {
                    if (loanStartDate == null) {
                      return 'Contract start date is required.';
                    }
                    if (loanEndDate == null) {
                      return 'Contract end date is required.';
                    }
                    if (loanEndDate!.isBefore(loanStartDate!)) {
                      return 'Contract end date cannot be earlier than the start date.';
                    }
                  }
                  if (expenseNameController.text.isEmpty) {
                    return 'Expense name cannot be empty.';
                  }
                  if (expenseCostController.text.isEmpty ||
                      double.tryParse(expenseCostController.text) == null) {
                    return 'Invalid cost value.';
                  }
                  return null;
                }

                return AlertDialog(
                  title: Row(
                    children: [
                      id == null
                          ? const Row(
                              children: [
                                Icon(Icons.add),
                                Text('Add Expense'),
                              ],
                            )
                          : const Row(
                              children: [
                                Icon(Icons.edit),
                                Text('Edit Expense'),
                              ],
                            ),
                      const Spacer(),
                      if (id != null)
                        IconButton(
                          onPressed: () async {
                            final wasDeleted = await deleteExpense(id);
                            if (wasDeleted && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                    ],
                  ),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
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
                              prefixText: '£',
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: Expense.categories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedCategory = value ?? 'Other';
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          // Expense type selector
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 3.5,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              children: Expense.typeDisplayOrder.map((type) {
                                final isSelected = selectedExpenseType == type;
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedExpenseType = type;
                                      if (selectedExpenseType !=
                                          ExpenseType.debt) {
                                        isLoan = false;
                                        loanStartDate = null;
                                        loanEndDate = null;
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? type.color.withValues(alpha: 0.18)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? type.color
                                            : Colors.white
                                                .withValues(alpha: 0.15),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(type.icon,
                                            size: 16,
                                            color: isSelected
                                                ? type.color
                                                : Colors.white
                                                    .withValues(alpha: 0.5)),
                                        const SizedBox(width: 6),
                                        Text(
                                          type.label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? type.color
                                                : Colors.white
                                                    .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Variable toggle
                          SwitchListTile(
                            title: const Text('Variable Amount'),
                            subtitle: const Text(
                              'Amount changes monthly (e.g. credit card)',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: isVariable,
                            onChanged: (value) {
                              setDialogState(() {
                                isVariable = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (selectedExpenseType == ExpenseType.debt) ...[
                            CheckboxListTile(
                              title: const Text('Contract'),
                              value: isLoan,
                              onChanged: (value) {
                                setDialogState(() {
                                  isLoan = value ?? false;
                                  if (!isLoan) {
                                    loanStartDate = null;
                                    loanEndDate = null;
                                  }
                                });
                              },
                            ),
                            if (isLoan) ...[
                              ListTile(
                                title: const Text('Contract Start Date'),
                                subtitle: Text(
                                  loanStartDate != null
                                      ? '${loanStartDate!.toLocal()}'
                                          .split(' ')[0]
                                      : 'Pick a date',
                                ),
                                onTap: () => pickDate(context, true),
                              ),
                              ListTile(
                                title: const Text('Contract End Date'),
                                subtitle: Text(
                                  loanEndDate != null
                                      ? '${loanEndDate!.toLocal()}'
                                          .split(' ')[0]
                                      : 'Pick a date',
                                ),
                                onTap: () => pickDate(context, false),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () async {
                        final validationError = validateFields();
                        if (validationError != null) {
                          _showSnackBar(
                            validationError,
                            backgroundColor: Colors.redAccent,
                          );
                          return;
                        }

                        final wasSaved = id == null
                            ? await addExpense()
                            : await updateExpense(id);

                        if (!wasSaved || !context.mounted) return;

                        expenseNameController.clear();
                        expenseCostController.clear();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                );
              },
            );
          },
        );
      } catch (error, stackTrace) {
        _logError('showExpensePopup', error, stackTrace);
        _showSnackBar(
          'Error opening expense dialog: $error',
          backgroundColor: Colors.redAccent,
        );
      }
    }

    // Group expenses by type
    final variableNeedingUpdate =
        widget.expenses.where((e) => _needsMonthlyUpdate(e)).toList();

    final groupedExpenses = <ExpenseType, List<Map<String, dynamic>>>{};
    for (final type in Expense.typeDisplayOrder) {
      groupedExpenses[type] = widget.expenses
          .where((e) => ExpenseType.fromString(e['expenseType']) == type)
          .toList();
    }

    Widget buildResponsiveList(
      List<Map<String, dynamic>> items,
      Widget Function(Map<String, dynamic>) cardBuilder,
    ) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final useGrid = MediaQuery.of(context).size.width > 900;
          if (useGrid) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 72,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => cardBuilder(items[index]),
            );
          }
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) => cardBuilder(items[index]),
          );
        },
      );
    }

    Widget buildExpenseCard(Map<String, dynamic> expense) {
      final expType = ExpenseType.fromString(expense['expenseType']);
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: expType.color.withValues(alpha: 0.15),
            child: Icon(
              expType.icon,
              color: expType.color,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  expense['name'],
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (expense['isLoan'] == true)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: MediaQuery.of(context).size.width < 600
                      ? Tooltip(
                          message: 'Contract',
                          child: Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.7),
                          ),
                        )
                      : Text(
                          'Contract',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
              if (expense['isVariable'] == true)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.sync,
                    size: 16,
                    color: Colors.amber.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Text(
                '\u00A3${expense['cost']}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: expType.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  expense['category'] ?? 'Other',
                  style: TextStyle(
                    fontSize: 11,
                    color: expType.color,
                  ),
                ),
              ),
            ],
          ),
          trailing: _buildExpenseTrailing(
            context,
            expense['loanEndDate'],
            expense['loanStartDate'],
            expense['isLoan'] == true,
          ),
          onTap: () => showExpensePopup(context, expense['id']),
        ),
      );
    }

    Widget buildVariableUpdateCard(Map<String, dynamic> expense) {
      return Card(
        color: Colors.amber.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0x33FFC107),
            child: Icon(Icons.edit_note, color: Colors.amber),
          ),
          title: Text(expense['name']),
          subtitle: Text(
            'Last: \u00A3${expense['cost']}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          trailing: FilledButton.icon(
            onPressed: () => showExpensePopup(context, expense['id']),
            icon: const Icon(Icons.update, size: 16),
            label: const Text('Update'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              visualDensity: VisualDensity.compact,
            ),
          ),
          onTap: () => showExpensePopup(context, expense['id']),
        ),
      );
    }

    return Column(
      children: [
        // Main header
        ListTile(
          title: Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Expenses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
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
        if (isExpanded) ...[
          // Monthly Updates section (variable items needing attention)
          if (variableNeedingUpdate.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    'Monthly Updates (${variableNeedingUpdate.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
            buildResponsiveList(variableNeedingUpdate, buildVariableUpdateCard),
            const Divider(height: 16),
          ],
          // Grouped type sections
          for (final type in Expense.typeDisplayOrder)
            if (groupedExpenses[type]!.isNotEmpty) ...[
              _buildTypeHeader(
                type,
                groupedExpenses[type]!,
                () => showExpensePopup(context, null, preselectedType: type),
              ),
              if (_sectionExpanded[type] == true)
                buildResponsiveList(groupedExpenses[type]!, buildExpenseCard),
            ],
        ],
      ],
    );
  }

  Widget _buildTypeHeader(
    ExpenseType type,
    List<Map<String, dynamic>> items,
    VoidCallback onAdd,
  ) {
    final subtotal = items.fold<double>(0.0, (acc, item) {
      final rawCost = item['cost'];
      final cost = rawCost is num
          ? rawCost.toDouble()
          : double.tryParse(rawCost?.toString() ?? '') ?? 0.0;
      return acc + cost;
    });

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
      child: Row(
        children: [
          Icon(type.icon, size: 16, color: type.color),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: type.color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '(${items.length})',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const Spacer(),
          Text(
            '\u00A3${subtotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: type.color,
            ),
          ),
          IconButton(
            icon: Icon(
              _sectionExpanded[type] == true
                  ? Icons.expand_less
                  : Icons.expand_more,
              size: 20,
              color: Colors.grey,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                _sectionExpanded[type] = !(_sectionExpanded[type] ?? true);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _getExpiryColor(DateTime? endDate) {
    if (endDate == null) return Colors.black;
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Colors.red;
    if (daysLeft <= 60) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildExpenseTrailing(
    BuildContext context,
    String? loanEndDate,
    String? loanStartDate,
    bool isLoan,
  ) {
    if (!isLoan) return const SizedBox();

    final endDate = loanEndDate != null ? DateTime.tryParse(loanEndDate) : null;
    final startDate =
        loanStartDate != null ? DateTime.tryParse(loanStartDate) : null;
    final expiryColor = _getExpiryColor(endDate);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (isSmallScreen) {
      return IconButton(
        icon: Icon(Icons.calendar_month, color: expiryColor),
        tooltip: 'Contract dates',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.calendar_month, size: 20),
                  SizedBox(width: 8),
                  Text('Contract Dates', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    startDate != null
                        ? 'Start: ${_formatDate(startDate)}'
                        : 'Start: No date',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    endDate != null
                        ? 'End: ${_formatDate(endDate)}'
                        : 'End: No date',
                    style: TextStyle(
                      fontSize: 14,
                      color: expiryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Text(
          startDate != null ? 'Start: ${_formatDate(startDate)}' : 'No Date',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          endDate != null ? 'End: ${_formatDate(endDate)}' : 'No Date',
          style: TextStyle(
            color: expiryColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
