import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:walletwatch/services/expense_database.dart'; // to check network status
import 'package:uuid/uuid.dart';

class AddManualExpense extends StatefulWidget {
  const AddManualExpense({super.key});

  @override
  State<AddManualExpense> createState() => _AddManualExpenseState();
}

class _AddManualExpenseState extends State<AddManualExpense> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedDate;
  final _shopController = TextEditingController();
  String _selectedCategory = 'Grocery';
  String _selectedPaymentMode = 'Cash';

  List<Map<String, String>> itemInputs = [];
  double total = 0.0;

  String? _selectedBank;
  List<String> _availableBanks = [];

  final List<String> _categories = [
    'Grocery',
    'Travel',
    'Food',
    'Medical',
    'Bills',
    'Other',
  ];

  final List<String> _paymentModes = ['Cash', 'Online'];

  @override
  void initState() {
    super.initState();
    itemInputs.add({});
    _fetchAvailableBanks();
    _syncPendingExpenses(); // try syncing any unsynced ones
  }

  Future<void> _fetchAvailableBanks() async {
    final budgets = await DatabaseHelper.instance.getBudget();
    final banks = budgets
        .where((b) => b['mode'] == 'Online')
        .map((b) => b['bank']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _availableBanks = banks;
      if (_availableBanks.isNotEmpty) _selectedBank = _availableBanks.first;
    });
  }

  void _addItem() {
    setState(() {
      itemInputs.add({});
    });
  }

  void _updateTotal() {
    double sum = 0.0;
    for (var item in itemInputs) {
      final amt = double.tryParse(item['amount'] ?? '0') ?? 0;
      sum += amt;
    }
    setState(() {
      total = sum;
    });
  }

  /// ✅ Check if connected to the internet
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// ✅ Try syncing local unsynced expenses to Supabase
  Future<void> _syncPendingExpenses() async {
    final hasConnection = await _hasInternetConnection();
    if (!hasConnection) return;

    final supabase = Supabase.instance.client;
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
              'bank': exp['bank']?.toString().isEmpty ?? true
                  ? null
                  : exp['bank'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        final supabaseId = response['id'] as int;

        await DatabaseHelper.instance.updateExpense(exp['id'], {
          'supabase_id': supabaseId,
          'synced': 1,
        });
      } catch (e) {
        debugPrint('Sync error for expense ${exp['id']}: $e');
      }
    }
  }

  Future<double> _getRemainingBudgetForMode(String mode) async {
    final now = DateTime.now();
    final currentMonthPrefix = '${now.year.toString().padLeft(2, '0')}';
    final allBudgets = await DatabaseHelper.instance.getBudget();

    double remaining = 0.0;

    for (final b in allBudgets) {
      final dateStr = (b['date'] ?? '') as String;
      if (!dateStr.startsWith(currentMonthPrefix)) continue;
      if (b['mode'] != mode) continue;

      final amount = (b['total'] as num?)?.toDouble() ?? 0.0;
      remaining += amount;
    }
    return remaining;
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final String date =
          _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

      // final itemString = itemInputs
      //     .map((item) => item.values.join(' | '))
      //     .join('\n');

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("You must be logged in")));
        return;
      }

      final remainingBudget = await _getRemainingBudgetForMode(
        _selectedPaymentMode,
      );

      if (remainingBudget <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Warning: Your $_selectedPaymentMode budget for this month "
              "is already used up (₹${remainingBudget.toStringAsFixed(2)}).",
            ),
          ),
        );
      } else if (total > remainingBudget) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Warning: This expense (₹${total.toStringAsFixed(2)}) exceeds your "
              "remaining $_selectedPaymentMode budget of "
              "₹${remainingBudget.toStringAsFixed(2)}.",
            ),
          ),
        );
      }
      final newUuid = const Uuid().v4();

      final expense = {
        'supabase_id': null,
        'uuid': newUuid,
        'date': date,
        'shop': _shopController.text,
        'category': _selectedCategory,
        'items': itemInputs.map((item) => item.values.join(' | ')).join('\n'),
        'total': total,
        'mode': _selectedPaymentMode,
        'bank': _selectedPaymentMode == 'Online' ? _selectedBank ?? '' : '',
        'synced': 0, // mark as not synced yet
      };
      try {
        // ✅ Save locally first
        final expenseId = await DatabaseHelper.instance.insertExpense(expense);

        // ✅ Deduct from local budget
        final deduction = {
          'supabase_id': null,
          'uuid': const Uuid().v4(),
          'date': date,
          'total': -total,
          'mode': _selectedPaymentMode,
          if (_selectedPaymentMode == 'Online') 'bank': _selectedBank ?? '',
        };
        await DatabaseHelper.instance.insertBudget(deduction);

        // ✅ Try uploading to Supabase if online
        if (await _hasInternetConnection()) {
          try {
            final supabase = Supabase.instance.client;
            final user = supabase.auth.currentUser;

            if (user != null) {
              final response = await supabase
                  .from('expenses')
                  .insert({
                    'uuid': newUuid,
                    'user_id': user.id,
                    'date': date,
                    'shop': _shopController.text,
                    'category': _selectedCategory,
                    'items': itemInputs
                        .map((item) => item.values.join(' | '))
                        .join('\n'),
                    'total': total,
                    'mode': _selectedPaymentMode,
                    'bank': _selectedPaymentMode == 'Online'
                        ? _selectedBank ?? ''
                        : null,
                    'created_at': DateTime.now().toIso8601String(),
                  })
                  .select('id')
                  .single();

              final supabaseId = response['id'] as int;

              // mark as synced locally
              await DatabaseHelper.instance.updateExpense(expenseId, {
                'supabase_id': supabaseId,
                'synced': 1,
              });
            }
          } catch (e) {
            debugPrint('Supabase insert error: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense Saved (Synced if online) ✅")),
        );

        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        debugPrint('Supabase/local error: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving expense: $e")));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Widget _buildItemFields(int index) {
    final item = itemInputs[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedCategory == 'Travel') ...[
          TextFormField(
            decoration: const InputDecoration(labelText: 'Mode'),
            onSaved: (val) => item['mode'] = val ?? '',
            initialValue: item['mode'],
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter mode' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Start'),
            onSaved: (val) => item['start'] = val ?? '',
            initialValue: item['start'],
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter start' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Destination'),
            onSaved: (val) => item['destination'] = val ?? '',
            initialValue: item['destination'],
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter destination' : null,
          ),
        ] else ...[
          TextFormField(
            decoration: const InputDecoration(labelText: 'Item Name'),
            onSaved: (val) => item['name'] = val ?? '',
            initialValue: item['name'],
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter item name' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Quantity'),
            onSaved: (val) => item['qty'] = val ?? '',
            initialValue: item['qty'],
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter quantity' : null,
          ),
        ],
        TextFormField(
          decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
          onChanged: (val) {
            item['amount'] = val;
            _updateTotal();
          },
          onSaved: (val) => item['amount'] = val ?? '0',
          initialValue: item['amount'],
          validator: (val) =>
              val == null || val.isEmpty ? 'Enter amount' : null,
        ),
        const Divider(thickness: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Manual Expense'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(_selectedDate ?? 'Select Date'),
              ),
              TextFormField(
                controller: _shopController,
                decoration: const InputDecoration(
                  labelText: 'Shop Name / Type',
                ),
                validator: (value) => value!.isEmpty ? 'Enter shop name' : null,
              ),
              DropdownButtonFormField(
                value: _selectedCategory,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                    itemInputs = [{}];
                    total = 0.0;
                  });
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              DropdownButtonFormField(
                value: _selectedPaymentMode,
                items: _paymentModes
                    .map(
                      (mode) =>
                          DropdownMenuItem(value: mode, child: Text(mode)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMode = value!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Paid By'),
              ),
              if (_selectedPaymentMode == 'Online' &&
                  _availableBanks.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedBank,
                  items: _availableBanks
                      .map(
                        (bank) =>
                            DropdownMenuItem(value: bank, child: Text(bank)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBank = val;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Select Bank'),
                ),
              const SizedBox(height: 16),
              const Text(
                "Items",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                itemInputs.length,
                (index) => _buildItemFields(index),
              ),
              Text("Total: ₹${total.toStringAsFixed(2)}"),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text("Add Another Item"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveExpense,
                child: const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
