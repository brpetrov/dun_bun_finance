import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:flutter/material.dart';

class PotsSection extends StatefulWidget {
  final List<Map<String, dynamic>> pots;
  final Future<void> Function() onPotUpdated;
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
  bool isExpanded = true;

  void _logError(String source, Object error, StackTrace stackTrace) {
    debugPrint('[PotsSection][$source] $error');
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

  void showPotPopup(BuildContext dialogContext, String? id) {
    try {
      final TextEditingController potNameController = TextEditingController();
      final TextEditingController potPercentageController =
          TextEditingController();

      if (id != null) {
        final pot = widget.pots.firstWhere((element) => element['id'] == id);
        potNameController.text = pot['name'];
        potPercentageController.text = pot['percentage'].toString();
      }

      showDialog<void>(
        context: dialogContext,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                id == null ? const Text('Add Pot') : const Text('Edit Pot'),
                const Spacer(),
                if (id != null)
                  IconButton(
                    onPressed: () async {
                      final wasDeleted = await deletePot(id);
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
                    _showSnackBar(
                      'Please fill out all fields',
                      backgroundColor: Colors.redAccent,
                    );
                    return;
                  }

                  final percentage = int.tryParse(percentageText);
                  if (percentage == null || percentage < 0 || percentage > 100) {
                    _showSnackBar(
                      'Percentage must be between 0 and 100',
                      backgroundColor: Colors.redAccent,
                    );
                    return;
                  }

                  final wasSaved = id == null
                      ? await addPot(name, percentage)
                      : await updatePot(id, name, percentage);

                  if (wasSaved && context.mounted) {
                    Navigator.of(context).pop();
                  }
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
    } catch (error, stackTrace) {
      _logError('showPotPopup', error, stackTrace);
      _showSnackBar(
        'Error opening pot dialog: $error',
        backgroundColor: Colors.redAccent,
      );
    }
  }

  Future<bool> addPot(String name, int percentage) async {
    try {
      await FirestoreService.createPot(name, percentage);
      await widget.onPotUpdated();
      return true;
    } catch (error, stackTrace) {
      _logError('addPot', error, stackTrace);
      _showSnackBar(
        'Error adding pot: $error',
        backgroundColor: Colors.redAccent,
      );
      return false;
    }
  }

  Future<bool> updatePot(String id, String name, int percentage) async {
    try {
      await FirestoreService.updatePot(id, {
        'name': name,
        'percentage': percentage,
      });
      await widget.onPotUpdated();
      return true;
    } catch (error, stackTrace) {
      _logError('updatePot', error, stackTrace);
      _showSnackBar(
        'Error updating pot: $error',
        backgroundColor: Colors.redAccent,
      );
      return false;
    }
  }

  Future<bool> deletePot(String id) async {
    try {
      await FirestoreService.deletePot(id);
      await widget.onPotUpdated();
      _showSnackBar(
        'Pot deleted',
        backgroundColor: Colors.redAccent,
      );
      return true;
    } catch (error, stackTrace) {
      _logError('deletePot', error, stackTrace);
      _showSnackBar(
        'Error deleting pot: $error',
        backgroundColor: Colors.redAccent,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text(
            'Pots',
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
                subtitle: Text('$percentage%'),
                trailing: Text(
                  '\u00A3${potValue.toStringAsFixed(2)}',
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
