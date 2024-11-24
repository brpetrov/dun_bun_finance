import 'package:dun_bun_finance/db_helper.dart';
import 'package:dun_bun_finance/models/pot.dart';
import 'package:flutter/material.dart';

class PotsSection extends StatefulWidget {
  final List<Map<String, dynamic>> pots;
  final VoidCallback onPotUpdated;
  final double incomeAfterExpenses;

  const PotsSection({
    super.key,
    required this.pots,
    required this.onPotUpdated,
    required this.incomeAfterExpenses,
  });

  @override
  State<PotsSection> createState() => _PotsSectionState();
}

class _PotsSectionState extends State<PotsSection> {
  bool isExpanded = true; // State to manage expand/collapse

  void showPotPopup(BuildContext context, int? id) {
    final TextEditingController potNameController = TextEditingController();
    final TextEditingController potPercentageController =
        TextEditingController();

    if (id != null) {
      final pot = widget.pots.firstWhere((element) => element['id'] == id);
      potNameController.text = pot['name'];
      potPercentageController.text = pot['percentage'].toString();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              id == null ? const Text('Add Pot') : const Text('Edit Pot'),
              const Spacer(),
              if (id != null)
                IconButton(
                  onPressed: () {
                    deletePot(id);
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
                  controller: potNameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: potPercentageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Percentage',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final name = potNameController.text.trim();
                final percentageText = potPercentageController.text.trim();

                if (name.isEmpty || percentageText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill out all fields'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final percentage = int.tryParse(percentageText);
                if (percentage == null || percentage < 0 || percentage > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Percentage must be between 0 and 100'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                if (id == null) {
                  await addPot(name, percentage);
                } else {
                  await updatePot(Pot(
                    id: id,
                    name: name,
                    percentage: percentage,
                    createdAt: DateTime.now(),
                  ));
                }

                Navigator.of(context).pop();
              },
              child: Text(id == null ? 'Add' : 'Update'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> addPot(String name, int percentage) async {
    try {
      await SQLHelper.createPot(name, percentage);
      widget.onPotUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error adding pot: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> updatePot(Pot pot) async {
    try {
      await SQLHelper.updatePot(pot);
      widget.onPotUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating pot: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> deletePot(int id) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pot Deleted"),
          backgroundColor: Colors.redAccent,
        ),
      );
      await SQLHelper.deletePot(id);
      widget.onPotUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error deleting pot: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text(
            "Pots",
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
                onPressed: () => showPotPopup(context, null),
              ),
            ],
          ),
        ),
        if (isExpanded)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.pots.length,
            itemBuilder: (context, index) {
              final pot = widget.pots[index];
              final percentage = pot['percentage'] as int;
              final potValue = widget.incomeAfterExpenses * (percentage / 100);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.savings)),
                title: Text(pot['name']),
                subtitle: Text("$percentage%"),
                trailing: Text(
                  '£${potValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 17,
                  ),
                ),
                onTap: () => showPotPopup(context, pot['id']),
              );
            },
          ),
      ],
    );
  }
}
