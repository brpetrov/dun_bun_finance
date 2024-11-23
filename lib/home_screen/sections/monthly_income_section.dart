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
