import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';

class EditExpensePage extends StatefulWidget {
  final Map<String, dynamic> expense;

  const EditExpensePage({super.key, required this.expense});

  @override
  State<EditExpensePage> createState() => _EditExpensePageState();
}

class _EditExpensePageState extends State<EditExpensePage> {
  final _formKey = GlobalKey<FormState>();

  late String _dateString;
  late TextEditingController _shopController;
  late TextEditingController _itemsController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;

  String _category = 'Grocery';
  String _mode = 'Cash';
  final TextEditingController _bankController = TextEditingController();

  bool _saving = false;

  final List<String> _categories = const [
    'Grocery',
    'Travel',
    'Food',
    'Medical',
    'Bills',
    'Other',
  ];

  final List<String> _modes = const ['Cash', 'Online'];

  @override
  void initState() {
    super.initState();

    final exp = widget.expense;

    _dateString =
        (exp['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()))
            .toString();

    _dateController = TextEditingController(text: _dateString);

    _shopController = TextEditingController(
      text: (exp['shop'] ?? '').toString(),
    );

    _itemsController = TextEditingController(
      text: (exp['items'] ?? '').toString(),
    );

    final category = (exp['category'] ?? 'Grocery').toString();
    if (_categories.contains(category)) {
      _category = category;
    }

    final mode = (exp['mode'] ?? 'Cash').toString();
    if (_modes.contains(mode)) {
      _mode = mode;
    }

    final amount = (exp['total'] as num?)?.toDouble() ?? 0.0;
    _amountController = TextEditingController(text: amount.toStringAsFixed(2));

    _bankController.text = (exp['bank'] ?? '').toString();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateString) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _dateString = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _dateController.text = _dateString;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _saving = true);

    final updatedExpense = {
      'date': _dateString,
      'shop': _shopController.text.trim(),
      'category': _category,
      'items': _itemsController.text.trim(),
      'total': amount,
      'mode': _mode,
      'bank': _mode == 'Online' ? _bankController.text.trim() : '',
    };

    try {
      // 1️⃣ Update local SQLite
      final localId = widget.expense['id'] as int?;
      if (localId != null) {
        await DatabaseHelper.instance.updateExpense(localId, updatedExpense);
      }

      // 2️⃣ Best-effort update Supabase
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        final remoteId = widget.expense['supabase_id'];
        final uuid = widget.expense['uuid'];

        final dataForSupabase = {
          'date': _dateString,
          'shop': updatedExpense['shop'],
          'category': _category,
          'items': updatedExpense['items'],
          'total': amount,
          'mode': _mode,
          'bank': _mode == 'Online' ? _bankController.text.trim() : null,
        };

        if (remoteId != null) {
          await supabase
              .from('expenses')
              .update(dataForSupabase)
              .eq('id', remoteId)
              .eq('user_id', user.id);
        } else if (uuid != null) {
          await supabase
              .from('expenses')
              .update(dataForSupabase)
              .eq('uuid', uuid)
              .eq('user_id', user.id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense updated ✅')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Edit error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update expense: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _shopController.dispose();
    _itemsController.dispose();
    _amountController.dispose();
    _bankController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              InkWell(
                onTap: _pickDate,
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _shopController,
                decoration: const InputDecoration(
                  labelText: 'Shop Name / Type',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Enter shop name'
                    : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _category,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _mode,
                items: _modes
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _mode = val;
                      if (_mode == 'Cash') _bankController.clear();
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Paid By'),
              ),

              if (_mode == 'Online') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankController,
                  decoration: const InputDecoration(
                    labelText: 'Bank (optional)',
                  ),
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _itemsController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Items (raw text)',
                  helperText:
                      'Each line can be "name | qty | amount" or any text you used earlier.',
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _saveChanges,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
