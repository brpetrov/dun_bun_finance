import 'package:flutter/material.dart';

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
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Monthly Income',
              prefixIcon: Icon(
                Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              prefixText: '\u00A3 ',
              prefixStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onSubmitted: (value) => onSubmit(),
          ),
        ),
      ),
    );
  }
}
