import 'package:dun_bun_finance/models/expense.dart';
import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SpendingHistoryScreen extends StatefulWidget {
  const SpendingHistoryScreen({super.key});

  @override
  State<SpendingHistoryScreen> createState() => _SpendingHistoryScreenState();
}

class _SpendingHistoryScreenState extends State<SpendingHistoryScreen> {
  List<Map<String, dynamic>> _snapshots = [];
  bool _isLoading = true;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await FirestoreService.getMonthlySnapshots();
      if (mounted) {
        setState(() {
          _snapshots = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _monthLabel(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    const abbr = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    final y = parts[0].substring(2);
    return "${abbr[m]}\n'$y";
  }

  double _subtotal(Map<String, dynamic> snap, String type) {
    final sub = snap['subtotalsByType'];
    if (sub is Map) {
      final v = sub[type];
      return v is num ? v.toDouble() : 0.0;
    }
    return 0.0;
  }

  double _income(Map<String, dynamic> snap) {
    final v = snap['income'];
    return v is num ? v.toDouble() : 0.0;
  }

  double _total(Map<String, dynamic> snap) {
    final v = snap['totalExpenses'];
    return v is num ? v.toDouble() : 0.0;
  }

  BarChartGroupData _barGroup(int index, Map<String, dynamic> snap) {
    final debt = _subtotal(snap, 'debt');
    final bill = _subtotal(snap, 'bill');
    final savings = _subtotal(snap, 'savings');
    final budget = _subtotal(snap, 'budget');
    final total = debt + bill + savings + budget;
    final isTouched = index == _touchedIndex;

    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: total,
          width: isTouched ? 20 : 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          rodStackItems: [
            BarChartRodStackItem(0, debt, Colors.redAccent),
            BarChartRodStackItem(debt, debt + bill, Colors.orangeAccent),
            BarChartRodStackItem(
                debt + bill, debt + bill + savings, Colors.greenAccent),
            BarChartRodStackItem(
                debt + bill + savings, total, Colors.blueAccent),
          ],
        ),
      ],
    );
  }

  double get _maxY {
    double max = 0;
    for (final s in _snapshots) {
      final t = _total(s);
      final inc = _income(s);
      if (t > max) max = t;
      if (inc > max) max = inc;
    }
    return (max * 1.2).ceilToDouble();
  }

  Widget _buildChart(Color labelColor, Color gridColor) {
    final visible = _snapshots.length > 12
        ? _snapshots.sublist(_snapshots.length - 12)
        : _snapshots;

    return BarChart(
      BarChartData(
        maxY: _maxY,
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.spot == null) {
              setState(() => _touchedIndex = null);
              return;
            }
            setState(
                () => _touchedIndex = response.spot!.touchedBarGroupIndex);
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black.withValues(alpha: 0.85),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final snap = visible[group.x];
              final label = _monthLabel(snap['month'] as String);
              final total = _total(snap);
              final income = _income(snap);
              return BarTooltipItem(
                '${label.replaceAll('\n', ' ')}\n',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
                children: [
                  TextSpan(
                    text: 'Expenses: £${total.toStringAsFixed(2)}',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                  if (income > 0)
                    TextSpan(
                      text: '\nIncome: £${income.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 11),
                    ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Text(
                  '£${value.toInt()}',
                  style: TextStyle(fontSize: 10, color: labelColor),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= visible.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _monthLabel(visible[i]['month'] as String),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: labelColor),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups:
            List.generate(visible.length, (i) => _barGroup(i, visible[i])),
        extraLinesData: ExtraLinesData(
          horizontalLines: () {
            final incomes =
                visible.map(_income).where((v) => v > 0).toList();
            if (incomes.isEmpty) return <HorizontalLine>[];
            final avgIncome =
                incomes.reduce((a, b) => a + b) / incomes.length;
            return [
              HorizontalLine(
                y: avgIncome,
                color: Colors.greenAccent.withValues(alpha: 0.4),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) =>
                      'avg income £${avgIncome.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 9, color: Colors.greenAccent),
                ),
              ),
            ];
          }(),
        ),
      ),
    );
  }

  Widget _buildLegend(Color labelColor) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: Expense.typeDisplayOrder.map((t) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: t.color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Text(t.label,
                style: TextStyle(fontSize: 11, color: labelColor)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMonthCard(Map<String, dynamic> snap, Color subtitleColor) {
    final month = snap['month'] as String;
    final total = _total(snap);
    final income = _income(snap);
    final remaining = income > 0 ? income - total : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Text(
              _monthLabel(month).replaceAll('\n', ' '),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            Text(
              '£${total.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
        subtitle: income > 0
            ? Text(
                'Income £${income.toStringAsFixed(2)} · Left £${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 11,
                    color: remaining >= 0
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.redAccent.withValues(alpha: 0.8)),
              )
            : null,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: Expense.typeDisplayOrder.map((t) {
                final amount = _subtotal(snap, t.name);
                if (amount <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(t.icon, size: 14, color: t.color),
                      const SizedBox(width: 8),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 12, color: subtitleColor)),
                      const Spacer(),
                      Text(
                        '£${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: t.color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final labelColor = onSurface.withValues(alpha: 0.5);
    final gridColor = onSurface.withValues(alpha: 0.07);
    final subtitleColor = onSurface.withValues(alpha: 0.7);
    final emptyColor = onSurface.withValues(alpha: 0.3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending History'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _snapshots.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart,
                            size: 64,
                            color: onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No history yet',
                          style:
                              TextStyle(fontSize: 16, color: emptyColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A snapshot is saved each time you refresh\nthe home screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.25)),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding:
                                    EdgeInsets.only(left: 8, bottom: 12),
                                child: Text(
                                  'Monthly Expenses',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                              SizedBox(
                                height: 220,
                                child: _buildChart(labelColor, gridColor),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _buildLegend(labelColor),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Month Breakdown',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: labelColor),
                      ),
                      const SizedBox(height: 8),
                      ..._snapshots.reversed
                          .map((s) => _buildMonthCard(s, subtitleColor)),
                    ],
                  ),
      ),
    );
  }
}
