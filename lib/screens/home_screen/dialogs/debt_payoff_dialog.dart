import 'package:flutter/material.dart';

class _DebtEntry {
  final String id;
  final String name;
  double balance;
  final double monthlyRate; // annual% / 1200
  final double minPayment;

  _DebtEntry({
    required this.id,
    required this.name,
    required this.balance,
    required this.monthlyRate,
    required this.minPayment,
  });

  _DebtEntry copyWith({double? balance}) => _DebtEntry(
        id: id,
        name: name,
        balance: balance ?? this.balance,
        monthlyRate: monthlyRate,
        minPayment: minPayment,
      );
}

class _PayoffPlan {
  final List<String> payoffOrder;
  final int months;
  final double totalInterest;

  const _PayoffPlan({
    required this.payoffOrder,
    required this.months,
    required this.totalInterest,
  });
}

class DebtPayoffDialog extends StatefulWidget {
  final List<Map<String, dynamic>> debts;

  const DebtPayoffDialog({super.key, required this.debts});

  @override
  State<DebtPayoffDialog> createState() => _DebtPayoffDialogState();
}

class _DebtPayoffDialogState extends State<DebtPayoffDialog>
    with SingleTickerProviderStateMixin {
  final _budgetController = TextEditingController();
  _PayoffPlan? _avalanche;
  _PayoffPlan? _snowball;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<_DebtEntry> _buildEntries() {
    return widget.debts.map((e) {
      final rawCost = e['cost'];
      final cost = rawCost is num ? rawCost.toDouble() : 0.0;
      final rawRate = e['interestRate'];
      final annualRate = rawRate != null ? (rawRate as num).toDouble() : 0.0;
      return _DebtEntry(
        id: e['id'] as String,
        name: e['name'] as String,
        balance: cost,
        monthlyRate: annualRate / 1200,
        minPayment: cost * 0.02, // 2% of balance as floor min payment
      );
    }).toList();
  }

  _PayoffPlan _simulate(
    List<_DebtEntry> entries,
    double budget, {
    required bool avalanche,
  }) {
    // deep-copy balances
    var debts = entries.map((e) => e.copyWith()).toList();
    double totalInterest = 0;
    int months = 0;
    final payoffOrder = <String>[];
    const maxMonths = 600; // 50 year cap to prevent infinite loops

    while (debts.any((d) => d.balance > 0.001) && months < maxMonths) {
      months++;
      double remaining = budget;

      // Apply interest and minimum payments
      for (final d in debts) {
        if (d.balance <= 0) continue;
        final interest = d.balance * d.monthlyRate;
        totalInterest += interest;
        d.balance += interest;
        final payment = d.minPayment.clamp(0, d.balance);
        d.balance -= payment;
        remaining -= payment;
        if (remaining < 0) remaining = 0;
      }

      // Apply extra budget to target debt
      if (remaining > 0) {
        final active = debts.where((d) => d.balance > 0.001).toList();
        if (active.isNotEmpty) {
          active.sort((a, b) => avalanche
              ? b.monthlyRate.compareTo(a.monthlyRate) // highest rate first
              : a.balance.compareTo(b.balance)); // lowest balance first
          final target = active.first;
          final extra = remaining.clamp(0, target.balance);
          target.balance -= extra;
        }
      }

      // Collect any newly paid-off debts this month
      for (final d in debts) {
        if (d.balance <= 0.001 && !payoffOrder.contains(d.name)) {
          payoffOrder.add(d.name);
          d.balance = 0;
        }
      }
    }

    return _PayoffPlan(
      payoffOrder: payoffOrder,
      months: months >= maxMonths ? -1 : months,
      totalInterest: totalInterest,
    );
  }

  void _calculate() {
    final budget = double.tryParse(_budgetController.text.trim());
    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid monthly budget'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final entries = _buildEntries();
    final totalMin = entries.fold(0.0, (s, e) => s + e.minPayment);
    if (budget < totalMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Budget must cover minimum payments (£${totalMin.toStringAsFixed(2)})'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _avalanche = _simulate(entries, budget, avalanche: true);
      _snowball = _simulate(entries, budget, avalanche: false);
    });
  }

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 20, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('How it Works'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _InfoPoint(
                  icon: Icons.local_fire_department,
                  color: Colors.redAccent,
                  title: 'Avalanche — save the most money',
                  body:
                      'Puts every spare pound at the debt with the highest interest rate first. You pay less overall because high-rate debt costs more the longer it sits.',
                ),
                SizedBox(height: 12),
                _InfoPoint(
                  icon: Icons.snowboarding,
                  color: Colors.blueAccent,
                  title: 'Snowball — stay motivated',
                  body:
                      'Targets the smallest balance first regardless of rate. Paying off a debt completely gives a psychological win that helps you keep going.',
                ),
                SizedBox(height: 12),
                _InfoPoint(
                  icon: Icons.calculate_outlined,
                  color: Colors.orangeAccent,
                  title: 'How the maths works',
                  body:
                      'Each month interest is applied to every balance, minimum payments are made across all debts, then any leftover budget is thrown at the target debt until it hits zero.',
                ),
                SizedBox(height: 12),
                _InfoPoint(
                  icon: Icons.tips_and_updates_outlined,
                  color: Colors.greenAccent,
                  title: 'Getting the best results',
                  body:
                      'Add an interest rate to each debt for accurate comparisons. The higher your monthly budget above the minimums, the faster both methods finish — and the gap between them shrinks.',
                ),
                SizedBox(height: 16),
                Text(
                  'Tip: try both tabs side by side to see exactly how much interest each method costs you.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _formatMonths(int months) {
    if (months < 0) return 'Over 50 years';
    if (months < 12) return '$months months';
    final y = months ~/ 12;
    final m = months % 12;
    return m == 0 ? '$y yr' : '$y yr $m mo';
  }

  Widget _buildPlanView(_PayoffPlan plan, _PayoffPlan other, Color accent) {
    final saves = other.totalInterest - plan.totalInterest;
    final faster = other.months - plan.months;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Debt-free in',
                  value: _formatMonths(plan.months),
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Total interest',
                  value: '£${plan.totalInterest.toStringAsFixed(2)}',
                  color: accent,
                ),
              ),
            ],
          ),
          if (saves > 0.5 || faster > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined,
                      color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (saves > 0.5)
                          'Saves £${saves.toStringAsFixed(2)} vs other method',
                        if (faster > 0) '$faster months faster',
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Payoff order',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...plan.payoffOrder.asMap().entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Text(
                    '${entry.key + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accent),
                  ),
                ),
                title: Text(entry.value),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRates =
        widget.debts.any((e) => (e['interestRate'] as num?) != null);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Debt Payoff Optimizer'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                tooltip: 'How does this work?',
                onPressed: () => _showInfoDialog(context),
              ),
            ],
            bottom: _avalanche != null
                ? TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.trending_down, size: 16),
                          text: 'Avalanche'),
                      Tab(
                          icon: Icon(Icons.snowboarding, size: 16),
                          text: 'Snowball'),
                    ],
                  )
                : null,
          ),
          body: Column(
            children: [
              if (!hasRates)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.amber.withValues(alpha: 0.08),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No interest rates set — add rates in each debt to see accurate savings.',
                          style: TextStyle(fontSize: 12, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _budgetController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Monthly debt budget',
                          border: OutlineInputBorder(),
                          prefixText: '£',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _calculate(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _calculate,
                      child: const Text('Calculate'),
                    ),
                  ],
                ),
              ),
              if (_avalanche == null)
                Expanded(
                  child: widget.debts.isEmpty
                      ? const Center(child: Text('No debt expenses found'))
                      : const Center(
                          child: Text(
                            'Enter your monthly budget above\nto see your payoff plan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                )
              else
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPlanView(_avalanche!, _snowball!, Colors.redAccent),
                      _buildPlanView(
                          _snowball!, _avalanche!, Colors.blueAccent),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPoint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoPoint({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
