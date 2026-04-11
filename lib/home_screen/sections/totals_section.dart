import 'package:dun_bun_finance/models/expense.dart';
import 'package:flutter/material.dart';

class TotalSection extends StatelessWidget {
  final double totalExpenses;
  final double incomeAfterExpenses;
  final Map<String, double> subtotalsByType;
  final double subscriptionsTotal;

  const TotalSection({
    super.key,
    required this.totalExpenses,
    required this.incomeAfterExpenses,
    this.subtotalsByType = const {},
    this.subscriptionsTotal = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          // Main totals row
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Ammount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u00A3${totalExpenses.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'After Expenses',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u00A3${incomeAfterExpenses.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: incomeAfterExpenses > 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
            if (subscriptionsTotal > 0) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.subscriptions_outlined,
                        size: 16, color: Colors.purpleAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Subscriptions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '\u00A3${subscriptionsTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.purpleAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Per-type subtotals
          if (subtotalsByType.isNotEmpty) ...[
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final useGrid = constraints.maxWidth >= 500;
                final visibleTypes = Expense.typeDisplayOrder
                    .where((t) => (subtotalsByType[t.name] ?? 0.0) > 0.0)
                    .toList();

                Widget buildTypeCard(ExpenseType type) {
                  final amount = subtotalsByType[type.name] ?? 0.0;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(type.icon, size: 16, color: type.color),
                          const SizedBox(width: 6),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\u00A3${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: type.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (useGrid) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 52,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: visibleTypes.length,
                    itemBuilder: (_, i) => buildTypeCard(visibleTypes[i]),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleTypes.length,
                  itemBuilder: (_, i) => buildTypeCard(visibleTypes[i]),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
