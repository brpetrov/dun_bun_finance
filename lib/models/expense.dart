class Expense {
  String id = '';
  String name = "";
  double cost = 0.0;
  String category = 'Other';
  DateTime? createdAt;
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

  Expense({
    required this.id,
    required this.name,
    required this.cost,
    this.category = 'Other',
    this.createdAt,
    required this.isLoan,
    this.loanStartDate,
    this.loanEndDate,
  });
}
