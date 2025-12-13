import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';

class BudgetTracker extends StatefulWidget {
  const BudgetTracker({super.key});

  @override
  State<BudgetTracker> createState() => _BudgetTrackerState();
}

class _BudgetTrackerState extends State<BudgetTracker> {
  List<Map<String, dynamic>> _filteredBudgets = [];

  double _cashTotal = 0.0;
  double _onlineTotal = 0.0;

  String _filterMode = 'All'; // All / Cash / Online
  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    _loadBudgetsForMonth(_selectedMonth);
  }

  // ---------------- LOAD ----------------
  Future<void> _loadBudgetsForMonth(String month) async {
    final allBudgets = await DatabaseHelper.instance.getBudget();

    final filtered = allBudgets
        .where((b) => (b['date'] ?? '').toString().startsWith(month))
        .toList();

    double cash = 0;
    double online = 0;

    for (final b in filtered) {
      final amount = (b['total'] as num?)?.toDouble() ?? 0;
      if ((b['mode'] ?? '') == 'Cash') {
        cash += amount;
      } else {
        online += amount;
      }
    }

    setState(() {
      _filteredBudgets = filtered;
      _cashTotal = cash;
      _onlineTotal = online;
    });
  }

  // ---------------- FILTER ----------------
  List<Map<String, dynamic>> get _filteredByMode {
    if (_filterMode == 'All') return _filteredBudgets;

    return _filteredBudgets.where((b) {
      return (b['mode'] ?? '').toString().toLowerCase() ==
          _filterMode.toLowerCase();
    }).toList();
  }

  // ---------------- EDIT ----------------
  Future<void> _showEditDialog(Map<String, dynamic> entry) async {
    final controller = TextEditingController(text: entry['total'].toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Budget"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Amount"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value != null) {
                await DatabaseHelper.instance.updateBudget(entry['id'], {
                  'total': value,
                });

                final supabaseId = entry['supabase_id'];
                if (supabaseId != null) {
                  await Supabase.instance.client
                      .from('budgets')
                      .update({'total': value})
                      .eq('id', supabaseId);
                }

                Navigator.pop(context);
                _loadBudgetsForMonth(_selectedMonth);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ---------------- DELETE ----------------
  Future<bool> _confirmDelete(Map<String, dynamic> entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete budget?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (result == true) {
      await DatabaseHelper.instance.deleteBudget(entry['id']);

      if (entry['supabase_id'] != null) {
        await Supabase.instance.client
            .from('budgets')
            .delete()
            .eq('id', entry['supabase_id']);
      }

      _loadBudgetsForMonth(_selectedMonth);
      return true;
    }
    return false;
  }

  // ---------------- SUMMARY ----------------
  Widget _buildSummary() {
    final total = _cashTotal + _onlineTotal;

    final cashFrac = total == 0 ? 0 : _cashTotal / total;
    final onlineFrac = total == 0 ? 0 : _onlineTotal / total;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This Month's Budget",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              "Total: ₹${total.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: Text("Cash: ₹${_cashTotal.toStringAsFixed(2)}"),
                ),
                Expanded(
                  child: Text(
                    "Online: ₹${_onlineTotal.toStringAsFixed(2)}",
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Row(
                children: [
                  Expanded(
                    flex: (cashFrac * 1000).round(),
                    child: Container(height: 6, color: Colors.green),
                  ),
                  Expanded(
                    flex: (onlineFrac * 1000).round(),
                    child: Container(height: 6, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- CARD ----------------
  Widget _buildBudgetCard(Map<String, dynamic> item) {
    final amount = (item['total'] as num?)?.toDouble() ?? 0;
    final isOnline = (item['mode'] ?? '') == 'Online';

    return Dismissible(
      key: ValueKey(item['id']),
      background: _slideBg(
        Icons.edit,
        'Edit',
        Colors.blue,
        Alignment.centerLeft,
      ),
      secondaryBackground: _slideBg(
        Icons.delete,
        'Delete',
        Colors.red,
        Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _showEditDialog(item);
          return false;
        }
        return await _confirmDelete(item);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isOnline
                ? Colors.blue.withOpacity(0.12)
                : Colors.green.withOpacity(0.12),
            child: Icon(
              isOnline ? Icons.account_balance_wallet : Icons.money,
              color: isOnline ? Colors.blue : Colors.green,
            ),
          ),
          title: Text(
            isOnline && (item['bank'] ?? '').toString().isNotEmpty
                ? item['bank']
                : '${item['mode']} Budget',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text("Date: ${item['date']}"),
          trailing: Text(
            "₹${amount.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _slideBg(
    IconData icon,
    String text,
    Color color,
    Alignment alignment,
  ) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white)),
          ] else ...[
            Text(text, style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white),
          ],
        ],
      ),
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final list = _filteredByMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Budget Tracker"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSummary(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: ['All', 'Cash', 'Online']
                  .map(
                    (m) => ChoiceChip(
                      label: Text(m),
                      selected: _filterMode == m,
                      onSelected: (_) => setState(() => _filterMode = m),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text("No budget entries found"))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildBudgetCard(list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
