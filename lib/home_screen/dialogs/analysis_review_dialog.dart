import 'package:dun_bun_finance/models/analysis_suggestion.dart';
import 'package:flutter/material.dart';

class AnalysisReviewDialog extends StatefulWidget {
  final List<AnalysisSuggestion> suggestions;
  final String summary;

  const AnalysisReviewDialog({
    super.key,
    required this.suggestions,
    required this.summary,
  });

  @override
  State<AnalysisReviewDialog> createState() => _AnalysisReviewDialogState();
}

class _AnalysisReviewDialogState extends State<AnalysisReviewDialog> {
  @override
  Widget build(BuildContext context) {
    final missing = widget.suggestions
        .where((s) => s.type == SuggestionType.missing)
        .toList();
    final mismatches = widget.suggestions
        .where((s) => s.type == SuggestionType.mismatch)
        .toList();
    final phantom = widget.suggestions
        .where((s) => s.type == SuggestionType.phantom)
        .toList();
    final insights = widget.suggestions
        .where((s) => s.type == SuggestionType.insight)
        .toList();

    final actionable = widget.suggestions
        .where((s) => s.type != SuggestionType.insight);
    final selectedCount = actionable.where((s) => s.accepted).length;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Analysis Results'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.minimize),
                tooltip: 'Minimize — review your expenses first',
                onPressed: () => Navigator.of(context).pop('minimize'),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    widget.summary,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),

                if (missing.isNotEmpty)
                  _buildSection(
                    'Missing Expenses',
                    'In bank statement but not tracked in app',
                    Colors.green,
                    Icons.add_circle_outline,
                    missing,
                  ),

                if (mismatches.isNotEmpty)
                  _buildSection(
                    'Amount Mismatches',
                    'Tracked but amount differs from bank',
                    Colors.orange,
                    Icons.swap_horiz,
                    mismatches,
                  ),

                if (phantom.isNotEmpty)
                  _buildSection(
                    'Phantom Expenses',
                    'Tracked but not found in bank statement',
                    Colors.red,
                    Icons.remove_circle_outline,
                    phantom,
                  ),

                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lightbulb_outline,
                            size: 18, color: Colors.amber),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Insights',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...insights.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.arrow_right,
                                    size: 18,
                                    color:
                                        Colors.white.withValues(alpha: 0.4)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(s.description,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white
                                              .withValues(alpha: 0.7))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                ],

                if (widget.suggestions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No discrepancies found. Your expenses match your bank statement.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: actionable.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: selectedCount > 0
                        ? () => Navigator.of(context).pop(widget.suggestions)
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text('Apply $selectedCount Selected Changes'),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    String subtitle,
    Color color,
    IconData icon,
    List<AnalysisSuggestion> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title (${items.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  child: CheckboxListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    value: s.accepted,
                    onChanged: (val) =>
                        setState(() => s.accepted = val ?? false),
                    title: Text(
                      s.suggestedName ?? s.description,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.description,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.5))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (s.suggestedCost != null)
                                Text('£${s.suggestedCost!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                              if (s.suggestedCategory != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(s.suggestedCategory!,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                                ),
                              ],
                              const Spacer(),
                              _confidenceBadge(s.confidence),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _confidenceBadge(String confidence) {
    final Color color;
    switch (confidence) {
      case 'high':
        color = Colors.greenAccent;
      case 'medium':
        color = Colors.orangeAccent;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(confidence,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
