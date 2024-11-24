class Expense {
  int id = 0;
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

  Expense.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'];
    cost = map['cost'];
    createdAt = DateTime.parse(map['created_at']);
    isLoan = map['isLoan'] == 1;
    loanStartDate = map['loanStartDate'] != null
        ? DateTime.parse(map['loanStartDate'])
        : null;
    loanEndDate =
        map['loanEndDate'] != null ? DateTime.parse(map['loanEndDate']) : null;
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cost': cost,
      'created_at': createdAt.toString(),
      'isLoan': isLoan ? 1 : 0,
      'loanStartDate': loanStartDate.toString(),
      'loanEndDate': loanEndDate.toString(),
    };
  }
}
