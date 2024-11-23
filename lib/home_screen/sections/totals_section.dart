import 'package:flutter/material.dart';

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
