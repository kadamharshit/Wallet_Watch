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

    _loadExistingItems();

    final amount = (exp['total'] as num?)?.toDouble() ?? 0.0;
    total = amount;

    _updateTotal();
  }

  void _loadExistingItems() {
    final raw = (widget.expense['items'] ?? '').toString().trim();

    if (raw.isEmpty) {
      itemInputs = [{}];
      return;
    }

    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          itemInputs = decoded.map<Map<String, String>>((e) {
            final map = Map<String, dynamic>.from(e);

            if (_category == 'Travel') {
              return {
                "mode": (map["mode"] ?? "").toString(),
                "start": (map["start"] ?? "").toString(),
                "destination": (map["destination"] ?? "").toString(),
                "amount": (map["amount"] ?? "").toString(),
              };
            }

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
      } catch (_) {}
    }

    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (_category == 'Travel') {
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

  void _updateTotal() {
    total = itemInputs.fold(0.0, (sum, i) {
      return sum + (double.tryParse(i['amount'] ?? '0') ?? 0);
    });
    if (mounted) setState(() {});
  }

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
      'items': _buildItemsJson(),
      'total': total,
      'mode': _mode,
      'bank': _mode == 'Online' ? _bankController.text.trim() : '',
    };

    try {
      final localId = widget.expense['id'] as int?;
      if (localId != null) {
        await DatabaseHelper.instance.updateExpense(localId, updatedExpense);
      }

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
        ).showSnackBar(const SnackBar(content: Text('Expense updated')));
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

  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF6F6F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _sectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              "Edit Expense",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.edit_note, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildItemFields(int index) {
    final item = itemInputs[index];
    final isTravel = _category == "Travel";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Item ${index + 1}",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (itemInputs.length > 1)
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isTravel) ...[
            TextFormField(
              initialValue: item["mode"],
              decoration: _pillDecoration(
                hint: "Mode",
                icon: Icons.directions_bus_outlined,
              ),
              onChanged: (val) => item["mode"] = val,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? "Enter mode" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item["start"],
              decoration: _pillDecoration(
                hint: "From",
                icon: Icons.location_on_outlined,
              ),
              onChanged: (val) => item["start"] = val,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? "Enter start" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item["destination"],
              decoration: _pillDecoration(
                hint: "To",
                icon: Icons.flag_outlined,
              ),
              onChanged: (val) => item["destination"] = val,
              validator: (val) => val == null || val.trim().isEmpty
                  ? "Enter destination"
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item["amount"],
              decoration: _pillDecoration(
                hint: "Amount",
                icon: Icons.currency_rupee,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              decoration: _pillDecoration(
                hint: "Item Name",
                icon: Icons.shopping_bag_outlined,
              ),
              onChanged: (val) => item["name"] = val,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? "Enter item name" : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: item["qty"],
                    decoration: _pillDecoration(
                      hint: "Qty",
                      icon: Icons.numbers,
                    ),
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
                    value: (_units.contains(item["unit"]))
                        ? item["unit"]
                        : "pcs",
                    decoration: _pillDecoration(
                      hint: "Unit",
                      icon: Icons.straighten,
                    ),
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
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item["amount"],
              decoration: _pillDecoration(
                hint: "Amount",
                icon: Icons.currency_rupee,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _shopController.dispose();
    _bankController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTravel = _category == "Travel";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 18),
                  children: [
                    _sectionContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Expense Details",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),

                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(30),
                            child: IgnorePointer(
                              child: TextFormField(
                                controller: _dateController,
                                decoration: _pillDecoration(
                                  hint: "Date",
                                  icon: Icons.calendar_today_outlined,
                                  suffixIcon: const Icon(
                                    Icons.edit_calendar_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _shopController,
                            decoration: _pillDecoration(
                              hint: "Shop Name / Type",
                              icon: Icons.storefront_outlined,
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Enter shop name'
                                : null,
                          ),

                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _category,
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;

                              setState(() {
                                _category = val;

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
                                    {
                                      "name": "",
                                      "qty": "",
                                      "unit": "pcs",
                                      "amount": "",
                                    },
                                  ];
                                }

                                _updateTotal();
                              });
                            },
                            decoration: _pillDecoration(
                              hint: "Category",
                              icon: Icons.category_outlined,
                            ),
                          ),

                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: _mode,
                            items: _modes
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _mode = val;
                                if (_mode == 'Cash') _bankController.clear();
                              });
                            },
                            decoration: _pillDecoration(
                              hint: "Paid By",
                              icon: Icons.payments_outlined,
                            ),
                          ),

                          if (_mode == 'Online') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _bankController,
                              decoration: _pillDecoration(
                                hint: "Bank (optional)",
                                icon: Icons.account_balance_outlined,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    _sectionContainer(
                      child: Row(
                        children: [
                          const Text(
                            "Total",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "₹${total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Text(
                        isTravel ? "Travel Entries" : "Items",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    _sectionContainer(
                      child: Column(
                        children: [
                          ...List.generate(
                            itemInputs.length,
                            (index) => _buildItemFields(index),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add),
                              label: Text(
                                isTravel
                                    ? "Add Another Trip"
                                    : "Add Another Item",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(
                                  color: Colors.blue,
                                  width: 1.3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
