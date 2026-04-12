//import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:walletwatch/services/expense_database.dart';

import 'package:provider/provider.dart';
import 'package:walletwatch/providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  double _cashExpense = 0.0;
  double _onlineExpense = 0.0;

  double _cashBudget = 0.0;
  double _onlineBudget = 0.0;

  String _username = '';
  String _useremail = '';

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _homeTourKey = "WalletWatch_home_tour_done";

  final GlobalKey _totalRemainingKey = GlobalKey();
  final GlobalKey _pieKey = GlobalKey();
  final GlobalKey _cashKey = GlobalKey();
  final GlobalKey _onlineKey = GlobalKey();
  final GlobalKey _addExpenseKey = GlobalKey();
  final GlobalKey _addBudgetKey = GlobalKey();

  final supabase = Supabase.instance.client;

  bool _monthHandled = false;

  // ---------------- Derived Values ----------------
  double get _cashRemaining => _cashBudget - _cashExpense;
  double get _onlineRemaining => _onlineBudget - _onlineExpense;
  double get _totalRemaining => _cashRemaining + _onlineRemaining;

  double get _cashProgress =>
      _cashBudget <= 0 ? 0.0 : (_cashExpense / _cashBudget).clamp(0.0, 1.0);

  double get _onlineProgress => _onlineBudget <= 0
      ? 0.0
      : (_onlineExpense / _onlineBudget).clamp(0.0, 1.0);

  Color _amountColor(double value) =>
      value >= 0 ? colorScheme.secondary : colorScheme.error;

  String _formatPercent(double used, double total) {
    if (total <= 0) return "No budget set";
    final percent = (used / total * 100).clamp(0, 999).toStringAsFixed(0);
    return "$percent% of budget used";
  }

  // ---------------- Lifecycle ----------------
  @override
  void initState() {
    super.initState();
    _initHome();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndHandleNewMonth();
    });
  }

  Future<void> _checkAndHandleNewMonth() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final budgets = await DatabaseHelper.instance.getBudget(user.id);
    if (_monthHandled) return;

    if (budgets.isEmpty) return;

    final lastBudget = budgets.last;

    final hasCurrentMonth = budgets.any((b) => isSameMonth(b['date']));

    if (hasCurrentMonth) return;

    if (isNewMonth(lastBudget['date'])) {
      _monthHandled = true;

      if (lastBudget['carry_forward'] == 1) {
        await _carryForwardBudget(lastBudget);
      } else {
        _handleNewMonth(lastBudget);
      }
    }
  }

  Future<void> _initHome() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isEmpty = await DatabaseHelper.instance.isLocalDatabaseEmpty();

    if (isEmpty) {
      await _syncFromSupabase(user.id); // 🔥 ADD THIS
    }
    await _loadUserInfo();
    await _loadBudgetsSeparately();
    await _loadExpensesSeparately();
    //await _loadShoppingList();

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _startTourIfFirstTime();
    });
  }

  //-------------------------Function to sync supabase to sqlite---------------------------
  Future<void> _syncFromSupabase(String userId) async {
    try {
      // 🔹 Fetch budgets
      final budgets = await supabase
          .from('budgets')
          .select()
          .eq('user_id', userId);

      for (final b in budgets) {
        await DatabaseHelper.instance.insertBudget({
          'uuid': b['uuid'],
          'user_id': userId,
          'date': b['date'],
          'mode': b['mode'],
          'total': b['total'],
          'bank': b['bank'] ?? '',
          'synced': 1,
          'supabase_id': b['id'],
          'carry_forward': 1, // fallback
        });
      }

      // 🔹 Fetch expenses
      final expenses = await supabase
          .from('expenses')
          .select()
          .eq('user_id', userId);

      for (final e in expenses) {
        await DatabaseHelper.instance.insertExpense({
          'uuid': e['uuid'],
          'user_id': userId,
          'date': e['date'],
          'shop': e['shop'],
          'category': e['category'],
          'items': e['items'],
          'total': e['total'],
          'mode': e['mode'],
          'bank': e['bank'],
          'synced': 1,
          'supabase_id': e['id'],
        });
      }
    } catch (e) {
      debugPrint("Sync error: $e");
    }
  }

  // ---------------- Loaders ----------------
  Future<void> _loadUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // STEP 1: Load from SQLite instantly
    final local = await DatabaseHelper.instance.getUserProfile(user.id);

    if (local != null) {
      setState(() {
        _username = local['name'] ?? 'User';
        _useremail = local['email'] ?? '';
      });
    }

    // STEP 2: Sync from Supabase in background
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        final name = response['name'] ?? 'User';
        final email = response['email'] ?? '';

        // Update UI
        if (mounted) {
          setState(() {
            _username = name;
            _useremail = email;
          });
        }

        // Save to SQLite cache
        await DatabaseHelper.instance.upsertUserProfile({
          'user_id': user.id,
          'name': name,
          'email': email,
          'mobile': response['mobile'] ?? '',
          'dob': response['dob'] ?? '',
        });
      }
    } catch (_) {}
  }

  //----------------Function for App Tour----------------------
  Future<void> _startTourIfFirstTime() async {
    final done = await _secureStorage.read(key: _homeTourKey);
    if (done == "true") return;

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    ShowCaseWidget.of(context).startShowCase([
      _totalRemainingKey,
      _pieKey,
      _cashKey,
      _onlineKey,
      _addExpenseKey,
      _addBudgetKey,
    ]);

    await _secureStorage.write(key: _homeTourKey, value: "true");
  }

  //-----------------------------------Helper---------------------------------------
  bool isNewMonth(String lastDate) {
    final last = DateTime.parse(lastDate);
    final now = DateTime.now();

    return last.month != now.month || last.year != now.year;
  }

  bool isSameMonth(String date) {
    final d = DateTime.parse(date);
    final now = DateTime.now();
    return d.month == now.month && d.year == now.year;
  }

  //--------------------------------Function to Carry Forward--------------------------------
  Future<void> _carryForwardBudget(Map lastBudget) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final budgets = await DatabaseHelper.instance.getBudget(user.id);

    final last = DateTime.parse(lastBudget['date']);

    final lastMonthBudgets = budgets.where((b) {
      final d = DateTime.parse(b['date']);
      return d.month == last.month && d.year == last.year;
    }).toList();

    for (final b in lastMonthBudgets) {
      await DatabaseHelper.instance.insertBudget({
        'uuid': const Uuid().v4(),
        'user_id': user.id,
        'date': DateTime.now().toString(),
        'mode': b['mode'],
        'total': b['total'],
        'bank': b['bank'],
        'synced': 0,
        'supabase_id': null,
        'carry_forward': b['carry_forward'] ?? 1,
      });
    }

    await _loadBudgetsSeparately();
  }

  //-------------------------Function to Reset Budget------------------------------
  Future<void> _resetBudget() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await DatabaseHelper.instance.insertBudget({
      'uuid': const Uuid().v4(),
      'user_id': user.id,
      'date': DateTime.now().toString(),
      'mode': 'Cash',
      'total': 0,
      'bank': '',
      'synced': 0,
      'supabase_id': null,
      'carry_forward': 0,
    });

    await _loadBudgetsSeparately();
  }

  //--------------------------------Function to Load Expenses from Supabase----------------------
  Future<void> _loadExpensesSeparately() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final expenses = await DatabaseHelper.instance.getExpenses(user.id);

    double cash = 0.0;
    double online = 0.0;

    for (final item in expenses) {
      final date = item['date']?.toString();
      if (date != null && date.startsWith(currentMonth)) {
        final amount = (item['total'] as num?)?.toDouble() ?? 0.0;
        final mode = (item['mode'] ?? 'Cash').toString().toLowerCase();

        if (mode == 'online') {
          online += amount;
        } else {
          cash += amount;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _cashExpense = cash;
      _onlineExpense = online;
    });
  }

  //----------------------Function to Load Budget from Supabase------------------
  Future<void> _loadBudgetsSeparately() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final budgets = await DatabaseHelper.instance.getBudget(user.id); // ✅ FIXED

    double cash = 0.0;
    double online = 0.0;

    for (final entry in budgets) {
      final date = (entry['date'] ?? '').toString();
      if (!date.startsWith(currentMonth)) continue;

      final amount = (entry['total'] as num?)?.toDouble() ?? 0.0;
      final mode = (entry['mode'] ?? 'Cash').toString();

      if (mode == 'Online') {
        online += amount;
      } else {
        cash += amount;
      }
    }

    if (!mounted) return;

    setState(() {
      _cashBudget = cash;
      _onlineBudget = online;
    });
  }

  // ---------------- Helpers ----------------
  String currentMonthYear() => DateFormat("MMMM yyyy").format(DateTime.now());

  String getInitials(String name) {
    if (name.trim().isEmpty) return "";
    final parts = name.trim().split(" ");
    return parts.length == 1
        ? parts[0][0].toUpperCase()
        : (parts[0][0] + parts[1][0]).toUpperCase();
  }

  //--------------Refresh--------------------
  Future<void> _refreshAll() async {
    await _loadBudgetsSeparately();
    await _loadExpensesSeparately();
    //await _loadShoppingList();
  }

  //-----------------Function for Logout---------------------
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.auth.signOut();

        // Clear local cache AFTER signout
        await DatabaseHelper.instance.clearAllTables();

        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logout failed. Check connection.")),
        );
      }
    }
  }

  // ---------------- Pie Chart ----------------
  Widget _buildExpensePieChart() {
    final total = _cashExpense + _onlineExpense;

    if (total <= 0) {
      return Center(
        child: Text(
          "No Expense data for this month",
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 48,
          sections: [
            PieChartSectionData(
              value: _cashExpense,
              color: colorScheme.secondary,
              radius: 52,
              title: "${((_cashExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: _onlineExpense,
              color: colorScheme.primary,
              radius: 52,
              title: "${((_onlineExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _budgetStatus {
    if (_totalRemaining >= 0) {
      return "Within Budget";
    } else {
      return "Over Budget";
    }
  }

  Color get _budgetStatusColor {
    return _totalRemaining >= 0 ? Colors.green : colorScheme.error;
  }

  Widget _buildPieLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(colorScheme.secondary, "Cash"),
        const SizedBox(width: 16),
        _legendItem(colorScheme.primary, "Online"),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  //----------------------------------UI---------------------

  void _handleNewMonth(Map lastBudget) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔥 Icon
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.calendar_month, color: colorScheme.primary),
              ),

              const SizedBox(height: 14),

              // 🧠 Title
              Text(
                "New Month Started",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 8),

              // 📄 Content
              Text(
                "Do you want to carry forward last month's budget or reset it?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // 🔘 Buttons
              Row(
                children: [
                  // ❌ Reset Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetBudget();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Reset"),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ✅ Carry Forward Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _carryForwardBudget(lastBudget);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Carry Forward"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            //  MODERN APPBAR HEADER
            SliverAppBar(
              pinned: true,
              expandedHeight: 70,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: const Text(
                "WalletWatch",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              foregroundColor: colorScheme.surface,
              elevation: 0,
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    _buildTotalRemainingCard(),
                    //if (_activeShoppingList != null) _buildShoppingListCard(),
                    const SizedBox(height: 8),
                    _buildPieCard(),
                    _buildRemainingRow(),
                    const SizedBox(height: 8),
                    _buildBottomButtons(),
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

  // ---------------- UI Parts ----------------
  Widget _buildTotalRemainingCard() {
    return Showcase(
      key: _totalRemainingKey,
      description: "This is your total remaining money for this month 💰",
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.savings, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Remaining • ${currentMonthYear()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "₹ ${_totalRemaining.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _amountColor(_totalRemaining),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _budgetStatusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _budgetStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _budgetStatusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieCard() {
    return Showcase(
      key: _pieKey,
      description: "This chart shows Cash vs Online expenses 📊",
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Expense Breakdown",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _buildExpensePieChart(),
            const SizedBox(height: 12),
            _buildPieLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingRow() {
    return Row(
      children: [
        Expanded(
          child: Showcase(
            key: _cashKey,
            description: "This shows your remaining Cash budget 💵",
            child: _buildRemainingCard(
              title: "Cash Remaining",
              icon: Icons.money,
              amount: _cashRemaining,
              progress: _cashProgress,
              percentText: _formatPercent(_cashExpense, _cashBudget),
              color: colorScheme.secondary,
              margin: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            ),
          ),
        ),
        Expanded(
          child: Showcase(
            key: _onlineKey,
            description: "This shows your remaining Online budget 🏦",
            child: _buildRemainingCard(
              title: "Online Remaining",
              icon: Icons.account_balance_wallet_outlined,
              amount: _onlineRemaining,
              progress: _onlineProgress,
              percentText: _formatPercent(_onlineExpense, _onlineBudget),
              color: colorScheme.primary,
              margin: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Showcase(
              key: _addExpenseKey,
              description: "Tap here to add a new expense ➕",
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text(
                    "Add Expense",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/add_expense');
                    _loadExpensesSeparately();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Showcase(
              key: _addBudgetKey,
              description: "Tap here to add your monthly budget 💳",
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text(
                    "Add Budget",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.surface,
                    foregroundColor: colorScheme.primary,
                    elevation: 0,
                    side: BorderSide(color: colorScheme.primary, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/budget');
                    _loadBudgetsSeparately();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.surface,
                    child: Text(
                      getInitials(_username),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username.isEmpty ? "User" : _username,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.surface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _useremail,
                          style: TextStyle(color: colorScheme.surface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _drawerItem(Icons.person, "My Profile", '/profiles'),
            _drawerItem(Icons.info, "About Us", '/about'),
            //_drawerItem(Icons.shopping_cart, "Shopping List", '/shopping_list'),
            _drawerItem(Icons.wallet, "Expense Tracker", '/expense_tracker'),
            _drawerItem(Icons.money, "Manage Budget", '/budget_tracker'),
            _drawerItem(Icons.bar_chart, "Reports", "/reports"),
            _drawerItem(Icons.download, "Export Report", "/export_report"),
            _drawerItem(Icons.question_mark, "How To Use", '/how_to_use'),
            _drawerItem(Icons.feedback, "Feedback", '/feedback'),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text("Dark Mode"),
              trailing: Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (value) {
                  context.read<ThemeProvider>().toggleTheme(value);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text("Sign Out"),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  //  FIXED CARD (no Expanded inside)
  Widget _buildRemainingCard({
    required String title,
    required IconData icon,
    required double amount,
    required double progress,
    required String percentText,
    required Color color,
    required EdgeInsets margin,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "₹ ${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: _amountColor(amount),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                color: color,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            percentText,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
