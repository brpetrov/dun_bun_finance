import 'package:dun_bun_finance/screens/hub_screen/hub_item.dart';
import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:flutter/material.dart';

class _CustomEntry {
  final HubCategory category;
  final String name;
  final String description;
  final int frequencyMonths;
  final DateTime? dueDate;

  _CustomEntry({
    required this.category,
    required this.name,
    this.description = '',
    required this.frequencyMonths,
    this.dueDate,
  });
}

class LifeHubSetupScreen extends StatefulWidget {
  final bool isInitialSetup;

  const LifeHubSetupScreen({super.key, this.isInitialSetup = true});

  @override
  State<LifeHubSetupScreen> createState() => _LifeHubSetupScreenState();
}

class _LifeHubSetupScreenState extends State<LifeHubSetupScreen> {
  final _selected = <String>{};
  final _dueDates = <String, DateTime>{};
  final List<_CustomEntry> _customEntries = [];
  HubCategory? _expandedCategory;
  bool _saving = false;

  static const _frequencyOptions = [1, 3, 6, 12, 18, 24, 60, 120];

  String _frequencyLabel(int months) {
    if (months == 1) return 'Monthly';
    if (months == 3) return 'Quarterly';
    if (months == 6) return 'Every 6 months';
    if (months == 12) return 'Annually';
    if (months == 18) return 'Every 18 months';
    if (months == 24) return 'Every 2 years';
    if (months == 120) return 'Every 10 years';
    return 'Every $months months';
  }

  Map<HubCategory, List<HubPreset>> get _grouped {
    final map = <HubCategory, List<HubPreset>>{};
    for (final preset in HubPresets.all) {
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

  Future<void> _addCustomItem(HubCategory cat) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int freq = 12;
    DateTime? dueDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Custom ${cat.label} Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: freq,
                  decoration: const InputDecoration(
                    labelText: 'How often?',
                    border: OutlineInputBorder(),
                  ),
                  items: _frequencyOptions
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(_frequencyLabel(m)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => freq = val);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 15),
                      helpText: 'When is this next due?',
                    );
                    if (picked != null) {
                      setDialogState(() => dueDate = picked);
                    }
                  },
                  icon: Icon(Icons.calendar_today, size: 16, color: cat.color),
                  label: Text(
                    dueDate != null
                        ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                        : 'Set due date (optional)',
                    style: TextStyle(color: cat.color),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    side: BorderSide(color: cat.color.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final desc = descCtrl.text.trim();
    nameCtrl.dispose();
    descCtrl.dispose();

    if (confirmed == true && name.isNotEmpty) {
      setState(() {
        _customEntries.add(_CustomEntry(
          category: cat,
          name: name,
          description: desc,
          frequencyMonths: freq,
          dueDate: dueDate,
        ));
      });
    }
  }

  Future<void> _save() async {
    final totalCount = _selected.length + _customEntries.length;
    if (totalCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select or add at least one item'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final presets =
          HubPresets.all.where((p) => _selected.contains(p.name)).toList();

      final items = [
        ...presets.map((p) {
          final dueDate = _dueDates[p.name];
          return {
            'name': p.name,
            'category': p.category.name,
            'description': p.description,
            'frequencyMonths': p.frequencyMonths,
            'nextDueDate': dueDate?.toIso8601String(),
          };
        }),
        ..._customEntries.map((e) => {
              'name': e.name,
              'category': e.category.name,
              'description': e.description,
              'frequencyMonths': e.frequencyMonths,
              'nextDueDate': e.dueDate?.toIso8601String(),
            }),
      ];

      await FirestoreService.createMaintenanceItems(items);

      if (mounted) {
        if (widget.isInitialSetup) {
          Navigator.of(context).pushReplacementNamed('/hub');
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

  void _toggleCategory(HubCategory cat, List<HubPreset> items) {
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
    final totalSelected = _selected.length + _customEntries.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isInitialSetup ? 'Set Up Life Hub' : 'Add More Reminders'),
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
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
                  'Select presets or add your own. Set due dates now or later.',
                  style: TextStyle(
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: HubCategory.values.map((cat) {
                final items = grouped[cat] ?? [];
                final customForCat =
                    _customEntries.where((e) => e.category == cat).toList();

                // Always show the Custom category; hide others if they have no presets
                if (items.isEmpty && cat != HubCategory.custom) {
                  return const SizedBox.shrink();
                }

                final isExpanded = _expandedCategory == cat;
                final presetSelectedCount =
                    items.where((p) => _selected.contains(p.name)).length;
                final totalForCat =
                    presetSelectedCount + customForCat.length;

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
                                    _categorySubtitle(items,
                                        presetSelectedCount, customForCat),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (items.isNotEmpty)
                              TextButton(
                                onPressed: () =>
                                    _toggleCategory(cat, items),
                                child: Text(
                                  presetSelectedCount == items.length
                                      ? 'Deselect All'
                                      : 'Select All',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            if (totalForCat > 0)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$totalForCat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: cat.color,
                                  ),
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
                    // Expanded content
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Presets grid
                            if (items.isNotEmpty)
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 138,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: items.length,
                                itemBuilder: (_, i) =>
                                    _buildPresetTile(items[i]),
                              ),
                            // Custom entries for this category
                            if (customForCat.isNotEmpty) ...[
                              if (items.isNotEmpty) const SizedBox(height: 8),
                              ...customForCat
                                  .map((e) => _buildCustomEntryTile(e)),
                            ],
                            // Add custom button
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _addCustomItem(cat),
                              icon: Icon(Icons.add, size: 16,
                                  color: cat.color),
                              label: Text(
                                'Add Custom Reminder',
                                style: TextStyle(color: cat.color),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: cat.color.withValues(alpha: 0.4)),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        ? 'Save $totalSelected Items & Continue'
                        : 'Add $totalSelected Items',
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

  String _categorySubtitle(List<HubPreset> presets, int presetSelected,
      List<_CustomEntry> custom) {
    if (presets.isEmpty) {
      if (custom.isEmpty) return 'Tap to add custom reminders';
      return '${custom.length} custom item${custom.length == 1 ? '' : 's'}';
    }
    final buf = '$presetSelected / ${presets.length} selected';
    if (custom.isEmpty) return buf;
    return '$buf + ${custom.length} custom';
  }

  Widget _buildCustomEntryTile(_CustomEntry entry) {
    final cat = entry.category;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: cat.color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cat.color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.tune, size: 18, color: cat.color),
        title: Text(
          entry.name,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: onSurface),
        ),
        subtitle: Text(
          entry.dueDate != null
              ? '${_frequencyLabel(entry.frequencyMonths)} · Due ${entry.dueDate!.day}/${entry.dueDate!.month}/${entry.dueDate!.year}'
              : _frequencyLabel(entry.frequencyMonths),
          style: TextStyle(
              fontSize: 11, color: onSurface.withValues(alpha: 0.6)),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
          onPressed: () => setState(() => _customEntries.remove(entry)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  Widget _buildPresetTile(HubPreset preset) {
    final isSelected = _selected.contains(preset.name);
    final dueDate = _dueDates[preset.name];
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      margin: EdgeInsets.zero,
      color: isSelected
          ? preset.category.color.withValues(alpha: 0.06)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected
            ? BorderSide(
                color: preset.category.color.withValues(alpha: 0.4),
                width: 1.5)
            : BorderSide.none,
      ),
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
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: isSelected,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) => setState(() {
                        if (val == true) {
                          _selected.add(preset.name);
                        } else {
                          _selected.remove(preset.name);
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: preset.category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  preset.frequencyLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: preset.category.color,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  preset.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                GestureDetector(
                  onTap: () => _pickDueDate(preset.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: preset.category.color
                              .withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 11, color: preset.category.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            dueDate != null
                                ? '${dueDate.day}/${dueDate.month}/${dueDate.year}'
                                : 'Set due date',
                            style: TextStyle(
                              fontSize: 10,
                              color: preset.category.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
