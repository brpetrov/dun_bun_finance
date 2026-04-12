import 'package:dun_bun_finance/hub/hub_item.dart';
import 'package:dun_bun_finance/hub/hub_setup_screen.dart';
import 'package:dun_bun_finance/services/firestore_service.dart';
import 'package:flutter/material.dart';

class LifeHubScreen extends StatefulWidget {
  const LifeHubScreen({super.key});

  @override
  State<LifeHubScreen> createState() => _LifeHubScreenState();
}

class _LifeHubScreenState extends State<LifeHubScreen> {
  List<HubItem> _items = [];
  bool _loading = true;
  HubCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final raw = await FirestoreService.getMaintenanceItems();
      _items = raw.map((data) {
        DateTime? nextDue;
        if (data['nextDueDate'] != null) {
          nextDue = DateTime.tryParse(data['nextDueDate'] as String);
        }
        DateTime? lastDone;
        if (data['lastDoneDate'] != null) {
          lastDone = DateTime.tryParse(data['lastDoneDate'] as String);
        }
        return HubItem(
          id: data['id'] as String,
          name: data['name'] as String,
          category: HubCategory.fromString(data['category'] as String?),
          description: data['description'] as String? ?? '',
          frequencyMonths: (data['frequencyMonths'] as num?)?.toInt() ?? 12,
          lastDoneDate: lastDone,
          nextDueDate: nextDue,
        );
      }).toList();

      // Sort: overdue first, then due soon, then upcoming, then ok
      _items.sort((a, b) {
        final statusOrder = a.status.index.compareTo(b.status.index);
        if (statusOrder != 0) return statusOrder;
        if (a.nextDueDate != null && b.nextDueDate != null) {
          return a.nextDueDate!.compareTo(b.nextDueDate!);
        }
        return 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markDone(HubItem item) async {
    await FirestoreService.markMaintenanceDone(item.id, item.frequencyMonths);
    await _loadItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} marked as done!'),
          backgroundColor: Colors.greenAccent.shade700,
        ),
      );
    }
  }

  Future<void> _editItem(HubItem item) async {
    final nameController = TextEditingController(text: item.name);
    final descController = TextEditingController(text: item.description);
    int frequencyMonths = item.frequencyMonths;
    HubCategory category = item.category;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<HubCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: HubCategory.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(c.icon, size: 18, color: c.color),
                                  const SizedBox(width: 8),
                                  Text(c.label),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => category = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _frequencyOptions.contains(frequencyMonths)
                        ? frequencyMonths
                        : 12,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                    ),
                    items: _frequencyOptions
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(_frequencyLabel(m)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => frequencyMonths = val);
                      }
                    },
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
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      await FirestoreService.updateMaintenanceItem(item.id, {
        'name': name,
        'description': descController.text.trim(),
        'category': category.name,
        'frequencyMonths': frequencyMonths,
      });
      await _loadItems();
    }

    nameController.dispose();
    descController.dispose();
  }

  static const _frequencyOptions = [1, 3, 6, 12, 18, 24, 60, 120];

  Future<void> _deleteItem(HubItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Reminder'),
        content: Text('Remove "${item.name}" from your Life Hub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirestoreService.deleteMaintenanceItem(item.id);
      await _loadItems();
    }
  }

  Future<void> _editDueDate(HubItem item) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.nextDueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 15),
      helpText: 'When is "${item.name}" next due?',
    );
    if (picked != null) {
      await FirestoreService.updateMaintenanceItem(item.id, {
        'nextDueDate': picked.toIso8601String(),
      });
      await _loadItems();
    }
  }

  Future<void> _openSetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LifeHubSetupScreen(isInitialSetup: false),
      ),
    );
    if (result == true) {
      await _loadItems();
    }
  }

  List<HubItem> get _filteredItems {
    if (_filterCategory == null) return _items;
    return _items.where((i) => i.category == _filterCategory).toList();
  }

  int _countByStatus(HubStatus status) {
    return _items.where((i) => i.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final overdueCount = _countByStatus(HubStatus.overdue);
    final dueSoonCount = _countByStatus(HubStatus.dueSoon);
    final upcomingCount = _countByStatus(HubStatus.upcoming);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Hub'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add more reminders',
            onPressed: _openSetup,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadItems,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    if (overdueCount > 0 ||
                        dueSoonCount > 0 ||
                        upcomingCount > 0)
                      _buildStatusBar(
                          overdueCount, dueSoonCount, upcomingCount),
                    _buildFilterChips(onSurface),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 600 ? 2 : 1;
                          return RefreshIndicator(
                            onRefresh: _loadItems,
                            child: GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 8, 12, 80),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 108,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _filteredItems.length,
                              itemBuilder: (_, i) =>
                                  _buildItemCard(_filteredItems[i]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No Life Hub reminders yet',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openSetup,
            icon: const Icon(Icons.add),
            label: const Text('Set Up Reminders'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(int overdue, int dueSoon, int upcoming) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: overdue > 0
          ? Colors.redAccent.withValues(alpha: 0.1)
          : dueSoon > 0
              ? Colors.orangeAccent.withValues(alpha: 0.1)
              : Colors.amber.withValues(alpha: 0.08),
      child: Row(
        children: [
          if (overdue > 0) ...[
            _statusChip('$overdue Overdue', HubStatus.overdue),
            const SizedBox(width: 8),
          ],
          if (dueSoon > 0) ...[
            _statusChip('$dueSoon Due Soon', HubStatus.dueSoon),
            const SizedBox(width: 8),
          ],
          if (upcoming > 0)
            _statusChip('$upcoming Coming Up', HubStatus.upcoming),
        ],
      ),
    );
  }

  Widget _statusChip(String label, HubStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Color onSurface) {
    final categories = _items.map((i) => i.category).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text('All (${_items.length})'),
            selected: _filterCategory == null,
            onSelected: (_) => setState(() => _filterCategory = null),
          ),
          const SizedBox(width: 6),
          ...categories.map((cat) {
            final count = _items.where((i) => i.category == cat).length;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: Icon(cat.icon, size: 16, color: cat.color),
                label: Text('${cat.label} ($count)'),
                selected: _filterCategory == cat,
                onSelected: (_) => setState(() =>
                    _filterCategory = _filterCategory == cat ? null : cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemCard(HubItem item) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final status = item.status;
    final daysUntil = item.nextDueDate?.difference(DateTime.now()).inDays;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showItemDetails(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + title + menu on one row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(status.icon, color: status.color, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert,
                        size: 16, color: onSurface.withValues(alpha: 0.4)),
                    onSelected: (value) {
                      switch (value) {
                        case 'done':
                          _markDone(item);
                        case 'edit':
                          _editItem(item);
                        case 'date':
                          _editDueDate(item);
                        case 'delete':
                          _deleteItem(item);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'done',
                        child: ListTile(
                          leading:
                              Icon(Icons.check_circle, color: Colors.green),
                          title: Text('Mark as Done'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'date',
                        child: ListTile(
                          leading: Icon(Icons.calendar_today),
                          title: Text('Change Due Date'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          title: Text('Remove'),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Category badge + due date on same row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      item.category.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: item.category.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.nextDueDate != null
                          ? _dueLabel(daysUntil!)
                          : 'No due date set',
                      style: TextStyle(
                        fontSize: 11,
                        color: item.nextDueDate != null
                            ? status.color
                            : onSurface.withValues(alpha: 0.4),
                        fontWeight: item.nextDueDate != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetails(HubItem item) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final status = item.status;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.category.icon,
                      color: item.category.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: status.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: status.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  item.category.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: item.category.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.description,
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.repeat, 'Frequency',
                _frequencyLabel(item.frequencyMonths), onSurface),
            if (item.nextDueDate != null)
              _detailRow(Icons.calendar_today, 'Next Due',
                  _formatDate(item.nextDueDate!), onSurface),
            if (item.lastDoneDate != null)
              _detailRow(Icons.check, 'Last Done',
                  _formatDate(item.lastDoneDate!), onSurface),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _editItem(item);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _editDueDate(item);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Set Date'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _markDone(item);
                    },
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Mark Done'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, Color onSurface) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: onSurface.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _dueLabel(int daysUntil) {
    if (daysUntil < -1) return '${-daysUntil} days overdue!';
    if (daysUntil == -1) return 'Overdue by 1 day!';
    if (daysUntil == 0) return 'Due today!';
    if (daysUntil == 1) return 'Due tomorrow';
    if (daysUntil <= 14) return 'Due in $daysUntil days';
    if (daysUntil <= 60) return 'Due in ${(daysUntil / 7).round()} weeks';
    return 'Due in ${(daysUntil / 30).round()} months';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

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
}
