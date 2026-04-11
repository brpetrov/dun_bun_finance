import 'package:dun_bun_finance/models/maintenance_item.dart';
import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:flutter/material.dart';

class MaintenanceSetupScreen extends StatefulWidget {
  /// If true, navigates to the dashboard after saving.
  /// If false (adding more from dashboard), just pops back.
  final bool isInitialSetup;

  const MaintenanceSetupScreen({super.key, this.isInitialSetup = true});

  @override
  State<MaintenanceSetupScreen> createState() => _MaintenanceSetupScreenState();
}

class _MaintenanceSetupScreenState extends State<MaintenanceSetupScreen> {
  final _selected = <String>{};
  final _dueDates = <String, DateTime>{};
  MaintenanceCategory? _expandedCategory;
  bool _saving = false;

  Map<MaintenanceCategory, List<MaintenancePreset>> get _grouped {
    final map = <MaintenanceCategory, List<MaintenancePreset>>{};
    for (final preset in MaintenancePresets.all) {
      map.putIfAbsent(preset.category, () => []).add(preset);
    }
    return map;
  }

  Future<void> _pickDueDate(String presetName) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDates[presetName] ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
      helpText: 'When is this next due?',
    );
    if (picked != null) {
      setState(() => _dueDates[presetName] = picked);
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one item'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final presets = MaintenancePresets.all
          .where((p) => _selected.contains(p.name))
          .toList();

      final items = presets.map((p) {
        final dueDate = _dueDates[p.name];
        return {
          'name': p.name,
          'category': p.category.name,
          'description': p.description,
          'frequencyMonths': p.frequencyMonths,
          'nextDueDate': dueDate?.toIso8601String(),
        };
      }).toList();

      await FirestoreService.createMaintenanceItems(items);

      if (mounted) {
        if (widget.isInitialSetup) {
          Navigator.of(context).pushReplacementNamed('/maintenance');
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleCategory(MaintenanceCategory cat, List<MaintenancePreset> items) {
    setState(() {
      final allSelected = items.every((p) => _selected.contains(p.name));
      if (allSelected) {
        for (final p in items) {
          _selected.remove(p.name);
        }
      } else {
        for (final p in items) {
          _selected.add(p.name);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup
            ? 'Set Up Maintenance Reminders'
            : 'Add More Reminders'),
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What do you need to keep track of?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the items relevant to you. You can set due dates now or later.',
                  style: TextStyle(
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: MaintenanceCategory.values.map((cat) {
                final items = grouped[cat];
                if (items == null || items.isEmpty) {
                  return const SizedBox.shrink();
                }
                final isExpanded = _expandedCategory == cat;
                final selectedInCat =
                    items.where((p) => _selected.contains(p.name)).length;

                return Column(
                  children: [
                    // Category header
                    InkWell(
                      onTap: () => setState(() =>
                          _expandedCategory = isExpanded ? null : cat),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child:
                                  Icon(cat.icon, color: cat.color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: onSurface,
                                    ),
                                  ),
                                  Text(
                                    '$selectedInCat / ${items.length} selected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Select all button
                            TextButton(
                              onPressed: () =>
                                  _toggleCategory(cat, items),
                              child: Text(
                                selectedInCat == items.length
                                    ? 'Deselect All'
                                    : 'Select All',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: onSurface.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Items
                    if (isExpanded)
                      ...items.map((preset) => _buildPresetTile(preset)),
                    Divider(
                      height: 1,
                      color: onSurface.withValues(alpha: 0.08),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: _saving
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: Text(
                    widget.isInitialSetup
                        ? 'Save ${_selected.length} Items & Continue'
                        : 'Add ${_selected.length} Items',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPresetTile(MaintenancePreset preset) {
    final isSelected = _selected.contains(preset.name);
    final dueDate = _dueDates[preset.name];
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          if (isSelected) {
            _selected.remove(preset.name);
          } else {
            _selected.add(preset.name);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) => setState(() {
                      if (val == true) {
                        _selected.add(preset.name);
                      } else {
                        _selected.remove(preset.name);
                      }
                    }),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: preset.category.color
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            preset.frequencyLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: preset.category.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Text(
                  preset.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 6),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        size: 13,
                        color: Colors.amber.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        preset.recommendedMonth,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDueDate(preset.name),
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      dueDate != null
                          ? 'Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}'
                          : 'Set Due Date (optional)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
