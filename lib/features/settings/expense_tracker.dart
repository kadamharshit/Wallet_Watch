import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/features/expense/edit_expense.dart';
import 'dart:io';

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

  //UI - only State
  String _filterMode = 'All'; //All /Cash /Online

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  /// ✅ Checks internet connection
  Future<bool> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  ///  Load data from Supabase if online, else from local DB
  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    _isOnline = await _checkConnection();
    final user = supabase.auth.currentUser;

    if (_isOnline && user != null) {
      try {
        // Fetch from Supabase
        final response = await supabase
            .from('expenses')
            .select()
            .eq('user_id', user.id)
            .order('date', ascending: false);

        _expenses = List<Map<String, dynamic>>.from(response);

        // Store them locally for offline mode
        for (var exp in _expenses) {
          await DatabaseHelper.instance.insertExpense({
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

        await _syncLocalToSupabase();
      } catch (e) {
        debugPrint("Supabase fetch error: $e");
        // fallback to local
        _expenses = await DatabaseHelper.instance.getExpenses();
      }
    } else {
      // offline mode
      _expenses = await DatabaseHelper.instance.getExpenses();
    }

    setState(() => _isLoading = false);
  }

  /// ✅ Sync unsynced local data to Supabase
  Future<void> _syncLocalToSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses();

    for (var exp in unsynced) {
      try {
        await supabase.from('expenses').insert({
          'user_id': user.id,
          'date': exp['date'],
          'shop': exp['shop'],
          'category': exp['category'],
          'items': exp['items'],
          'total': exp['total'],
          'mode': exp['mode'],
          'bank': exp['bank'],
          'created_at': DateTime.now().toIso8601String(),
        });
        await DatabaseHelper.instance.markExpenseAsSynced(exp['id']);
      } catch (e) {
        debugPrint("Sync error: $e");
      }
    }
  }

  /// ✅ Human readable date
  String _formatDate(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;

    final now = DateTime.now();
    final diff = now.difference(parsed).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  //Sumaries for header
  double get _totalCash {
    double sum = 0;
    for (final e in _expenses) {
      final mode = (e['mode'] ?? 'Cash').toString().toLowerCase();
      final amount = (e['total'] as num?)?.toDouble() ?? 0.0;
      if (mode == 'cash') sum += amount;
    }
    return sum;
  }

  double get _totalOnline {
    double sum = 0;
    for (final e in _expenses) {
      final mode = (e['mode'] ?? '').toString().toLowerCase();
      final amount = (e['total'] as num?)?.toDouble() ?? 0.0;
      if (mode == 'online') sum += amount;
    }
    return sum;
  }

  double get _grandtotal => _totalCash + _totalOnline;

  //Apply filter (All/Cash/Online)
  List<Map<String, dynamic>> get _filteredExpenses {
    if (_filterMode == 'All') return _expenses;

    final target = _filterMode.toLowerCase();
    return _expenses.where((e) {
      final mode = (e['mode'] ?? '').toString().toLowerCase();
      return mode == target;
    }).toList();
  }

  // Group Expenses by data string
  Map<String, List<Map<String, dynamic>>> get _groupedByDate {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final exp in _filteredExpenses) {
      final date = (exp['date'] ?? '').toString();
      if (date.isEmpty) continue;

      map.putIfAbsent(date, () => []).add(exp);
    }

    //Sort dates descending
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));

    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (final k in sortedKeys) {
      sortedMap[k] = map[k]!;
    }
    return sortedMap;
  }

  //Show details of items
  void _showExpenseDetails(Map<String, dynamic> exp) {
    final itemsRaw = (exp['items'] ?? '').toString();
    final itemsLines = itemsRaw.isNotEmpty ? itemsRaw.split('\n') : <String>[];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final amount = (exp['total'] as num?)?.toDouble() ?? 0.0;
        final mode = (exp['mode'] ?? 'Cash').toString();
        final category = (exp['category'] ?? 'Uncategorized').toString();
        final shop = (exp['shop'] ?? 'Unknown Shop').toString();
        final bank = (exp['bank'] ?? '').toString();
        final date = (exp['date'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                shop,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${_formatDate(date)} • $category",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(label: Text(mode)),
                  if (mode.toLowerCase() == 'online' && bank.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Chip(label: Text(bank)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "Amount:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "₹${amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Items",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (itemsLines.isEmpty)
                Text(
                  "No item details saved.",
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                ...itemsLines.map((line) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• "),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  //Edit Expense option
  Future<void> _openEditPage(Map<String, dynamic> exp) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditExpensePage(expense: exp)),
    );

    if (updated == true) {
      // Reload from DB / Supabase so UI shows latest values
      await _loadExpenses();
    }
  }

  //Confirm delete expense
  Future<bool> _confirmDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteExpense(Map<String, dynamic> exp) async {
    try {
      // 1. Delete from local SQLite
      final localId = exp['id'] as int?;
      if (localId != null) {
        await DatabaseHelper.instance.deleteExpense(localId);
      }

      // 2. Best-effort delete from Supabase if we know the remote row
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        // If you stored Supabase row id locally:
        final remoteId = exp['supabase_id'];

        if (remoteId != null) {
          await supabase
              .from('expenses')
              .delete()
              .eq('id', remoteId)
              .eq('user_id', user.id);
        } else if (exp['uuid'] != null) {
          // Fallback: delete by uuid if you use that as link
          await supabase
              .from('expenses')
              .delete()
              .eq('uuid', exp['uuid'])
              .eq('user_id', user.id);
        }
      }

      // 3. Remove from in-memory list & refresh UI
      setState(() {
        _expenses.remove(exp);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense deleted')));
    } catch (e) {
      debugPrint('Delete error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  /// ✅ UI for one expense card with swipe-to-delete + tap for details
  /// ✅ UI for one expense card (NO Dismissible here)
  Widget _buildExpenseCard(Map<String, dynamic> exp) {
    final double amount = (exp['total'] as num?)?.toDouble() ?? 0.0;
    final mode = (exp['mode'] ?? 'Cash').toString();
    final category = (exp['category'] ?? 'Uncategorized').toString();
    final shop = (exp['shop'] ?? 'Unknown Shop').toString();
    final bank = (exp['bank'] ?? '').toString();
    final isOnline = mode.toLowerCase() == 'online';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showExpenseDetails(exp),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: isOnline
              ? Colors.blue.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          child: Icon(
            isOnline ? Icons.account_balance_wallet : Icons.money,
            color: isOnline ? Colors.blue : Colors.green,
            size: 20,
          ),
        ),
        title: Text(shop, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(category),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 4,
                  ),
                ),
                Chip(
                  label: Text(mode),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 4,
                  ),
                ),
                if (isOnline && bank.isNotEmpty)
                  Chip(
                    label: Text(bank),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 4,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Text(
          "₹${amount.toStringAsFixed(2)}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _refreshExpenses() async {
    await _loadExpenses();
  }

  //Small progress bar for header (how much is cash vs online)

  Widget _buildUsageBar() {
    final total = _grandtotal;
    if (total <= 0) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    final cashFraction = _totalCash / total;
    final onlineFraction = _totalOnline / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: [
          Expanded(
            flex: (cashFraction * 1000).round().clamp(0, 1000),
            child: Container(height: 6, color: Colors.green),
          ),
          Expanded(
            flex: (onlineFraction * 1000).round().clamp(0, 1000),
            child: Container(height: 6, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  //Header summary card
  Widget _buildHeaderSummary() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Row: title + online/offline
            Row(
              children: [
                const Text(
                  "This Month's Expenses",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? Colors.green.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOnline ? Icons.cloud_done : Icons.cloud_off,
                        size: 16,
                        color: _isOnline ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline ? "Online" : "Offline",
                        style: TextStyle(
                          fontSize: 12,
                          color: _isOnline ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Total: ₹${_grandtotal.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Cash: ₹${_totalCash.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Online: ₹${_totalOnline.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildUsageBar(),
            const SizedBox(height: 10),
            //Filter chips
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("All"),
                  selected: _filterMode == 'All',
                  onSelected: (_) {
                    setState(() => _filterMode = 'All');
                  },
                ),
                ChoiceChip(
                  label: const Text("Cash"),
                  selected: _filterMode == 'Cash',
                  onSelected: (_) {
                    setState(() => _filterMode = 'Cash');
                  },
                ),
                ChoiceChip(
                  label: const Text('Online'),
                  selected: _filterMode == 'Online',
                  onSelected: (_) {
                    setState(() => _filterMode = 'Online');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// List grouped by date
  Widget _buildGroupedList() {
    final grouped = _groupedByDate;

    if (grouped.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text("No expenses found"),
        ),
      );
    }

    return ListView(
      children: grouped.entries.map((entry) {
        final dateKey = entry.key;
        final list = entry.value;

        final dayTotal = list.fold<double>(
          0,
          (prev, e) => prev + ((e['total'] as num?)?.toDouble() ?? 0.0),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDate(dateKey),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "• ₹${dayTotal.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              // Cards for that date
              ...list.map(_buildDismissibleExpense).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  //Dismissible expense UI
  Widget _buildDismissibleExpense(Map<String, dynamic> exp) {
    final keyValue = exp['id'] ?? exp['uuid'] ?? exp.hashCode;

    return Dismissible(
      key: ValueKey(keyValue),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
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
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
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
          // 👉 Swipe right → EDIT
          await _openEditPage(exp);
          return false; // do NOT dismiss card
        } else if (direction == DismissDirection.endToStart) {
          // 👉 Swipe left → DELETE
          final confirmed = await _confirmDeleteDialog();
          if (confirmed) {
            await _deleteExpense(exp);
          }
          return confirmed;
        }
        return false;
      },
      child: _buildExpenseCard(exp),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            onPressed: _refreshExpenses,
            icon: const Icon(Icons.refresh),
          ),
        ],
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshExpenses,
              child: Column(
                children: [
                  _buildHeaderSummary(),
                  Expanded(child: _buildGroupedList()),
                ],
              ),
            ),
    );
  }
}
