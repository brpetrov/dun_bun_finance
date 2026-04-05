import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DataExportDialog extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> pots;

  const DataExportDialog({
    super.key,
    required this.expenses,
    required this.pots,
  });

  Map<String, dynamic> _buildPayload() {
    return {
      'expenses': expenses.map(_normalizeMap).toList(),
      'pots': pots.map(_normalizeMap).toList(),
    };
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> source) {
    final normalized = <String, dynamic>{};
    for (final entry in source.entries) {
      normalized[entry.key] = _normalizeValue(entry.value);
    }
    return normalized;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is List) {
      return value.map(_normalizeValue).toList();
    }

    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _normalizeValue(nestedValue),
        ),
      );
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final exportContent =
        const JsonEncoder.withIndent('  ').convert(_buildPayload());

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Current Data Export'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_all_outlined),
                tooltip: 'Copy JSON',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: exportContent),
                  );

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied current expenses and pots'),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  exportContent,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
