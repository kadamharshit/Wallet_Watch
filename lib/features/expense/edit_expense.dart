import 'dart:convert';

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
  late TextEditingController _dateController;

  String _category = 'Grocery';
  String _mode = 'Cash';

  final TextEditingController _bankController = TextEditingController();

  bool _saving = false;

  double total = 0.0;

  // ✅ Item inputs (Works for both normal + travel)
  List<Map<String, String>> itemInputs = [{}];

  final List<String> _categories = const [
    'Grocery',
    'Travel',
    'Food',
    'Medical',
    'Bills',
    'Other',
  ];

  final List<String> _modes = const ['Cash', 'Online'];

  // ✅ Units (for qty better than only "1")
  final List<String> _units = const [
    'pcs',
    'kg',
    'g',
    'L',
    'ml',
    'dozen',
    'packet',
    'bottle',
    'box',
    'other',
  ];

  // ---------------- INIT ----------------
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

    final category = (exp['category'] ?? 'Grocery').toString();
    if (_categories.contains(category)) _category = category;

    final mode = (exp['mode'] ?? 'Cash').toString();
    if (_modes.contains(mode)) _mode = mode;

    _bankController.text = (exp['bank'] ?? '').toString();

    // ✅ Load items into fields
    _loadExistingItems();

    // ✅ Load total
    final amount = (exp['total'] as num?)?.toDouble() ?? 0.0;
    total = amount;

    // ✅ if items have proper amounts, recompute
    _updateTotal();
  }

  // ---------------- ITEMS PARSING ----------------
  void _loadExistingItems() {
    final raw = (widget.expense['items'] ?? '').toString().trim();

    if (raw.isEmpty) {
      itemInputs = [{}];
      return;
    }

    // ✅ If JSON array saved
    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          itemInputs = decoded.map<Map<String, String>>((e) {
            final map = Map<String, dynamic>.from(e);

            // Travel fields
            if (_category == 'Travel') {
              return {
                "mode": (map["mode"] ?? "").toString(),
                "start": (map["start"] ?? "").toString(),
                "destination": (map["destination"] ?? "").toString(),
                "amount": (map["amount"] ?? "").toString(),
              };
            }

            // Normal items
            return {
              "name": (map["name"] ?? "").toString(),
              "qty": (map["qty"] ?? "").toString(),
              "unit": (map["unit"] ?? "pcs").toString(),
              "amount": (map["amount"] ?? "").toString(),
            };
          }).toList();

          if (itemInputs.isEmpty) itemInputs = [{}];
          return;
        }
      } catch (_) {
        // If broken json -> fallback to old format
      }
    }

    // ✅ Old format: lines "Milk | 1 | 29"
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (_category == 'Travel') {
      // "Mode | From | To | Amount"
      itemInputs = lines.map((line) {
        final parts = line.split('|').map((e) => e.trim()).toList();
        return {
          "mode": parts.isNotEmpty ? parts[0] : "",
          "start": parts.length > 1 ? parts[1] : "",
          "destination": parts.length > 2 ? parts[2] : "",
          "amount": parts.length > 3 ? parts[3] : "",
        };
      }).toList();
    } else {
      // "Name | Qty | Amount"
      itemInputs = lines.map((line) {
        final parts = line.split('|').map((e) => e.trim()).toList();
        return {
          "name": parts.isNotEmpty ? parts[0] : "",
          "qty": parts.length > 1 ? parts[1] : "",
          "unit": "pcs",
          "amount": parts.length > 2 ? parts[2] : "",
        };
      }).toList();
    }

    if (itemInputs.isEmpty) itemInputs = [{}];
  }

  // ---------------- TOTAL ----------------
  void _updateTotal() {
    total = itemInputs.fold(0.0, (sum, i) {
      return sum + (double.tryParse(i['amount'] ?? '0') ?? 0);
    });
    if (mounted) setState(() {});
  }

  // ---------------- ADD/REMOVE ITEM ----------------
  void _addItem() {
    setState(() {
      if (_category == "Travel") {
        itemInputs.add({
          "mode": "",
          "start": "",
          "destination": "",
          "amount": "",
        });
      } else {
        itemInputs.add({"name": "", "qty": "", "unit": "pcs", "amount": ""});
      }
    });
  }

  void _removeItem(int index) {
    if (itemInputs.length == 1) return;
    setState(() {
      itemInputs.removeAt(index);
      _updateTotal();
    });
  }

  // ---------------- DATE PICKER ----------------
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
      setState(() => _dateController.text = _dateString);
    }
  }

  // ---------------- JSON SAVE FORMAT ----------------
  String _buildItemsJson() {
    final list = itemInputs.map((i) {
      if (_category == "Travel") {
        return {
          "mode": i["mode"] ?? "",
          "start": i["start"] ?? "",
          "destination": i["destination"] ?? "",
          "amount": double.tryParse(i["amount"] ?? "0") ?? 0.0,
        };
      } else {
        return {
          "name": i["name"] ?? "",
          "qty": double.tryParse(i["qty"] ?? "0") ?? 0.0,
          "unit": i["unit"] ?? "pcs",
          "amount": double.tryParse(i["amount"] ?? "0") ?? 0.0,
        };
      }
    }).toList();

    return jsonEncode(list);
  }

  // ---------------- SAVE ----------------
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total must be greater than 0')),
      );
      return;
    }

    setState(() => _saving = true);

    final updatedExpense = {
      'date': _dateString,
      'shop': _shopController.text.trim(),
      'category': _category,
      'items': _buildItemsJson(), // ✅ JSON saved
      'total': total,
      'mode': _mode,
      'bank': _mode == 'Online' ? _bankController.text.trim() : '',
    };

    try {
      // ✅ Update local SQLite
      final localId = widget.expense['id'] as int?;
      if (localId != null) {
        await DatabaseHelper.instance.updateExpense(localId, updatedExpense);
      }

      // ✅ Update Supabase (best effort)
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        final remoteId = widget.expense['supabase_id'];
        final uuid = widget.expense['uuid'];

        final dataForSupabase = {
          'date': updatedExpense['date'],
          'shop': updatedExpense['shop'],
          'category': updatedExpense['category'],
          'items': updatedExpense['items'],
          'total': updatedExpense['total'],
          'mode': updatedExpense['mode'],
          'bank': (_mode == "Online" && _bankController.text.trim().isNotEmpty)
              ? _bankController.text.trim()
              : null,
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

  // ---------------- ITEM UI ----------------
  Widget _buildItemFields(int index) {
    final item = itemInputs[index];

    final isTravel = _category == "Travel";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Item ${index + 1}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (itemInputs.length > 1)
              IconButton(
                onPressed: () => _removeItem(index),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
          ],
        ),

        if (isTravel) ...[
          TextFormField(
            initialValue: item["mode"],
            decoration: const InputDecoration(labelText: "Mode"),
            onChanged: (val) => item["mode"] = val,
            validator: (val) =>
                val == null || val.trim().isEmpty ? "Enter mode" : null,
          ),
          TextFormField(
            initialValue: item["start"],
            decoration: const InputDecoration(labelText: "From"),
            onChanged: (val) => item["start"] = val,
            validator: (val) =>
                val == null || val.trim().isEmpty ? "Enter start" : null,
          ),
          TextFormField(
            initialValue: item["destination"],
            decoration: const InputDecoration(labelText: "To"),
            onChanged: (val) => item["destination"] = val,
            validator: (val) =>
                val == null || val.trim().isEmpty ? "Enter destination" : null,
          ),
          TextFormField(
            initialValue: item["amount"],
            decoration: const InputDecoration(labelText: "Amount"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              item["amount"] = val;
              _updateTotal();
            },
            validator: (val) {
              final a = double.tryParse(val ?? "");
              if (a == null || a <= 0) return "Enter valid amount";
              return null;
            },
          ),
        ] else ...[
          TextFormField(
            initialValue: item["name"],
            decoration: const InputDecoration(labelText: "Item Name"),
            onChanged: (val) => item["name"] = val,
            validator: (val) =>
                val == null || val.trim().isEmpty ? "Enter item name" : null,
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item["qty"],
                  decoration: const InputDecoration(labelText: "Qty"),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) => item["qty"] = val,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? "Enter qty" : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: (_units.contains(item["unit"])) ? item["unit"] : "pcs",
                  decoration: const InputDecoration(labelText: "Unit"),
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      item["unit"] = val ?? "pcs";
                    });
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: item["amount"],
            decoration: const InputDecoration(labelText: "Amount"),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              item["amount"] = val;
              _updateTotal();
            },
            validator: (val) {
              final a = double.tryParse(val ?? "");
              if (a == null || a <= 0) return "Enter valid amount";
              return null;
            },
          ),
        ],

        const SizedBox(height: 12),
        const Divider(),
      ],
    );
  }

  // ---------------- DISPOSE ----------------
  @override
  void dispose() {
    _shopController.dispose();
    _bankController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final isTravel = _category == "Travel";

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
                  if (val == null) return;

                  setState(() {
                    _category = val;

                    // ✅ Reset item fields structure when category changes
                    if (_category == "Travel") {
                      itemInputs = [
                        {
                          "mode": "",
                          "start": "",
                          "destination": "",
                          "amount": "",
                        },
                      ];
                    } else {
                      itemInputs = [
                        {"name": "", "qty": "", "unit": "pcs", "amount": ""},
                      ];
                    }

                    _updateTotal();
                  });
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
                  if (val == null) return;
                  setState(() {
                    _mode = val;
                    if (_mode == 'Cash') _bankController.clear();
                  });
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

              const SizedBox(height: 16),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        "₹${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                isTravel ? "Travel Entries" : "Items",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              ...List.generate(
                itemInputs.length,
                (index) => _buildItemFields(index),
              ),

              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: Text(isTravel ? "Add Another Trip" : "Add Another Item"),
              ),

              const SizedBox(height: 18),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveChanges,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
