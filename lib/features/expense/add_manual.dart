import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:walletwatch/services/expense_database.dart';
import 'package:uuid/uuid.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddManualExpense extends StatefulWidget {
  const AddManualExpense({super.key});

  @override
  State<AddManualExpense> createState() => _AddManualExpenseState();
}

class _AddManualExpenseState extends State<AddManualExpense> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedDate;
  final _shopController = TextEditingController();

  bool _isSaving = false;

  String _selectedCategory = 'Grocery';
  String _selectedPaymentMode = 'Cash';

  bool _showItemsSection = false;

  final List<String> _units = ['pcs', 'kg', 'g', 'L', 'ml'];
  List<Map<String, dynamic>> itemInputs = [
    {"name": "", "qty": "", "unit": "pcs", "amount": ""},
  ];
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

  final List<String> _travelModes = [
    "Bus",
    "Train",
    "Metro",
    "Rickshaw",
    "Taxi",
    "Flight",
    "Ferry",
    "Other",
  ];

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  final List<String> _paymentModes = ['Cash', 'Online'];

  List<Map<String, dynamic>> _recentTravels = [];

  final _travelModeController = TextEditingController();
  final _travelStartController = TextEditingController();
  final _travelDestController = TextEditingController();
  final _travelAmountController = TextEditingController();

  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _paymentKey = GlobalKey();
  final GlobalKey _bankKey = GlobalKey();
  final GlobalKey _shopKey = GlobalKey();
  final GlobalKey _itemsKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _addExpenseTourDoneKey =
      "walletwatch_add_expense_tour_done";

  static const String _addExpenseOnlineBankTourDoneKey =
      "walletwatch_add_expense_online_bank_tour_done";

  @override
  void initState() {
    super.initState();
    _fetchAvailableBanks();
    _syncPendingExpenses();
    _loadMostUsedTravels();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAddExpenseTourOnlyOnce();
    });
  }

  Future<void> _loadMostUsedTravels() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final expenses = await DatabaseHelper.instance.getExpenses(user.id);

    final Map<String, Map<String, dynamic>> freqMap = {};

    for (final e in expenses) {
      if (e['category'] != 'Travel') continue;

      final raw = (e['items'] ?? '').toString();
      if (raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);

        if (decoded is List && decoded.isNotEmpty) {
          final item = decoded.first;

          final key =
              "${e['shop']}|${item['start']}|${item['destination']}|${e['mode']}";

          if (!freqMap.containsKey(key)) {
            freqMap[key] = {'count': 1, 'expense': e, 'item': item};
          } else {
            freqMap[key]!['count']++;
          }
        }
      } catch (_) {}
    }

    final filtered = freqMap.values.where((e) => e['count'] >= 2).toList()
      ..sort((a, b) => b['count'].compareTo(a['count']));

    setState(() {
      _recentTravels = filtered.take(5).map<Map<String, dynamic>>((e) {
        final exp = Map<String, dynamic>.from(e['expense']);
        exp['route_item'] = e['item'];
        return exp;
      }).toList();
    });
  }

  Future<void> _startAddExpenseTourOnlyOnce() async {
    final done = await _secureStorage.read(key: _addExpenseTourDoneKey);
    if (done == "true") return;

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    ShowCaseWidget.of(
      context,
    ).startShowCase([_dateKey, _categoryKey, _paymentKey, _shopKey, _saveKey]);

    await _secureStorage.write(key: _addExpenseTourDoneKey, value: "true");
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchAvailableBanks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final budgets = await DatabaseHelper.instance.getBudget(user.id);

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

  void _addItem() => setState(() => itemInputs.add({}));

  void _removeItem(int index) {
    if (itemInputs.length == 1) return;
    setState(() {
      itemInputs.removeAt(index);
      _updateTotal();
    });
  }

  void _updateTotal() {
    total = itemInputs.fold(0.0, (sum, i) {
      final amt = double.tryParse(i['amount']?.toString() ?? '0') ?? 0;
      return sum + amt;
    });
    setState(() {});
  }

  Future<void> _syncPendingExpenses() async {
    if (!await _hasInternetConnection()) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses(user.id);

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

  Future<void> _loadRecentTravels() async {
    final data = await DatabaseHelper.instance.getRecentTravelExpenses(
      limit: 5,
    );
    setState(() {
      _recentTravels = data;
    });
  }

  void _applyTravelTemplate(Map<String, dynamic> exp) {
    final raw = (exp['items'] ?? '').toString().trim();

    if (raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first as Map<String, dynamic>;

        setState(() {
          _selectedCategory = "Travel";
          _shopController.text = (exp['shop'] ?? '').toString();

          _selectedPaymentMode = (exp['mode'] ?? 'Cash').toString();
          _selectedBank = (exp['bank'] ?? '').toString().isNotEmpty
              ? exp['bank']
              : null;

          _travelModeController.text = (first['mode'] ?? '').toString();
          _travelStartController.text = (first['start'] ?? '').toString();
          _travelDestController.text = (first['destination'] ?? '').toString();
          _travelAmountController.clear();

          itemInputs = [
            {
              "mode": _travelModeController.text,
              "start": _travelStartController.text,
              "destination": _travelDestController.text,
              "amount": "",
            },
          ];

          total = 0.0;
          _showItemsSection = true;
        });
      }
    } catch (e) {
      debugPrint("Failed to apply travel template: $e");
    }
  }

  Future<void> _saveExpense() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Total must be greater than 0")),
      );
      return;
    }
    setState(() => _isSaving = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final date =
        _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final uuid = const Uuid().v4();

    String itemsJsonString = "[]";

    if (_selectedCategory == "Travel") {
      final travelItems = [
        {
          "mode": _travelModeController.text.trim(),
          "start": _travelStartController.text.trim(),
          "destination": _travelDestController.text.trim(),
          "amount": double.tryParse(_travelAmountController.text.trim()) ?? 0.0,
        },
      ];
      itemsJsonString = jsonEncode(travelItems);
    } else {
      final normalItems = itemInputs.map((i) {
        return {
          "name": (i["name"] ?? "").toString().trim(),
          "qty": double.tryParse((i["qty"] ?? "0").toString().trim()) ?? 0.0,
          "unit": (i["unit"] ?? "pcs").toString(),
          "amount":
              double.tryParse((i["amount"] ?? "0").toString().trim()) ?? 0.0,
        };
      }).toList();

      itemsJsonString = jsonEncode(normalItems);
    }

    final localExpense = {
      'uuid': uuid,
      'user_id': user.id,
      'date': date,
      'shop': _shopController.text.trim(),
      'category': _selectedCategory,
      'items': itemsJsonString,
      'total': total,
      'mode': _selectedPaymentMode,
      'bank': _selectedPaymentMode == 'Online' ? (_selectedBank ?? '') : '',
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
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Expense saved")));

    Navigator.pop(context, true);
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
      fillColor: colorScheme.surfaceVariant.withOpacity(0.35),
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
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.35)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildItemFields(int index) {
    final item = itemInputs[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.6),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _selectedCategory == 'Travel'
                    ? 'Trip Details'
                    : 'Item ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (itemInputs.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  onPressed: () => _removeItem(index),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_selectedCategory == 'Travel') ...[
            DropdownButtonFormField<String>(
              value: _travelModeController.text.isEmpty
                  ? null
                  : _travelModeController.text,
              items: _travelModes
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _travelModeController.text = val ?? "";
                });
              },
              decoration: _pillDecoration(
                hint: "Transport Mode",
                icon: Icons.directions,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _travelStartController,
              decoration: _pillDecoration(
                hint: "Start",
                icon: Icons.location_on_outlined,
              ),
              onChanged: (val) => item['start'] = val,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter start point' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _travelDestController,
              decoration: _pillDecoration(
                hint: "Destination",
                icon: Icons.flag_outlined,
              ),
              onChanged: (val) => item['destination'] = val,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter destination' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _travelAmountController,
              decoration: _pillDecoration(
                hint: "Amount",
                icon: Icons.currency_rupee,
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                item['amount'] = val;
                _updateTotal();
              },
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter amount' : null,
            ),
          ] else ...[
            TextFormField(
              decoration: _pillDecoration(
                hint: "Item Name",
                icon: Icons.shopping_bag_outlined,
              ),
              initialValue: item['name']?.toString(),
              onChanged: (val) => item['name'] = val,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter item name' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    decoration: _pillDecoration(
                      hint: "Qty",
                      icon: Icons.numbers,
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: item['qty']?.toString(),
                    onChanged: (val) => item['qty'] = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Enter qty' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: (item['unit'] ?? 'pcs').toString(),
                    items: _units
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        item['unit'] = val;
                      });
                    },
                    decoration: _pillDecoration(
                      hint: "Unit",
                      icon: Icons.straighten,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: _pillDecoration(
                hint: "Amount",
                icon: Icons.currency_rupee,
              ),
              keyboardType: TextInputType.number,
              initialValue: item['amount']?.toString(),
              onChanged: (val) {
                item['amount'] = val;
                _updateTotal();
              },
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter amount' : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
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
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Add Expense",
              style: TextStyle(
                color: Theme.of(context).colorScheme.surface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.add_card_outlined,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    Showcase(
                      key: _dateKey,
                      description: "Select the expense date",
                      child: _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Date",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(30),
                              child: InputDecorator(
                                decoration: _pillDecoration(
                                  hint: "Select Date",
                                  icon: Icons.calendar_today_outlined,
                                ),
                                child: Text(_selectedDate ?? "Select Date"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    _sectionContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Category & Payment",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),

                          Showcase(
                            key: _categoryKey,
                            description: "Choose expense category",
                            child: DropdownButtonFormField(
                              value: _selectedCategory,
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value!;
                                  total = 0.0;
                                  _showItemsSection = true;

                                  if (_selectedCategory == 'Travel') {
                                    itemInputs = [
                                      {
                                        "mode": "",
                                        "start": "",
                                        "destination": "",
                                        "amount": "",
                                      },
                                    ];
                                    _travelModeController.clear();
                                    _travelStartController.clear();
                                    _travelDestController.clear();
                                    _travelAmountController.clear();
                                  } else {
                                    itemInputs = [{}];
                                  }
                                });
                              },
                              decoration: _pillDecoration(
                                hint: "Category",
                                icon: Icons.category_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Showcase(
                            key: _paymentKey,
                            description: "Select how you paid: Cash or Online",
                            child: DropdownButtonFormField(
                              value: _selectedPaymentMode,
                              items: _paymentModes
                                  .map(
                                    (mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) async {
                                setState(() {
                                  _selectedPaymentMode = value!;
                                  _showItemsSection = true;
                                });

                                if (_selectedPaymentMode == "Online") {
                                  final done = await _secureStorage.read(
                                    key: _addExpenseOnlineBankTourDoneKey,
                                  );

                                  if (done != "true") {
                                    await _secureStorage.write(
                                      key: _addExpenseOnlineBankTourDoneKey,
                                      value: "true",
                                    );

                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          ShowCaseWidget.of(
                                            context,
                                          ).startShowCase([_bankKey]);
                                        });
                                  }
                                }
                              },
                              decoration: _pillDecoration(
                                hint: "Paid By",
                                icon: Icons.payments_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          if (_selectedPaymentMode == 'Online' &&
                              _availableBanks.isNotEmpty)
                            Showcase(
                              key: _bankKey,
                              description:
                                  "Select the bank used for online payment",
                              child: DropdownButtonFormField<String>(
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
                                decoration: _pillDecoration(
                                  hint: "Select Bank",
                                  icon: Icons.account_balance_outlined,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    Showcase(
                      key: _shopKey,
                      description: "Enter shop name/type",
                      child: _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCategory == 'Travel'
                                  ? "Travel Provider"
                                  : "Shop Name / Type",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _shopController,
                              decoration: _pillDecoration(
                                hint: _selectedCategory == 'Travel'
                                    ? "Travel Company (e.g. NMMT, Uber)"
                                    : "Shop Name / Type",
                                icon: _selectedCategory == 'Travel'
                                    ? Icons.directions_bus
                                    : Icons.storefront_outlined,
                              ),
                              validator: (value) =>
                                  value!.isEmpty ? 'Enter shop name' : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_selectedCategory == 'Travel' &&
                        _recentTravels.isNotEmpty)
                      _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Most Used Routes",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              height: 85,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recentTravels.length,
                                itemBuilder: (context, index) {
                                  final exp = _recentTravels[index];
                                  final item = exp['route_item'];

                                  if (item == null) {
                                    return const SizedBox();
                                  }

                                  final provider = (exp['shop'] ?? '')
                                      .toString();
                                  final start = (item['start'] ?? '')
                                      .toString();
                                  final dest = (item['destination'] ?? '')
                                      .toString();
                                  final mode = (exp['mode'] ?? 'Cash')
                                      .toString();

                                  final bool isOnline =
                                      mode.toLowerCase() == 'online';

                                  final cardColor = isOnline
                                      ? colorScheme.primary.withOpacity(0.15)
                                      : Colors.green.withOpacity(0.15);

                                  final borderColor = isOnline
                                      ? colorScheme.primary
                                      : Colors.green;

                                  final iconColor = isOnline
                                      ? colorScheme.primary
                                      : Colors.green;

                                  return GestureDetector(
                                    onTap: () => _applyTravelTemplate(exp),
                                    child: Container(
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.directions_bus,
                                                size: 18,
                                                color: iconColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  provider,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 8),

                                          Text(
                                            "$start → $dest",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_showItemsSection)
                      Showcase(
                        key: _itemsKey,
                        description:
                            "Add item details and auto calculate total",
                        child: _sectionContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedCategory == 'Travel'
                                    ? "Trip Details"
                                    : "Items",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),

                              ...List.generate(
                                itemInputs.length,
                                (index) => _buildItemFields(index),
                              ),

                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
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
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              if (_selectedCategory != 'Travel')
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _addItem,
                                    icon: const Icon(Icons.add),
                                    label: const Text(
                                      "Add Another Item",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colorScheme.primary,
                                      side: BorderSide(
                                        color: colorScheme.primary,
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
                      ),

                    const SizedBox(height: 6),

                    Showcase(
                      key: _saveKey,
                      description: "Finally tap here to save the expense",
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,

                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveExpense,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    height: 22,
                                    width: 22,

                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                    ),
                                  )
                                : Text(
                                    "Save Expense",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
