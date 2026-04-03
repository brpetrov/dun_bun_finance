class StatementTransaction {
  final String description;
  final double amount;
  final DateTime? date;

  StatementTransaction({
    required this.description,
    required this.amount,
    this.date,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
        'date': date?.toIso8601String(),
      };
}
