import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  static const String _addBudgetOnlineTourDoneKey =
      "walletwatch_add_budget_online_tour_done";

  //  Showcase Keys
  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _modeKey = GlobalKey();
  final GlobalKey _cashAmountKey = GlobalKey();
  final GlobalKey _onlineBanksKey = GlobalKey();
  final GlobalKey _totalKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  //  Tour storage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _addBudgetTourDoneKey =
      "walletwatch_add_budget_tour_done";

  @override
  void initState() {
    super.initState();
    _addBankField();
    _syncPendingBudgets();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAddBudgetTourOnlyOnce();
    });
  }

  Future<void> _startAddBudgetTourOnlyOnce() async {
    final done = await _secureStorage.read(key: _addBudgetTourDoneKey);
    if (done == "true") return;

    if (!mounted) return;

    ShowCaseWidget.of(
      context,
    ).startShowCase([_dateKey, _modeKey, _cashAmountKey, _saveKey]);

    await _secureStorage.write(key: _addBudgetTourDoneKey, value: "true");
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
        //  Validate all amounts using keys
        for (var b in _bankInputs) {
          final key = b['amountKey'] as GlobalKey<FormFieldState>;
          if (!(key.currentState?.validate() ?? false)) return;
        }

        //  Save all banks
        for (var b in _bankInputs) {
          final bankName = b['bank'].text.trim();
          final amount = double.tryParse(b['amount'].text) ?? 0.0;
          if (amount <= 0) continue;

          final uuid = const Uuid().v4();

          final localId = await DatabaseHelper.instance.insertBudget({
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

  //  Common pill decoration
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
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

  Widget _buildOnlineBankField() {
    return Showcase(
      key: _onlineBanksKey,
      description: "Add bank name + amount. You can add multiple banks ✅",
      child: Column(
        children: [
          ..._bankInputs.asMap().entries.map((entry) {
            final index = entry.key;
            final c = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F6F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: c['bank'],
                          decoration: _pillDecoration(
                            hint: "Bank Name",
                            icon: Icons.account_balance,
                          ),
                        ),
                      ),
                      if (_bankInputs.length > 1)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _removeBankField(index),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: c['amountKey'],
                    controller: c['amount'],
                    keyboardType: TextInputType.number,
                    decoration: _pillDecoration(
                      hint: "Amount",
                      icon: Icons.currency_rupee,
                    ),
                    validator: (v) {
                      final amt = double.tryParse(v ?? '');
                      if (amt == null || amt <= 0) return 'Enter valid amount';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            );
          }),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _addBankField,
              icon: const Icon(Icons.add),
              label: const Text(
                "Add Another Bank",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue, width: 1.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            //  Header like your app theme
            Container(
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
                      "Add Budget",
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
                    child: const Icon(Icons.wallet, color: Colors.white),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 18),
                  children: [
                    // Date + Mode
                    _sectionContainer(
                      child: Column(
                        children: [
                          Showcase(
                            key: _dateKey,
                            description:
                                "Select budget date (usually current month) 📅",
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(30),
                              child: InputDecorator(
                                decoration: _pillDecoration(
                                  hint: "Select Date",
                                  icon: Icons.calendar_today_outlined,
                                ),
                                child: Text(
                                  _selectedDate ?? "Select Date",
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Showcase(
                            key: _modeKey,
                            description:
                                "Choose budget type: Cash or Online 💰🏦",
                            child: DropdownButtonFormField(
                              value: _mode,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Cash',
                                  child: Text('Cash'),
                                ),
                                DropdownMenuItem(
                                  value: 'Online',
                                  child: Text('Online'),
                                ),
                              ],
                              onChanged: (v) async {
                                setState(() => _mode = v!);

                                if (_mode == "Online") {
                                  final done = await _secureStorage.read(
                                    key: _addBudgetOnlineTourDoneKey,
                                  );

                                  if (done != "true") {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;

                                          ShowCaseWidget.of(
                                            context,
                                          ).startShowCase([
                                            _onlineBanksKey,
                                            _totalKey,
                                            _saveKey,
                                          ]);
                                        });

                                    await _secureStorage.write(
                                      key: _addBudgetOnlineTourDoneKey,
                                      value: "true",
                                    );
                                  }
                                }
                              },
                              decoration: _pillDecoration(
                                hint: "Budget Mode",
                                icon: Icons.payments_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    //  Cash / Online input
                    if (_mode == 'Cash')
                      _sectionContainer(
                        child: Showcase(
                          key: _cashAmountKey,
                          description:
                              "Enter the cash budget amount for this month 💵",
                          child: TextFormField(
                            controller: _cashAmountController,
                            keyboardType: TextInputType.number,
                            decoration: _pillDecoration(
                              hint: "Cash Amount",
                              icon: Icons.currency_rupee,
                            ),
                            validator: (v) {
                              final amt = double.tryParse(v ?? '');
                              if (amt == null || amt <= 0) {
                                return 'Enter valid amount';
                              }
                              return null;
                            },
                          ),
                        ),
                      )
                    else
                      _sectionContainer(child: _buildOnlineBankField()),

                    //  Total online
                    if (_mode == 'Online')
                      Showcase(
                        key: _totalKey,
                        description:
                            "This is total online budget (sum of all banks) 📌",
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withOpacity(0.10),
                                Colors.blue.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                "Total Online Budget",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Text(
                                "₹${_onlineTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 6),

                    // Save button
                    Showcase(
                      key: _saveKey,
                      description: "Tap here to save your budget ✅",
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveBudget,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Save Budget",
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
}
