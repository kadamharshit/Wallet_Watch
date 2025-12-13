import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/features/expense/edit_expense.dart';
import 'package:walletwatch/services/expense_database.dart';

class ExpenseTracker extends StatefulWidget {
  const ExpenseTracker({super.key});

  @override
  State<ExpenseTracker> createState() => _ExpenseTrackerState();
}

class _ExpenseTrackerState extends State<ExpenseTracker> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  bool _isOnline = false;

  String _filterMode = 'All'; // All / Cash / Online

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  // ---------------- INTERNET ----------------
  Future<bool> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------- LOAD EXPENSES ----------------
  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    _isOnline = await _checkConnection();
    final user = supabase.auth.currentUser;

    // 1️⃣ Sync local → Supabase
    if (_isOnline && user != null) {
      await _syncLocalToSupabase();
    }

    // 2️⃣ Fetch from Supabase & cache locally
    if (_isOnline && user != null) {
      try {
        final response = await supabase
            .from('expenses')
            .select()
            .eq('user_id', user.id)
            .order('date', ascending: false);

        final serverExpenses = List<Map<String, dynamic>>.from(response);

        for (final exp in serverExpenses) {
          await DatabaseHelper.instance.upsertExpenseByUuid({
            'uuid': exp['uuid'],
            'supabase_id': exp['id'],
            'date': exp['date'],
            'shop': exp['shop'] ?? '',
            'category': exp['category'] ?? '',
            'items': exp['items'] ?? '',
            'total': exp['total'] ?? 0,
            'mode': exp['mode'] ?? 'Cash',
            'bank': exp['bank'] ?? '',
            'synced': 1,
          });
        }

        _expenses = await DatabaseHelper.instance.getExpenses();
      } catch (e) {
        debugPrint("Supabase fetch error: $e");
        _expenses = await DatabaseHelper.instance.getExpenses();
      }
    } else {
      // Offline
      _expenses = await DatabaseHelper.instance.getExpenses();
    }

    setState(() => _isLoading = false);
  }

  // ---------------- SYNC ----------------
  Future<void> _syncLocalToSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses();

    for (final exp in unsynced) {
      try {
        final response = await supabase
            .from('expenses')
            .insert({
              'uuid': exp['uuid'],
              'user_id': user.id,
              'date': exp['date'],
              'shop': exp['shop'],
              'category': exp['category'],
              'items': exp['items'],
              'total': exp['total'],
              'mode': exp['mode'],
              'bank': exp['bank'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateExpense(exp['id'], {
          'supabase_id': response['id'],
          'synced': 1,
        });
      } catch (e) {
        debugPrint("Sync error: $e");
      }
    }
  }

  // ---------------- HELPERS ----------------
  String _formatDate(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;

    final diff = DateTime.now().difference(parsed).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  double get _totalCash => _expenses
      .where((e) => (e['mode'] ?? '').toString().toLowerCase() == 'cash')
      .fold(0.0, (sum, e) => sum + (e['total'] as num).toDouble());

  double get _totalOnline => _expenses
      .where((e) => (e['mode'] ?? '').toString().toLowerCase() == 'online')
      .fold(0.0, (sum, e) => sum + (e['total'] as num).toDouble());

  double get _grandTotal => _totalCash + _totalOnline;

  List<Map<String, dynamic>> get _filteredExpenses {
    if (_filterMode == 'All') return _expenses;
    return _expenses.where((e) {
      return (e['mode'] ?? '').toString().toLowerCase() ==
          _filterMode.toLowerCase();
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedByDate {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final e in _filteredExpenses) {
      final date = e['date'] ?? '';
      map.putIfAbsent(date, () => []).add(e);
    }

    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  // ---------------- DELETE ----------------
  Future<void> _deleteExpense(Map<String, dynamic> exp) async {
    final localId = exp['id'];
    final supabaseId = exp['supabase_id'];
    final uuid = exp['uuid'];

    await DatabaseHelper.instance.deleteExpense(localId);

    final user = supabase.auth.currentUser;
    if (user != null) {
      if (supabaseId != null) {
        await supabase.from('expenses').delete().eq('id', supabaseId);
      } else if (uuid != null) {
        await supabase.from('expenses').delete().eq('uuid', uuid);
      }
    }

    await _loadExpenses();
  }

  // ---------------- UI ----------------
  Widget _buildExpenseCard(Map<String, dynamic> exp) {
    final amount = (exp['total'] as num).toDouble();
    final isOnline = (exp['mode'] ?? '').toString().toLowerCase() == 'online';

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditExpensePage(expense: exp)),
        ).then((_) => _loadExpenses());
      },
      leading: CircleAvatar(
        backgroundColor: isOnline
            ? Colors.blue.withOpacity(.1)
            : Colors.green.withOpacity(.1),
        child: Icon(
          isOnline ? Icons.account_balance_wallet : Icons.money,
          color: isOnline ? Colors.blue : Colors.green,
        ),
      ),
      title: Text(exp['shop'] ?? 'Unknown'),
      subtitle: Text("${_formatDate(exp['date'])} • ${exp['category']}"),
      trailing: Text(
        "₹${amount.toStringAsFixed(2)}",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadExpenses),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Total: ₹${_grandTotal.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text("Cash: ₹${_totalCash.toStringAsFixed(2)}"),
                            const Spacer(),
                            Text("Online: ₹${_totalOnline.toStringAsFixed(2)}"),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _filterMode == 'All',
                              onSelected: (_) =>
                                  setState(() => _filterMode = 'All'),
                            ),
                            ChoiceChip(
                              label: const Text('Cash'),
                              selected: _filterMode == 'Cash',
                              onSelected: (_) =>
                                  setState(() => _filterMode = 'Cash'),
                            ),
                            ChoiceChip(
                              label: const Text('Online'),
                              selected: _filterMode == 'Online',
                              onSelected: (_) =>
                                  setState(() => _filterMode = 'Online'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: _groupedByDate.entries.map((entry) {
                      final dateTotal = entry.value.fold<double>(
                        0,
                        (sum, e) => sum + (e['total'] as num).toDouble(),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              "${_formatDate(entry.key)} • ₹${dateTotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...entry.value.map((e) {
                            return Dismissible(
                              key: ValueKey(e['uuid']),
                              direction: DismissDirection.horizontal,

                              // 👉 EDIT (Swipe right)
                              background: Container(
                                color: Colors.blue,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 16),
                                child: const Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 👉 DELETE (Swipe left)
                              secondaryBackground: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.delete, color: Colors.white),
                                  ],
                                ),
                              ),

                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // 🟦 EDIT
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditExpensePage(expense: e),
                                    ),
                                  );
                                  await _loadExpenses();
                                  return false;
                                }

                                if (direction == DismissDirection.endToStart) {
                                  final confirm = await _confirmDeleteDialog();
                                  if (confirm) {
                                    await _deleteExpense(e);
                                  }
                                  return confirm;
                                }

                                return false;
                              },

                              child: _buildExpenseCard(e),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
