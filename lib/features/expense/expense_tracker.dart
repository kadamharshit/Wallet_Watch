import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// ✅ Load data from Supabase if online, else from local DB
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

  /// ✅ UI for one expense card
  Widget _buildExpenseCard(Map<String, dynamic> exp) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        title: Text(
          exp['shop'] ?? 'Unknown Shop',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${exp['category']} • ${exp['mode']}"),
            Text("₹${exp['total']}"),
            Text(_formatDate(exp['date'])),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshExpenses() async {
    await _loadExpenses();
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshExpenses,
              child: _expenses.isEmpty
                  ? const Center(child: Text("No expenses found"))
                  : ListView.builder(
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) =>
                          _buildExpenseCard(_expenses[index]),
                    ),
            ),
    );
  }
}
