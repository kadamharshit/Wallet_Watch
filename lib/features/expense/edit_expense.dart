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

  final ScrollController _scrollController = ScrollController();

  late TextEditingController _amountController;
  late TextEditingController _shopController;
  late TextEditingController _bankController;

  // Travel controllers
  late TextEditingController _travelModeController;
  late TextEditingController _travelStartController;
  late TextEditingController _travelDestinationController;

  late String _dateString;

  String _category = 'Grocery';
  String _mode = 'Cash';

  bool _saving = false;

  double total = 0.0;

  List<String> _availableBanks = [];

  // Grocery items.
  //
  // IMPORTANT:
  // These items no longer contain an amount.
  // The expense amount is stored only in `total`.
  List<Map<String, String>> itemInputs = [];

  // Keeps old non-Grocery/non-Travel item data safe if it exists.
  String _originalItemsJson = "[]";
  String _originalCategory = "Grocery";

  final List<String> _categories = const [
    'Grocery',
    'Travel',
    'Food',
    'Medical',
    'Bills',
    'Other',
  ];

  final List<String> _travelModes = const [
    "Bus",
    "Train",
    "Metro",
    "Rickshaw",
    "Taxi",
    "Flight",
    "Ferry",
    "Other",
  ];

  final List<String> _modes = const ['Cash', 'Online'];

  final List<String> _units = const ['pcs', 'kg', 'g', 'L', 'ml'];

  static const double WARNING_LIMIT = 50000;
  static const double MAX_LIMIT = 200000;

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    final exp = widget.expense;

    // Date
    _dateString =
        (exp['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()))
            .toString();

    // Amount
    final existingAmount = (exp['total'] as num?)?.toDouble() ?? 0.0;

    total = existingAmount;

    _amountController = TextEditingController(
      text: existingAmount > 0
          ? existingAmount.toStringAsFixed(existingAmount % 1 == 0 ? 0 : 2)
          : '',
    );

    // Shop
    _shopController = TextEditingController(
      text: (exp['shop'] ?? '').toString(),
    );

    // Category
    final existingCategory = (exp['category'] ?? 'Grocery').toString();

    if (_categories.contains(existingCategory)) {
      _category = existingCategory;
    }

    _originalCategory = _category;

    // Payment mode
    final existingMode = (exp['mode'] ?? 'Cash').toString();

    if (_modes.contains(existingMode)) {
      _mode = existingMode;
    }

    // Bank
    _bankController = TextEditingController(
      text: (exp['bank'] ?? '').toString(),
    );

    // Travel controllers
    _travelModeController = TextEditingController();
    _travelStartController = TextEditingController();
    _travelDestinationController = TextEditingController();

    // Existing items
    _originalItemsJson = (exp['items'] ?? '').toString().trim();

    _loadExistingItems();

    // Load available banks
    _loadBanks();
  }

  // ---------------------------------------------------------------------------
  // LOAD BANKS
  // ---------------------------------------------------------------------------

  Future<void> _loadBanks() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final response = await supabase
          .from('budgets')
          .select('bank')
          .eq('user_id', user.id)
          .eq('mode', 'Online');

      final banks = response
          .map((e) => (e['bank'] ?? '').toString().trim())
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList();

      // Important:
      // If an old expense has a bank that no longer exists in the
      // current budget list, keep it available so DropdownButton
      // doesn't fail and the old value isn't lost.
      final existingBank = _bankController.text.trim();

      if (existingBank.isNotEmpty && !banks.contains(existingBank)) {
        banks.add(existingBank);
      }

      if (!mounted) return;

      setState(() {
        _availableBanks = banks;
      });
    } catch (_) {
      // Keep the page usable even if bank loading fails.
    }
  }

  // ---------------------------------------------------------------------------
  // LOAD EXISTING ITEMS
  // ---------------------------------------------------------------------------

  void _loadExistingItems() {
    final raw = _originalItemsJson;

    if (raw.isEmpty) {
      _initializeEmptyDetails();
      return;
    }

    // New / existing JSON format
    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          if (_category == 'Travel') {
            _loadExistingTravel(decoded);
          } else if (_category == 'Grocery') {
            _loadExistingGrocery(decoded);
          } else {
            // For Food / Medical / Bills / Other:
            // the new system does not use item details.
            itemInputs = [];
          }

          return;
        }
      } catch (_) {
        // Fall through to legacy format.
      }
    }

    // -----------------------------------------------------------------------
    // Legacy text format
    // -----------------------------------------------------------------------

    final lines = raw
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (_category == 'Travel') {
      itemInputs = [];

      if (lines.isNotEmpty) {
        final parts = lines.first.split('|').map((e) => e.trim()).toList();

        final mode = parts.isNotEmpty ? parts[0] : "";

        final start = parts.length > 1 ? parts[1] : "";

        final destination = parts.length > 2 ? parts[2] : "";

        _travelModeController.text = mode;
        _travelStartController.text = start;
        _travelDestinationController.text = destination;

        itemInputs = [
          {"mode": mode, "start": start, "destination": destination},
        ];
      }

      return;
    }

    if (_category == 'Grocery') {
      itemInputs = lines.map((line) {
        final parts = line.split('|').map((e) => e.trim()).toList();

        return {
          "name": parts.isNotEmpty ? parts[0] : "",
          "qty": parts.length > 1 ? parts[1] : "",
          "unit": "pcs",
        };
      }).toList();

      if (itemInputs.isEmpty) {
        itemInputs = [];
      }

      return;
    }

    itemInputs = [];
  }

  // ---------------------------------------------------------------------------
  // LOAD EXISTING GROCERY
  // ---------------------------------------------------------------------------

  void _loadExistingGrocery(List decoded) {
    final loadedItems = <Map<String, String>>[];

    for (final element in decoded) {
      if (element is! Map) continue;

      final map = Map<String, dynamic>.from(element);

      final name = (map["name"] ?? "").toString();

      final qty = (map["qty"] ?? "").toString();

      final unit = (map["unit"] ?? "pcs").toString();

      // IMPORTANT:
      // We intentionally DO NOT load:
      //
      // map["amount"]
      //
      // because item amount is no longer part of the new system.

      // Ignore completely empty old entries.
      if (name.trim().isEmpty && qty.trim().isEmpty) {
        continue;
      }

      loadedItems.add({
        "name": name,
        "qty": qty,
        "unit": _units.contains(unit) ? unit : "pcs",
      });
    }

    itemInputs = loadedItems;
  }

  // ---------------------------------------------------------------------------
  // LOAD EXISTING TRAVEL
  // ---------------------------------------------------------------------------

  void _loadExistingTravel(List decoded) {
    if (decoded.isEmpty) {
      _initializeTravelDetails();
      return;
    }

    final first = decoded.first;

    if (first is! Map) {
      _initializeTravelDetails();
      return;
    }

    final map = Map<String, dynamic>.from(first);

    final mode = (map["mode"] ?? "").toString();

    final start = (map["start"] ?? "").toString();

    final destination = (map["destination"] ?? "").toString();

    // IMPORTANT:
    // Old travel data may contain "amount".
    // We intentionally ignore it.
    //
    // The real expense amount comes from:
    // widget.expense['total']

    _travelModeController.text = mode;
    _travelStartController.text = start;
    _travelDestinationController.text = destination;

    itemInputs = [
      {"mode": mode, "start": start, "destination": destination},
    ];
  }

  // ---------------------------------------------------------------------------
  // INITIALIZE EMPTY DETAILS
  // ---------------------------------------------------------------------------

  void _initializeEmptyDetails() {
    if (_category == 'Travel') {
      _initializeTravelDetails();
    } else if (_category == 'Grocery') {
      itemInputs = [];
    } else {
      itemInputs = [];
    }
  }

  void _initializeTravelDetails() {
    _travelModeController.clear();
    _travelStartController.clear();
    _travelDestinationController.clear();

    itemInputs = [
      {"mode": "", "start": "", "destination": ""},
    ];
  }

  // ---------------------------------------------------------------------------
  // AMOUNT
  // ---------------------------------------------------------------------------

  void _updateTotal() {
    final value = double.tryParse(_amountController.text.trim());

    total = value ?? 0.0;

    if (mounted) {
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // DATE PICKER
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateString) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _dateString = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  // ---------------------------------------------------------------------------
  // GROCERY ITEMS
  // ---------------------------------------------------------------------------

  void _addItem() {
    String defaultUnit = 'pcs';

    if (_category == 'Grocery') {
      defaultUnit = 'kg';
    }

    setState(() {
      itemInputs.add({"name": "", "qty": "", "unit": defaultUnit});
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

  void _removeItem(int index) {
    if (index < 0 || index >= itemInputs.length) {
      return;
    }

    setState(() {
      itemInputs.removeAt(index);
    });
  }

  // ---------------------------------------------------------------------------
  // SUGGEST UNIT
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // TRAVEL ICON
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // BUILD ITEMS JSON
  // ---------------------------------------------------------------------------

  String _buildItemsJson() {
    // -----------------------------------------------------------------------
    // TRAVEL
    // -----------------------------------------------------------------------

    if (_category == 'Travel') {
      final mode = _travelModeController.text.trim();

      final start = _travelStartController.text.trim();

      final destination = _travelDestinationController.text.trim();

      return jsonEncode([
        {"mode": mode, "start": start, "destination": destination},
      ]);
    }

    // -----------------------------------------------------------------------
    // GROCERY
    // -----------------------------------------------------------------------

    if (_category == 'Grocery') {
      final validItems = itemInputs
          .where((item) {
            final name = (item["name"] ?? "").trim();

            final qty = (item["qty"] ?? "").trim();

            return name.isNotEmpty || qty.isNotEmpty;
          })
          .map((item) {
            return {
              "name": (item["name"] ?? "").trim(),

              "qty": double.tryParse((item["qty"] ?? "0").trim()) ?? 0.0,

              "unit": _units.contains(item["unit"]) ? item["unit"] : "pcs",
            };
          })
          .toList();

      if (validItems.isEmpty) {
        return "[]";
      }

      return jsonEncode(validItems);
    }

    // -----------------------------------------------------------------------
    // OTHER CATEGORIES
    // -----------------------------------------------------------------------

    // If this expense was originally another category and we haven't
    // changed its category, preserve any old items rather than destroying
    // existing data.
    if (_category == _originalCategory &&
        _category != 'Travel' &&
        _category != 'Grocery' &&
        _originalItemsJson.isNotEmpty) {
      return _originalItemsJson;
    }

    // New system doesn't use item details for these categories.
    return "[]";
  }

  // ---------------------------------------------------------------------------
  // VALIDATE GROCERY DETAILS
  // ---------------------------------------------------------------------------

  bool _validateGroceryDetails() {
    if (_category != 'Grocery') {
      return true;
    }

    for (int i = 0; i < itemInputs.length; i++) {
      final item = itemInputs[i];

      final name = (item["name"] ?? "").trim();

      final qty = (item["qty"] ?? "").trim();

      // Completely empty item = okay because Grocery details are optional.
      if (name.isEmpty && qty.isEmpty) {
        continue;
      }

      // Partially filled item = ask user to complete it.
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Enter item name for Item ${i + 1}")),
        );

        return false;
      }

      final parsedQty = double.tryParse(qty);

      if (parsedQty == null || parsedQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Enter a valid quantity for Item ${i + 1}")),
        );

        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // VALIDATE TRAVEL DETAILS
  // ---------------------------------------------------------------------------

  bool _validateTravelDetails() {
    if (_category != 'Travel') {
      return true;
    }

    final mode = _travelModeController.text.trim();

    final start = _travelStartController.text.trim();

    final destination = _travelDestinationController.text.trim();

    if (mode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select transport mode")),
      );

      return false;
    }

    if (start.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter start location")),
      );

      return false;
    }

    if (destination.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter destination")));

      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // SAVE CHANGES
  // ---------------------------------------------------------------------------

  Future<void> _saveChanges() async {
    if (_saving) return;

    // Validate normal form fields.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate amount.
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0')),
      );

      return;
    }

    if (enteredAmount > MAX_LIMIT) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total expense cannot exceed ₹2,00,000')),
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

    // Grocery details are optional.
    if (!_validateGroceryDetails()) {
      return;
    }

    // Travel details are compulsory.
    if (!_validateTravelDetails()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final supabase = Supabase.instance.client;

    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _saving = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please log in again")));
      }

      return;
    }

    // Keep total based ONLY on the main amount field.
    total = enteredAmount;

    final itemsJson = _buildItemsJson();

    final updatedExpense = {
      'date': _dateString,

      'shop': _shopController.text.trim(),

      'category': _category,

      'items': itemsJson,

      'total': enteredAmount,

      'mode': _mode,

      'bank': _mode == 'Online' ? _bankController.text.trim() : '',
    };

    try {
      // ---------------------------------------------------------------------
      // UPDATE LOCAL DATABASE
      // ---------------------------------------------------------------------

      final localId = widget.expense['id'] as int?;

      if (localId != null) {
        await DatabaseHelper.instance.updateExpense(localId, updatedExpense);
      }

      // ---------------------------------------------------------------------
      // UPDATE SUPABASE
      // ---------------------------------------------------------------------

      final remoteId = widget.expense['supabase_id'];

      final uuid = widget.expense['uuid'];

      final dataForSupabase = {
        'date': updatedExpense['date'],

        'shop': updatedExpense['shop'],

        'category': updatedExpense['category'],

        'items': updatedExpense['items'],

        'total': updatedExpense['total'],

        'mode': updatedExpense['mode'],

        'bank': (_mode == 'Online' && _bankController.text.trim().isNotEmpty)
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

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense updated')));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update expense. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI DECORATION
  // ---------------------------------------------------------------------------

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
      fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
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
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

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
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: colorScheme.surface),
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
              color: colorScheme.surface.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.edit_note, color: colorScheme.surface),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GROCERY ITEM FIELD
  // ---------------------------------------------------------------------------

  Widget _buildGroceryItemFields(int index) {
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
                "Item ${index + 1}",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),

              const Spacer(),

              if (itemInputs.length > 1)
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                ),
            ],
          ),

          const SizedBox(height: 10),

          TextFormField(
            key: ValueKey("edit_item_name_$index"),
            initialValue: item["name"] ?? "",
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _pillDecoration(
              hint: "Item Name",
              icon: Icons.shopping_bag_outlined,
            ),
            onChanged: (value) {
              item["name"] = value;

              if (item["unit"] == null || item["unit"] == "pcs") {
                item["unit"] = getSuggestedUnit(value);
              }

              setState(() {});
            },
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: ValueKey("edit_item_qty_$index"),
                  initialValue: item["qty"] ?? "",
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _pillDecoration(hint: "Qty", icon: Icons.numbers),
                  onChanged: (value) {
                    item["qty"] = value;
                  },
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _units.contains(item["unit"]) ? item["unit"] : "pcs",
                  items: _units
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      item["unit"] = value;
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TRAVEL DETAILS
  // ---------------------------------------------------------------------------

  Widget _buildTravelDetails() {
    return _sectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Trip Details",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _travelModes.contains(_travelModeController.text)
                ? _travelModeController.text
                : null,
            items: _travelModes
                .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _travelModeController.text = value;

                if (itemInputs.isEmpty) {
                  itemInputs = [
                    {"mode": value, "start": "", "destination": ""},
                  ];
                } else {
                  itemInputs[0]["mode"] = value;
                }
              });
            },
            decoration: _pillDecoration(
              hint: "Select Transport Mode",
              icon: getTravelIcon(_travelModeController.text),
            ),
            validator: (value) {
              if (_category != 'Travel') {
                return null;
              }

              if (value == null || value.isEmpty) {
                return "Select mode";
              }

              return null;
            },
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
            onChanged: (value) {
              if (itemInputs.isEmpty) {
                itemInputs = [
                  {
                    "mode": _travelModeController.text,
                    "start": value,
                    "destination": "",
                  },
                ];
              } else {
                itemInputs[0]["start"] = value;
              }
            },
            validator: (value) {
              if (_category != 'Travel') {
                return null;
              }

              if (value == null || value.trim().isEmpty) {
                return "Enter start location";
              }

              return null;
            },
          ),

          const SizedBox(height: 10),

          TextFormField(
            controller: _travelDestinationController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: _pillDecoration(
              hint: "Destination",
              icon: Icons.flag_outlined,
            ),
            onChanged: (value) {
              if (itemInputs.isEmpty) {
                itemInputs = [
                  {
                    "mode": _travelModeController.text,
                    "start": _travelStartController.text,
                    "destination": value,
                  },
                ];
              } else {
                itemInputs[0]["destination"] = value;
              }
            },
            validator: (value) {
              if (_category != 'Travel') {
                return null;
              }

              if (value == null || value.trim().isEmpty) {
                return "Enter destination";
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isTravel = _category == 'Travel';

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
                      // =======================================================
                      // AMOUNT
                      // =======================================================
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
                              onChanged: (_) {
                                _updateTotal();
                              },
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _pillDecoration(
                                hint: "Enter Amount",
                                icon: Icons.currency_rupee,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Enter amount";
                                }

                                final amount = double.tryParse(value.trim());

                                if (amount == null || amount <= 0) {
                                  return "Enter valid amount";
                                }

                                if (amount > MAX_LIMIT) {
                                  return "Max ₹2,00,000 allowed";
                                }

                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      // =======================================================
                      // CATEGORY & PAYMENT
                      // =======================================================
                      _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Category & Payment",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),

                            const SizedBox(height: 10),

                            DropdownButtonFormField<String>(
                              value: _category,
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }

                                if (value == _category) {
                                  return;
                                }

                                setState(() {
                                  _category = value;

                                  if (_category == 'Travel') {
                                    _initializeTravelDetails();
                                  } else {
                                    _travelModeController.clear();

                                    _travelStartController.clear();

                                    _travelDestinationController.clear();

                                    if (_category == 'Grocery') {
                                      itemInputs = [];
                                    } else {
                                      itemInputs = [];
                                    }
                                  }
                                });
                              },
                              decoration: _pillDecoration(
                                hint: "Select Category",
                                icon: Icons.category_outlined,
                              ),
                              validator: (value) {
                                if (value == null) {
                                  return "Select category";
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            DropdownButtonFormField<String>(
                              value: _mode,
                              items: _modes
                                  .map(
                                    (mode) => DropdownMenuItem(
                                      value: mode,
                                      child: Text(mode),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  _mode = value;

                                  if (_mode == 'Cash') {
                                    _bankController.clear();
                                  }
                                });
                              },
                              decoration: _pillDecoration(
                                hint: "Paid By",
                                icon: Icons.payments_outlined,
                              ),
                            ),

                            if (_mode == 'Online' &&
                                _availableBanks.isNotEmpty) ...[
                              const SizedBox(height: 12),

                              DropdownButtonFormField<String>(
                                value:
                                    _availableBanks.contains(
                                      _bankController.text,
                                    )
                                    ? _bankController.text
                                    : null,
                                items: _availableBanks
                                    .map(
                                      (bank) => DropdownMenuItem(
                                        value: bank,
                                        child: Text(bank),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _bankController.text = value ?? '';
                                  });
                                },
                                decoration: _pillDecoration(
                                  hint: "Select Bank",
                                  icon: Icons.account_balance_outlined,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // =======================================================
                      // ADD MORE DETAILS
                      // =======================================================
                      ExpansionTile(
                        title: const Text(
                          "Add More Details",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),

                        children: [
                          // ---------------------------------------------------
                          // DATE
                          // ---------------------------------------------------
                          Padding(
                            padding: const EdgeInsets.all(12),

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
                                      child: Text(_dateString),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ---------------------------------------------------
                          // GROCERY ITEM DETAILS
                          // ---------------------------------------------------
                          if (_category == 'Grocery')
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

                                    if (itemInputs.isNotEmpty)
                                      ...List.generate(
                                        itemInputs.length,
                                        (index) =>
                                            _buildGroceryItemFields(index),
                                      ),

                                    if (itemInputs.isEmpty)
                                      Text(
                                        "No item details added.",
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),

                                    const SizedBox(height: 4),

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

                      // =======================================================
                      // SHOP / TRAVEL PROVIDER
                      // =======================================================
                      _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTravel ? "Travel Provider" : "Shop Name / Type",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _shopController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: _pillDecoration(
                                hint: isTravel
                                    ? "Travel Company (e.g. NMMT, Uber)"
                                    : "Shop Name / Type",
                                icon: isTravel
                                    ? Icons.directions_bus_outlined
                                    : Icons.storefront_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return isTravel
                                      ? "Enter travel provider"
                                      : "Enter shop name";
                                }

                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      // =======================================================
                      // TRAVEL DETAILS
                      //
                      // IMPORTANT:
                      // These are NOT inside Add More Details.
                      // They are mandatory for Travel.
                      // =======================================================
                      if (isTravel)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: _buildTravelDetails(),
                        ),

                      // =======================================================
                      // TOTAL
                      // =======================================================
                      _sectionContainer(
                        child: Row(
                          children: [
                            Text(
                              isTravel ? "Trip Cost" : "Total",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              "₹${total.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      // =======================================================
                      // SAVE
                      // =======================================================
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),

                        child: SizedBox(
                          width: double.infinity,
                          height: 52,

                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveChanges,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),

                            child: _saving
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.surface,
                                    ),
                                  )
                                : const Text(
                                    "Save Changes",
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _amountController.dispose();
    _shopController.dispose();
    _bankController.dispose();

    _travelModeController.dispose();
    _travelStartController.dispose();
    _travelDestinationController.dispose();

    _scrollController.dispose();

    super.dispose();
  }
}
