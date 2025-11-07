import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';

class AddBudget extends StatefulWidget {
  const AddBudget({super.key});

  @override
  State<AddBudget> createState() => _AddBudgetState();
}

class _AddBudgetState extends State<AddBudget> {
  final _formKey = GlobalKey<FormState>();
  final _cashAmountController = TextEditingController();
  String? _selectedDate;
  String? _mode = 'Cash';
  final List<Map<String, dynamic>> _bankInputs = [];

  @override
  void initState() {
    super.initState();
    _addBankField();
    _syncPendingBudgets();
  }

  void _addBankField() {
    setState(() {
      _bankInputs.add({
        'bank': TextEditingController(),
        'amount': TextEditingController(),
        'amountKey': GlobalKey<FormFieldState>(),
      });
    });
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

  Future<void> _saveBudget() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You must be logged in")));
      return;
    }

    final date =
        _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    bool entrySaved = false;

    try {
      if (_mode == 'Cash') {
        if (_formKey.currentState!.validate()) {
          final amount = double.tryParse(_cashAmountController.text) ?? 0.0;
          if (amount > 0) {
            final localData = {
              'date': date,
              'mode': 'Cash',
              'total': amount,
              'bank': '',
              'is_synced': 0,
            };
            final id = await DatabaseHelper.instance.insertBudget(localData);

            if (await _hasInternetConnection()) {
              await supabase.from('budgets').insert({
                'user_id': user.id,
                'date': date,
                'mode': 'Cash',
                'total': amount,
                'category': null,
              });
              await DatabaseHelper.instance.markBudgetAsSynced(id);
            }

            entrySaved = true;
          }
        }
      } else {
        bool allValid = true;
        for (var bankInput in _bankInputs) {
          final fieldKey = bankInput['amountKey'] as GlobalKey<FormFieldState>;
          if (!(fieldKey.currentState?.validate() ?? false)) {
            allValid = false;
          }
        }
        if (!allValid) return;

        for (var bankInput in _bankInputs) {
          final bankName = bankInput['bank'].text.trim();
          final amount = double.tryParse(bankInput['amount'].text) ?? 0.0;
          if (amount > 0) {
            final localData = {
              'date': date,
              'mode': 'Online',
              'total': amount,
              'bank': bankName,
              'is_synced': 0,
            };
            final id = await DatabaseHelper.instance.insertBudget(localData);

            if (await _hasInternetConnection()) {
              await supabase.from('budgets').insert({
                'user_id': user.id,
                'date': date,
                'mode': 'Online',
                'total': amount,
                'category': bankName.isNotEmpty ? bankName : null,
              });
              await DatabaseHelper.instance.markBudgetAsSynced(id);
            }

            entrySaved = true;
          }
        }
      }

      if (entrySaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Budget entry saved (Synced if online) ✅"),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please enter at least one valid amount"),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving budget: $error")));
    }
  }

  Future<void> _syncPendingBudgets() async {
    final hasConnection = await _hasInternetConnection();
    if (!hasConnection) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedBudgets();
    for (final b in unsynced) {
      try {
        await supabase.from('budgets').insert({
          'user_id': user.id,
          'date': b['date'],
          'mode': b['mode'],
          'total': b['total'],
          'category': b['bank']?.toString().isEmpty ?? true ? null : b['bank'],
          'created_at': DateTime.now().toIso8601String(),
        });
        await DatabaseHelper.instance.markBudgetAsSynced(b['id']);
      } catch (e) {
        debugPrint('Budget sync error for ${b['id']}: $e');
      }
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Widget _buildOnlineBankField() {
    return Column(
      children: [
        ..._bankInputs.asMap().entries.map((entry) {
          final index = entry.key;
          final controllers = entry.value;

          return Column(
            children: [
              TextFormField(
                controller: controllers['bank'],
                decoration: const InputDecoration(
                  labelText: 'Bank Name (optional)',
                ),
              ),
              TextFormField(
                key: controllers['amountKey'],
                controller: controllers['amount'],
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter amount';
                  final amount = double.tryParse(val);
                  if (amount == null || amount <= 0)
                    return 'Enter valid amount > 0';
                  return null;
                },
              ),
              const Divider(),
            ],
          );
        }),
        ElevatedButton.icon(
          onPressed: _addBankField,
          icon: const Icon(Icons.add),
          label: const Text('Add Another Bank'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Budget'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_selectedDate ?? 'Select Date'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _mode,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Online', child: Text('Online')),
                ],
                onChanged: (value) {
                  setState(() {
                    _mode = value!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Budget Mode'),
              ),
              const SizedBox(height: 16),
              if (_mode == 'Cash')
                TextFormField(
                  controller: _cashAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cash Amount'),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(val);
                    if (amount == null || amount <= 0)
                      return 'Enter valid amount > 0';
                    return null;
                  },
                )
              else
                _buildOnlineBankField(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveBudget,
                child: const Text('Save Budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
