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
  final _amountController = TextEditingController();

  bool _isSaving = false;

  String? _selectedCategory;
  String _selectedPaymentMode = 'Cash';

  bool _showAdvanceDetails = false;

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

  final ScrollController _scrollController = ScrollController();

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  final List<String> _paymentModes = ['Cash', 'Online'];

  List<Map<String, dynamic>> _recentTravels = [];

  List<String> _shopSuggestions = [];

  final _travelModeController = TextEditingController();
  final _travelStartController = TextEditingController();
  final _travelDestController = TextEditingController();

  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _paymentKey = GlobalKey();
  final GlobalKey _bankKey = GlobalKey();
  final GlobalKey _shopKey = GlobalKey();
  final GlobalKey _itemsKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  final FocusNode _shopFocus = FocusNode();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _addExpenseTourDoneKey =
      "walletwatch_add_expense_tour_done";

  static const String _addExpenseOnlineBankTourDoneKey =
      "walletwatch_add_expense_online_bank_tour_done";

  static const double WARNING_LIMIT = 50000;
  static const double MAX_LIMIT = 200000;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fetchAvailableBanks();
    _syncPendingExpenses();
    _loadMostUsedTravels();
    _loadShopSuggestions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAddExpenseTourOnlyOnce();
    });
  }

  //-------------------------Function for Loading Most Used Travel----------------------------

  Future<void> _loadMostUsedTravels() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    final expenses = await DatabaseHelper.instance.getExpenses(user.id);

    final Map<String, Map<String, dynamic>> freqMap = {};

    for (final e in expenses) {
      final expenseDate = DateTime.tryParse((e['date'] ?? '').toString());

      if (expenseDate == null) continue;

      if (now.difference(expenseDate).inDays > 60) continue;

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
            // keep the most recent expense data for this route
            final existingDate = (freqMap[key]!['expense']['date'] ?? '')
                .toString();
            final newDate = (e['date'] ?? '').toString();
            if (newDate.compareTo(existingDate) > 0) {
              freqMap[key]!['expense'] = e;
              freqMap[key]!['item'] = item;
            }
          }
        }
      } catch (_) {}
    }

    final sorted = freqMap.values.toList()
      ..sort((a, b) {
        final countDiff = b['count'].compareTo(a['count']);
        if (countDiff != 0) return countDiff;
        // tiebreak: most recently used first
        final dateA = (a['expense']['date'] ?? '').toString();
        final dateB = (b['expense']['date'] ?? '').toString();
        return dateB.compareTo(dateA);
      });

    setState(() {
      _recentTravels = sorted.take(5).map<Map<String, dynamic>>((e) {
        final exp = Map<String, dynamic>.from(e['expense']);
        exp['route_item'] = e['item'];
        return exp;
      }).toList();
    });
  }

  Future<void> _loadShopSuggestions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    final expenses = await DatabaseHelper.instance.getExpenses(user.id);

    final Map<String, int> shopCount = {};

    for (final e in expenses) {
      final expenseDate = DateTime.tryParse((e['date'] ?? '').toString());

      if (expenseDate == null) continue;

      // only last 60 days
      if (now.difference(expenseDate).inDays > 60) continue;

      // skip travel
      if (e['category'] == 'Travel') continue;

      // match current category
      if (e['category'] != _selectedCategory) continue;

      final shop = (e['shop'] ?? '').toString().trim();

      if (shop.isEmpty) continue;

      shopCount[shop] = (shopCount[shop] ?? 0) + 1;
    }

    final sorted = shopCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _shopSuggestions = sorted.take(5).map((e) => e.key).toList();
    });
  }

  //----------------------------------App Tour-------------------------------------
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

  //----------------------------Function to check internet Connection--------------------------
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  //----------------------------Fetch Available----------------------------------
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

  void _addItem() {
    String defaultUnit = 'pcs';

    if (_selectedCategory == 'Grocery') {
      defaultUnit = 'kg';
    }
    setState(() {
      itemInputs.add({
        "name": "",
        "qty": "",
        "unit": defaultUnit,
        "amount": "",
      });
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  //--------------------HELPER-----------------------------------
  void _removeItem(int index) {
    if (itemInputs.length == 1) return;
    setState(() {
      itemInputs.removeAt(index);
      _updateTotal();
    });
  }

  IconData getTravelIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'train':
        return Icons.train;
      case 'metro':
        return Icons.subway;
      case 'rickshaw':
      case 'taxi':
        return Icons.local_taxi;
      case 'flight':
        return Icons.flight;
      case 'ferry':
        return Icons.directions_boat;
      default:
        return Icons.directions_bus;
    }
  }

  void _updateTotal() {
    total = double.tryParse(_amountController.text) ?? 0;
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

  // Future<void> _loadRecentTravels() async {
  //   final data = await DatabaseHelper.instance.getRecentTravelExpenses(
  //     limit: 5,
  //   );
  //   setState(() {
  //     _recentTravels = data;
  //   });
  // }

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

          itemInputs = [
            {
              "mode": _travelModeController.text,
              "start": _travelStartController.text,
              "destination": _travelDestController.text,
              "amount": "",
            },
          ];

          total = 0.0;
        });
      }
    } catch (e) {}
  }

  //------------------------------Function to Save Expense----------------------------------
  Future<void> _saveExpense() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Amount must be greater than 0")),
      );
      return;
    }
    if (enteredAmount > MAX_LIMIT) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount expense cannot exceed ₹2,00,000')),
      );
      return;
    }
    if (enteredAmount > WARNING_LIMIT) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('High expense amount'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    if (_selectedCategory == 'Travel') {
      final mode = _travelModeController.text.trim();
      final start = _travelStartController.text.trim();
      final destination = _travelDestController.text.trim();

      if (mode.isEmpty || start.isEmpty || destination.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please enter transport mode, start and destination"),
          ),
        );

        return;
      }
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isSaving = false);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please log in again")));
      return;
    }
    setState(() => _isSaving = true);

    final date =
        _selectedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final uuid = const Uuid().v4();

    String itemsJsonString = "[]";

    if (_selectedCategory == "Travel") {
      final mode = _travelModeController.text.trim();
      final start = _travelStartController.text.trim();
      final destination = _travelDestController.text.trim();

      // Only save travel details if the user actually entered them.
      if (mode.isNotEmpty || start.isNotEmpty || destination.isNotEmpty) {
        final travelItems = [
          {"mode": mode, "start": start, "destination": destination},
        ];

        itemsJsonString = jsonEncode(travelItems);
      }
    } else {
      final normalItems = itemInputs
          .where((i) {
            final name = (i["name"] ?? "").toString().trim();
            final qty = (i["qty"] ?? "").toString().trim();

            return name.isNotEmpty || qty.isNotEmpty;
          })
          .map((i) {
            return {
              "name": (i["name"] ?? "").toString().trim(),
              "qty":
                  double.tryParse((i["qty"] ?? "0").toString().trim()) ?? 0.0,
              "unit": (i["unit"] ?? "pcs").toString(),
            };
          })
          .toList();

      if (normalItems.isNotEmpty) {
        itemsJsonString = jsonEncode(normalItems);
      }
    }

    final localExpense = {
      'uuid': uuid,
      'user_id': user.id,
      'date': date,
      'shop': _shopController.text.trim(),
      'category': _selectedCategory,
      'items': itemsJsonString,
      'total': enteredAmount,
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
              'total': enteredAmount,
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

  String getSuggestedUnit(String itemName) {
    final text = itemName.toLowerCase();

    if (text.contains('oil') || text.contains('juice')) {
      return 'L';
    }

    if (text.contains('rice') ||
        text.contains('sugar') ||
        text.contains('wheat')) {
      return 'kg';
    }

    if (text.contains('shampoo') ||
        text.contains('perfume') ||
        text.contains('milk')) {
      return 'ml';
    }

    return 'pcs';
  }

  //-------------------------------Date Picker-------------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null
          ? DateTime.parse(_selectedDate!)
          : DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  //-----------------------------UI--------------------------------------
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
              validator: (val) =>
                  val == null || val.isEmpty ? "Select mode" : null,
              decoration: _pillDecoration(
                hint: "Select Transport Mode",

                icon: getTravelIcon(_travelModeController.text),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _travelStartController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _pillDecoration(
                hint: "Start",
                icon: Icons.location_on_outlined,
              ),
              onChanged: (val) => item['start'] = val,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter start location' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _travelDestController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _pillDecoration(
                hint: "Destination",
                icon: Icons.flag_outlined,
              ),
              onChanged: (val) => item['destination'] = val,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter destination' : null,
            ),
            // const SizedBox(height: 10),
            // TextFormField(
            //   controller: _travelAmountController,
            //   decoration: _pillDecoration(
            //     hint: "Amount",
            //     icon: Icons.currency_rupee,
            //   ),
            //   textInputAction: TextInputAction.done,
            //   keyboardType: TextInputType.numberWithOptions(decimal: true),
            //   onChanged: (val) {
            //     item['amount'] = val;
            //     _updateTotal();
            //   },
            //   validator: (val) {
            //     final amt = double.tryParse(val ?? '');

            //     if (amt == null || amt <= 0) {
            //       return 'Enter valid amount';
            //     }

            //     if (amt > MAX_LIMIT) {
            //       return 'Max ₹2,00,000 allowed';
            //     }

            //     return null;
            //   },
            // ),
          ] else ...[
            TextFormField(
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: _pillDecoration(
                hint: "Item Name",
                icon: Icons.shopping_bag_outlined,
              ),
              initialValue: item['name']?.toString(),
              onChanged: (val) {
                item['name'] = val;

                // Auto suggest unit
                if (item['unit'] == null || item['unit'] == 'pcs') {
                  item['unit'] = getSuggestedUnit(val);
                }

                setState(() {});
              },
              validator: (val) =>
                  val == null || val.isEmpty ? 'Enter item name' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    textInputAction: TextInputAction.next,
                    decoration: _pillDecoration(
                      hint: "Qty",
                      icon: Icons.numbers,
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    initialValue: item['qty']?.toString(),
                    onChanged: (val) => item['qty'] = val,
                    validator: (val) {
                      final qty = double.tryParse(val ?? "");
                      if (qty == null || qty <= 0) {
                        return "Qty must be greater than 0";
                      }
                    },
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
            // TextFormField(
            //   textInputAction: TextInputAction.done,
            //   decoration: _pillDecoration(
            //     hint: "Amount",
            //     icon: Icons.currency_rupee,
            //   ),
            //   keyboardType: TextInputType.numberWithOptions(decimal: true),
            //   initialValue: item['amount']?.toString(),
            //   onChanged: (val) {
            //     item['amount'] = val;
            //     _updateTotal();
            //   },
            //   validator: (val) {
            //     final amt = double.tryParse(val ?? '');

            //     if (amt == null || amt <= 0) {
            //       return 'Enter valid amount';
            //     }

            //     if (amt > MAX_LIMIT) {
            //       return 'Max ₹2,00,000 allowed';
            //     }

            //     return null;
            //   },
            // ),
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
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 6, bottom: 18),
                    children: [
                      _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Amount",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _amountController,
                              onChanged: (_) => _updateTotal(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _pillDecoration(
                                hint: "Enter Amount",
                                icon: Icons.currency_rupee,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Enter amount";
                                }

                                final amt = double.tryParse(value);

                                if (amt == null || amt <= 0) {
                                  return "Enter valid amount";
                                }

                                return null;
                              },
                            ),
                          ],
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
                              child: DropdownButtonFormField<String>(
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
                                    _shopController.clear();
                                    _shopSuggestions.clear();

                                    total = 0.0;
                                    _loadShopSuggestions();

                                    if (_selectedCategory == 'Travel') {
                                      itemInputs = [
                                        {
                                          "mode": "",
                                          "start": "",
                                          "destination": "",
                                        },
                                      ];

                                      _travelModeController.clear();
                                      _travelStartController.clear();
                                      _travelDestController.clear();
                                    } else {
                                      String defaultUnit = 'pcs';

                                      if (_selectedCategory == 'Grocery') {
                                        defaultUnit = 'kg';
                                      }

                                      itemInputs = [
                                        {
                                          "name": "",
                                          "qty": "",
                                          "unit": defaultUnit,
                                        },
                                      ];
                                    }
                                  });
                                },
                                decoration: _pillDecoration(
                                  hint: "Select Category",
                                  icon: Icons.category_outlined,
                                ),
                                validator: (value) =>
                                    value == null ? 'Select category' : null,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Showcase(
                              key: _paymentKey,
                              description:
                                  "Select how you paid: Cash or Online",
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
                                    //_showItemsSection = true;
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
                                focusNode: _shopFocus,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).nextFocus();
                                },
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,

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
                              if (_selectedCategory != null &&
                                  _selectedCategory != 'Travel' &&
                                  _shopSuggestions.isNotEmpty) ...[
                                const SizedBox(height: 14),

                                Text(
                                  "Recent Shops",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _shopSuggestions.map((shop) {
                                    return ActionChip(
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      label: Text(shop),
                                      onPressed: () {
                                        setState(() {
                                          _shopController.text = shop;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ] else if (_selectedCategory != null &&
                                  _selectedCategory != 'Travel') ...[
                                const SizedBox(height: 12),

                                Text(
                                  "Recent shops will appear here",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_selectedCategory == 'Travel')
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Showcase(
                            key: _itemsKey,
                            description:
                                "Travel details are required: select transport mode, start and destination.",
                            child: _sectionContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Trip Details",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  _buildItemFields(0),
                                ],
                              ),
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
                                        margin: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: borderColor,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  getTravelIcon(
                                                    item['mode']?.toString() ??
                                                        '',
                                                  ),
                                                  size: 18,
                                                  color: iconColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    provider,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                color: colorScheme
                                                    .onSurfaceVariant,
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
                        )
                      else if (_selectedCategory == 'Travel')
                        _sectionContainer(
                          child: Text(
                            "Your frequent routes will appear here",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ExpansionTile(
                        title: const Text(
                          "Add More Details",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onExpansionChanged: (value) {
                          setState(() {
                            _showAdvanceDetails = value;
                          });
                        },
                        children: [
                          // --------------------------------------------------
                          // DATE - available for every category
                          // --------------------------------------------------
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Showcase(
                              key: _dateKey,
                              description:
                                  "Your expense date is set to today. Tap here if you want to change it.",
                              child: _sectionContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Date",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
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
                                        child: Text(
                                          _selectedDate ?? "Select Date",
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // --------------------------------------------------
                          // GROCERY ITEM DETAILS - optional
                          // --------------------------------------------------
                          if (_selectedCategory == 'Grocery')
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: _sectionContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Item Details (Optional)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    ...List.generate(
                                      itemInputs.length,
                                      (index) => _buildItemFields(index),
                                    ),

                                    const SizedBox(height: 12),

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
                                            borderRadius: BorderRadius.circular(
                                              30,
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
      ),
    );
  }

  @override
  void dispose() {
    _shopController.dispose();
    _travelModeController.dispose();
    _amountController.dispose();
    _travelStartController.dispose();
    _travelDestController.dispose();

    _shopFocus.dispose();

    _scrollController.dispose();
    super.dispose();
  }
}
