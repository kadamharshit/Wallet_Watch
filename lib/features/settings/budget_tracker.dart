import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'dart:collection';

class BudgetTracker extends StatefulWidget {
  const BudgetTracker({super.key});

  @override
  State<BudgetTracker> createState() => _BudgetTrackerState();
}

class _BudgetTrackerState extends State<BudgetTracker> {
  late Future<List<Map<String, dynamic>>> _budgetList = Future.value([]);
  List<String> _availableMonths = [];
  String _selectedMonth = '';
  double _cashTotal = 0.0;
  double _onlineTotal = 0.0;
  List<Map<String, dynamic>> _filteredBudgets = [];

  @override
  void initState() {
    super.initState();
    _initializeMonthList();
  }

  void _initializeMonthList() async {
    final allBudgets = await DatabaseHelper.instance.getBudget();
    final monthSet = <String>{};

    for (var entry in allBudgets) {
      final date = entry['date'] ?? '';
      if (date.length >= 7) {
        monthSet.add(date.substring(0, 7));
      }
    }

    final sortedMonths = monthSet.toList()..sort((a, b) => b.compareTo(a));

    setState(() {
      _availableMonths = sortedMonths;
      _selectedMonth = sortedMonths.isNotEmpty
          ? sortedMonths.first
          : "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
    });

    _loadBudgetsForMonth(_selectedMonth);
  }

  void _loadBudgetsForMonth(String month) async {
    final allBudgets = await DatabaseHelper.instance.getBudget();
    final filtered = allBudgets.where((entry) {
      final date = entry['date'] ?? '';
      return date.startsWith(month);
    }).toList();

    double cash = 0.0;
    double online = 0.0;

    for (var entry in filtered) {
      final amount = (entry['total'] as num?)?.toDouble() ?? 0.0;
      if (entry['mode'] == 'Cash') {
        cash += amount;
      } else {
        online += amount;
      }
    }

    setState(() {
      _budgetList = Future.value(filtered);
      _filteredBudgets = filtered;
      _cashTotal = cash;
      _onlineTotal = online;
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatMonthLabel(String monthYear) {
    final parts = monthYear.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return "${_getMonthName(month)} $year";
  }

  Future<void> _showEditDialog(Map<String, dynamic> entry) async {
    final amountController = TextEditingController(
      text: entry['total'].toString(),
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Budget"),
        content: TextField(
          controller: amountController,
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
              final newAmount = double.tryParse(amountController.text);
              if (newAmount != null) {
                await DatabaseHelper.instance.updateBudget(entry['id'], {
                  'date': entry['date'],
                  'total': newAmount,
                  'mode': entry['mode'],
                  'bank': entry['bank'] ?? '',
                });
                final supabaseId = entry['supabase_id'];
                if (supabaseId != null) {
                  final supabase = Supabase.instance.client;
                  await supabase
                      .from('budgets')
                      .update({'total': newAmount})
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

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Budget Entry"),
        content: const Text("Are you sure you want to delete this entry?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteBudget(id);
      _loadBudgetsForMonth(_selectedMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group online budgets by bank
    final onlineByBank = <String, List<Map<String, dynamic>>>{};
    for (var entry in _filteredBudgets) {
      if (entry['mode'] != 'Cash') {
        final bank = (entry['bank'] as String?)?.isNotEmpty == true
            ? entry['bank']
            : 'Unknown';
        onlineByBank.putIfAbsent(bank!, () => []).add(entry);
      }
    }

    final cashEntries = _filteredBudgets
        .where((e) => e['mode'] == 'Cash')
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text("Budget Tracker"),
      ),
      body: Column(
        children: [
          if (_availableMonths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: DropdownButton<String>(
                value: _selectedMonth,
                isExpanded: true,
                items: _availableMonths.map((month) {
                  return DropdownMenuItem<String>(
                    value: month,
                    child: Text(_formatMonthLabel(month)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMonth = value;
                    });
                    _loadBudgetsForMonth(value);
                  }
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cash Budget – ${_formatMonthLabel(_selectedMonth)}: ₹${_cashTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                Text(
                  "Online Budget – ${_formatMonthLabel(_selectedMonth)}: ₹${_onlineTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ExpansionTile(
                  title: const Text("Cash"),
                  children: cashEntries.map((item) {
                    return ListTile(
                      leading: const Icon(
                        Icons.attach_money,
                        color: Colors.green,
                      ),
                      title: Text(
                        "₹${(item['total'] as double).toStringAsFixed(2)}",
                      ),
                      subtitle: Text(
                        "Date: ${item['date']} • Mode: ${item['mode']}",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _showEditDialog(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(item['id']),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                ...onlineByBank.entries.map((entry) {
                  return ExpansionTile(
                    title: Text("Online - ${entry.key}"),
                    children: entry.value.map((item) {
                      return ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.blue,
                        ),
                        title: Text(
                          "₹${(item['total'] as double).toStringAsFixed(2)}",
                        ),
                        subtitle: Text(
                          "Date: ${item['date']} • Mode: ${item['mode']} • Bank: ${item['bank'] ?? 'Unknown'}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () => _showEditDialog(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(item['id']),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
