import 'dart:io';
import 'package:uuid/uuid.dart';
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
  String _mode = 'Cash';

  final List<Map<String, dynamic>> _bankInputs = [];

  @override
  void initState() {
    super.initState();
    _addBankField();
    _syncPendingBudgets();
  }

  void _addBankField() {
    _bankInputs.add({
      'bank': TextEditingController(),
      'amount': TextEditingController(),
      'amountKey': GlobalKey<FormFieldState>(),
    });
    setState(() {});
  }

  void _removeBankField(int index) {
    if (_bankInputs.length == 1) return;
    _bankInputs.removeAt(index);
    setState(() {});
  }

  double get _onlineTotal {
    double sum = 0.0;
    for (var b in _bankInputs) {
      sum += double.tryParse(b['amount'].text) ?? 0.0;
    }
    return sum;
  }

  bool _hasDuplicateBanks() {
    final names = _bankInputs
        .map((b) => b['bank'].text.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    return names.length != names.toSet().length;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  Future<void> _saveBudget() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    if (_mode == 'Online' && _hasDuplicateBanks()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Each bank name must be unique")),
      );
      return;
    }

    final date =
        _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    bool saved = false;

    try {
      if (_mode == 'Cash') {
        if (!_formKey.currentState!.validate()) return;

        final amount = double.tryParse(_cashAmountController.text) ?? 0.0;
        if (amount <= 0) return;

        final uuid = const Uuid().v4();

        final localId = await DatabaseHelper.instance.insertBudget({
          //'user_id': user.id,
          'uuid': uuid,
          'date': date,
          'mode': 'Cash',
          'total': amount,
          'bank': '',
          'synced': 0,
          'supabase_id': null,
        });

        if (await _hasInternetConnection()) {
          final res = await supabase
              .from('budgets')
              .insert({
                'uuid': uuid,
                'user_id': user.id,
                'date': date,
                'mode': 'Cash',
                'total': amount,
              })
              .select('id')
              .single();

          await DatabaseHelper.instance.updateBudget(localId, {
            'supabase_id': res['id'],
            'synced': 1,
          });
        }

        saved = true;
      } else {
        for (var b in _bankInputs) {
          final key = b['amountKey'] as GlobalKey<FormFieldState>;
          if (!(key.currentState?.validate() ?? false)) return;
        }

        for (var b in _bankInputs) {
          final bankName = b['bank'].text.trim();
          final amount = double.tryParse(b['amount'].text) ?? 0.0;
          if (amount <= 0) continue;

          final uuid = const Uuid().v4();

          final localId = await DatabaseHelper.instance.insertBudget({
            //'user_id': user.id,
            'uuid': uuid,
            'date': date,
            'mode': 'Online',
            'total': amount,
            'bank': bankName,
            'synced': 0,
            'supabase_id': null,
          });

          if (await _hasInternetConnection()) {
            final res = await supabase
                .from('budgets')
                .insert({
                  'uuid': uuid,
                  'user_id': user.id,
                  'date': date,
                  'mode': 'Online',
                  'total': amount,
                  'bank': bankName,
                })
                .select('id')
                .single();

            await DatabaseHelper.instance.updateBudget(localId, {
              'supabase_id': res['id'],
              'synced': 1,
            });
          }

          saved = true;
        }
      }

      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Budget saved successfully ✅")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _syncPendingBudgets() async {
    if (!await _hasInternetConnection()) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedBudgets();

    for (final b in unsynced) {
      try {
        final res = await supabase
            .from('budgets')
            .insert({
              'uuid': b['uuid'],
              'user_id': user.id,
              'date': b['date'],
              'mode': b['mode'],
              'total': b['total'],
              'bank': b['bank'],
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateBudget(b['id'], {
          'supabase_id': res['id'],
          'synced': 1,
        });
      } catch (_) {}
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final res = await InternetAddress.lookup('example.com');
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildOnlineBankField() {
    return Column(
      children: [
        ..._bankInputs.asMap().entries.map((entry) {
          final index = entry.key;
          final c = entry.value;

          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: c['bank'],
                      decoration: const InputDecoration(labelText: 'Bank Name'),
                    ),
                  ),
                  if (_bankInputs.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeBankField(index),
                    ),
                ],
              ),
              TextFormField(
                key: c['amountKey'],
                controller: c['amount'],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (v) {
                  final amt = double.tryParse(v ?? '');
                  if (amt == null || amt <= 0) return 'Enter valid amount';
                  return null;
                },
                onChanged: (_) => setState(() {}),
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
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _sectionCard(
                child: Column(
                  children: [
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_selectedDate ?? 'Select Date'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField(
                      value: _mode,
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'Online',
                          child: Text('Online'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _mode = v!),
                      decoration: const InputDecoration(
                        labelText: 'Budget Mode',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _mode == 'Cash'
                  ? _sectionCard(
                      child: TextFormField(
                        controller: _cashAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cash Amount',
                        ),
                        validator: (v) {
                          final amt = double.tryParse(v ?? '');
                          if (amt == null || amt <= 0) {
                            return 'Enter valid amount';
                          }
                          return null;
                        },
                      ),
                    )
                  : _sectionCard(child: _buildOnlineBankField()),
              if (_mode == 'Online')
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('Total Budget'),
                      const Spacer(),
                      Text(
                        '₹${_onlineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveBudget,
                  child: const Text('Save Budget'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
