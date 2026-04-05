import 'package:flutter/material.dart';

enum ExpenseType {
  debt,
  bill,
  savings,
  budget;

  String get label {
    switch (this) {
      case ExpenseType.debt:
        return 'Debt';
      case ExpenseType.bill:
        return 'Bills';
      case ExpenseType.savings:
        return 'Savings';
      case ExpenseType.budget:
        return 'Budget';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseType.debt:
        return Icons.credit_card;
      case ExpenseType.bill:
        return Icons.receipt_long;
      case ExpenseType.savings:
        return Icons.savings;
      case ExpenseType.budget:
        return Icons.shopping_cart;
    }
  }

  Color get color {
    switch (this) {
      case ExpenseType.debt:
        return Colors.redAccent;
      case ExpenseType.bill:
        return Colors.orangeAccent;
      case ExpenseType.savings:
        return Colors.greenAccent;
      case ExpenseType.budget:
        return Colors.blueAccent;
    }
  }

  static ExpenseType fromString(String? value) {
    switch (value) {
      case 'debt':
        return ExpenseType.debt;
      case 'bill':
        return ExpenseType.bill;
      case 'savings':
        return ExpenseType.savings;
      case 'budget':
        return ExpenseType.budget;
      default:
        return ExpenseType.bill;
    }
  }
}

class Expense {
  String id = '';
  String name = "";
  double cost = 0.0;
  String category = 'Other';
  ExpenseType expenseType = ExpenseType.bill;
  bool isVariable = false;
  DateTime? createdAt;
  DateTime? updatedAt;
  bool isLoan = false;
  DateTime? loanStartDate;
  DateTime? loanEndDate;

  static const List<String> categories = [
    'Subscription',
    'Utilities',
    'Insurance',
    'Contract',
    'Rent/Mortgage',
    'Transport',
    'Food & Groceries',
    'Entertainment',
    'Health & Fitness',
    'Other',
  ];

  /// Display order for expense type sections.
  static const List<ExpenseType> typeDisplayOrder = [
    ExpenseType.debt,
    ExpenseType.bill,
    ExpenseType.savings,
    ExpenseType.budget,
  ];

  Expense({
    required this.id,
    required this.name,
    required this.cost,
    this.category = 'Other',
    this.expenseType = ExpenseType.bill,
    this.isVariable = false,
    this.createdAt,
    this.updatedAt,
    required this.isLoan,
    this.loanStartDate,
    this.loanEndDate,
  });
}
