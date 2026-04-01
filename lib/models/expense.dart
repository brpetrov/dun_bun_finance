class Expense {
  String id = '';
  String name = "";
  double cost = 0.0;
  DateTime? createdAt;
  bool isLoan = false;
  DateTime? loanStartDate;
  DateTime? loanEndDate;

  Expense({
    required this.id,
    required this.name,
    required this.cost,
    this.createdAt,
    required this.isLoan,
    this.loanStartDate,
    this.loanEndDate,
  });
}
