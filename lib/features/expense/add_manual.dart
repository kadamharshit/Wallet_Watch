import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:walletwatch/services/expense_database.dart';
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

  bool _showItemsSection = false;

  List<Map<String, String>> itemInputs = [{}];
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

  // ✅ Recent travel templates
  List<Map<String, dynamic>> _recentTravels = [];

  // ✅ Controllers for Travel Autofill (fix for initialValue issue)
  final _travelModeController = TextEditingController();
  final _travelStartController = TextEditingController();
  final _travelDestController = TextEditingController();
  final _travelAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAvailableBanks();
    _syncPendingExpenses();
    _loadRecentTravels();
  }

  // ---------------- NETWORK ----------------
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------- BANKS ----------------
  Future<void> _fetchAvailableBanks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final budgets = await DatabaseHelper.instance.getBudget();

    final banks = budgets
        .where((b) => b['mode'] == 'Online')
        .map((b) => (b['bank'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _availableBanks = banks;
      if (banks.isNotEmpty) _selectedBank = banks.first;
    });
  }

  // ---------------- ITEMS ----------------
  void _addItem() => setState(() => itemInputs.add({}));

  void _removeItem(int index) {
    if (itemInputs.length == 1) return;
    setState(() {
      itemInputs.removeAt(index);
      _updateTotal();
    });
  }

  void _updateTotal() {
    total = itemInputs.fold(
      0.0,
      (sum, i) => sum + (double.tryParse(i['amount'] ?? '0') ?? 0),
    );
    setState(() {});
  }

  // ---------------- SYNC ----------------
  Future<void> _syncPendingExpenses() async {
    if (!await _hasInternetConnection()) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses();

    for (final exp in unsynced) {
      try {
        final res = await supabase
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
              'bank': (exp['bank'] as String?)?.isNotEmpty == true
                  ? exp['bank']
                  : null,
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateExpense(exp['id'], {
          'supabase_id': res['id'],
          'synced': 1,
        });
      } catch (_) {}
    }
  }

  // ---------------- RECENT TRAVEL ----------------
  Future<void> _loadRecentTravels() async {
    final data = await DatabaseHelper.instance.getRecentTravelExpenses(
      limit: 5,
    );
    setState(() {
      _recentTravels = data;
    });
  }

  // ---------------- APPLY TRAVEL TEMPLATE ----------------
  void _applyTravelTemplate(Map<String, dynamic> exp) {
    final itemsRaw = (exp['items'] ?? '').toString().trim();

    String tMode = '';
    String tStart = '';
    String tDest = '';

    if (itemsRaw.isNotEmpty) {
      final firstLine = itemsRaw.split('\n').first;
      final parts = firstLine.split('|').map((e) => e.trim()).toList();

      if (parts.length >= 3) {
        tMode = parts[0];
        tStart = parts[1];
        tDest = parts[2];
      }
    }

    setState(() {
      _selectedCategory = "Travel";
      _shopController.text = (exp['shop'] ?? '').toString();

      _selectedPaymentMode = (exp['mode'] ?? 'Cash').toString();

      _selectedBank = (exp['bank'] ?? '').toString().isNotEmpty
          ? exp['bank']
          : null;

      // ✅ Autofill travel controllers
      _travelModeController.text = tMode;
      _travelStartController.text = tStart;
      _travelDestController.text = tDest;
      _travelAmountController.clear();

      // ✅ Update itemInputs too
      itemInputs = [
        {"mode": tMode, "start": tStart, "destination": tDest, "amount": ""},
      ];

      total = 0.0;
      _showItemsSection = true;
    });
  }

  // ---------------- SAVE ----------------
  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Total must be greater than 0")),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final date =
        _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    final uuid = const Uuid().v4();

    // ✅ Ensure travel data is saved from controllers
    if (_selectedCategory == "Travel") {
      itemInputs[0]["mode"] = _travelModeController.text.trim();
      itemInputs[0]["start"] = _travelStartController.text.trim();
      itemInputs[0]["destination"] = _travelDestController.text.trim();
      itemInputs[0]["amount"] = _travelAmountController.text.trim();
    }

    final localExpense = {
      'uuid': uuid,
      'date': date,
      'shop': _shopController.text.trim(),
      'category': _selectedCategory,
      'items': itemInputs
          .map((i) {
            if (_selectedCategory == 'Travel') {
              return [
                i['mode'] ?? '',
                i['start'] ?? '',
                i['destination'] ?? '',
                i['amount'] ?? '0',
              ].join(' | ');
            } else {
              return [
                i['name'] ?? '',
                i['qty'] ?? '',
                i['amount'] ?? '0',
              ].join(' | ');
            }
          })
          .join('\n'),
      'total': total,
      'mode': _selectedPaymentMode,
      'bank': _selectedPaymentMode == 'Online' ? _selectedBank ?? '' : '',
      'synced': 0,
      'supabase_id': null,
    };

    final localId = await DatabaseHelper.instance.insertExpense(localExpense);

    if (await _hasInternetConnection()) {
      try {
        final res = await supabase
            .from('expenses')
            .insert({
              'uuid': uuid,
              'user_id': user.id,
              'date': date,
              'shop': localExpense['shop'],
              'category': localExpense['category'],
              'items': localExpense['items'],
              'total': total,
              'mode': localExpense['mode'],
              'bank': localExpense['bank'].toString().isNotEmpty
                  ? localExpense['bank']
                  : null,
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateExpense(localId, {
          'supabase_id': res['id'],
          'synced': 1,
        });
      } catch (e) {
        debugPrint("Supabase insert failed, saved offline: $e");
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Expense saved ✅")));

    Navigator.pushReplacementNamed(context, '/home');
  }

  // ---------------- DATE ----------------
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

  // ---------------- UI HELPERS ----------------
  Widget _sectionCard({required Widget child}) => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _buildItemFields(int index) {
    final item = itemInputs[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Item ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (itemInputs.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
          ],
        ),

        // ✅ Travel Fields with controllers
        if (_selectedCategory == 'Travel') ...[
          TextFormField(
            controller: _travelModeController,
            decoration: const InputDecoration(labelText: 'Mode'),
            onChanged: (val) => item['mode'] = val,
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter travel mode' : null,
          ),
          TextFormField(
            controller: _travelStartController,
            decoration: const InputDecoration(labelText: 'Start'),
            onChanged: (val) => item['start'] = val,
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter start point' : null,
          ),
          TextFormField(
            controller: _travelDestController,
            decoration: const InputDecoration(labelText: 'Destination'),
            onChanged: (val) => item['destination'] = val,
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter destination' : null,
          ),
          TextFormField(
            controller: _travelAmountController,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              item['amount'] = val;
              _updateTotal();
            },
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter amount' : null,
          ),
        ]
        // ✅ Other Categories
        else ...[
          TextFormField(
            decoration: const InputDecoration(labelText: 'Item Name'),
            initialValue: item['name'],
            onSaved: (val) => item['name'] = val ?? '',
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter item name' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Quantity'),
            initialValue: item['qty'],
            onSaved: (val) => item['qty'] = val ?? '',
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter quantity' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: TextInputType.number,
            initialValue: item['amount'],
            onChanged: (val) {
              item['amount'] = val;
              _updateTotal();
            },
            onSaved: (val) => item['amount'] = val ?? '0',
            validator: (val) =>
                val == null || val.isEmpty ? 'Enter amount' : null,
          ),
        ],

        const SizedBox(height: 12),
        const Divider(thickness: 1),
      ],
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Date + Shop
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Date",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_selectedDate ?? 'Select date'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // ✅ Category + Payment
              const SizedBox(height: 10),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Category & Payment",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField(
                      value: _selectedCategory,
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                          itemInputs = [{}];
                          total = 0.0;
                          _showItemsSection = true;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField(
                      value: _selectedPaymentMode,
                      items: _paymentModes
                          .map(
                            (mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(mode),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMode = value!;
                          _showItemsSection = true;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Paid By'),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedPaymentMode == 'Online' &&
                        _availableBanks.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedBank,
                        items: _availableBanks
                            .map(
                              (bank) => DropdownMenuItem(
                                value: bank,
                                child: Text(bank),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedBank = val;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Select Bank',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Shop Name/Type",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _shopController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name / Type',
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter shop name' : null,
                    ),
                  ],
                ),
              ),

              // ✅ Recent Travel Chips (only for Travel category)
              if (_selectedCategory == 'Travel' &&
                  _recentTravels.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  "Recent Travel",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _recentTravels.map((t) {
                    final shop = (t['shop'] ?? '').toString();
                    return ActionChip(
                      label: Text(shop.isEmpty ? "Travel" : shop),
                      onPressed: () => _applyTravelTemplate(t),
                    );
                  }).toList(),
                ),
              ],

              // ✅ Items Section (shows after selection)
              if (_showItemsSection) ...[
                const SizedBox(height: 10),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Items",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        itemInputs.length,
                        (index) => _buildItemFields(index),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 16)),
                            const Spacer(),
                            Text(
                              "₹${total.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text("Add Another Item"),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveExpense,
                  child: const Text(
                    "Save Expense",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shopController.dispose();
    _travelModeController.dispose();
    _travelStartController.dispose();
    _travelDestController.dispose();
    _travelAmountController.dispose();
    super.dispose();
  }
}
