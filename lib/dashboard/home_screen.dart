import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:walletwatch/services/expense_database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _cashExpense = 0.0;
  double _onlineExpense = 0.0;

  double _cashBudget = 0.0;
  double _onlineBudget = 0.0;

  String _username = '';
  String _useremail = '';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _homeTourKey = "WalletWatch_home_tour_done";

  final GlobalKey _totalRemainingKey = GlobalKey();
  final GlobalKey _pieKey = GlobalKey();
  final GlobalKey _cashKey = GlobalKey();
  final GlobalKey _onlineKey = GlobalKey();
  final GlobalKey _addExpenseKey = GlobalKey();
  final GlobalKey _addBudgetKey = GlobalKey();

  final supabase = Supabase.instance.client;

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
      value >= 0 ? Colors.green : Colors.redAccent;

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
  }

  Future<void> _initHome() async {
    await _loadUserInfo();
    await _loadBudgetsSeparately();
    await _loadExpensesSeparately();

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _startTourIfFirstTime();
    });
  }

  // ---------------- Loaders ----------------
  Future<void> _loadUserInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      setState(() {
        _username = response['name'] ?? 'User';
        _useremail = response['email'] ?? '';
      });
    }
  }

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

  Future<void> _loadExpensesSeparately() async {
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final expenses = await DatabaseHelper.instance.getExpenses();

    double cash = 0.0;
    double online = 0.0;

    for (final item in expenses) {
      final date = item['date']?.toString();
      if (date != null && date.startsWith(currentMonth)) {
        final amount = (item['total'] as num?)?.toDouble() ?? 0.0;
        final mode = (item['mode'] ?? 'Cash').toString().toLowerCase();
        mode == 'online' ? online += amount : cash += amount;
      }
    }

    setState(() {
      _cashExpense = cash;
      _onlineExpense = online;
    });
  }

  Future<void> _loadBudgetsSeparately() async {
    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final budgets = await DatabaseHelper.instance.getBudget();

    double cash = 0.0;
    double online = 0.0;

    for (final entry in budgets) {
      final date = (entry['date'] ?? '').toString();
      if (!date.startsWith(currentMonth)) continue;

      final amount = (entry['total'] as num?)?.toDouble() ?? 0.0;
      final mode = (entry['mode'] ?? 'Cash').toString();

      mode == 'Online' ? online += amount : cash += amount;
    }

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

  Future<void> _refreshAll() async {
    await _loadBudgetsSeparately();
    await _loadExpensesSeparately();
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.clearAllTables();
      await supabase.auth.signOut();

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // ---------------- Pie Chart ----------------
  Widget _buildExpensePieChart() {
    final total = _cashExpense + _onlineExpense;

    if (total <= 0) {
      return const Center(
        child: Text(
          "No Expense data for this month",
          style: TextStyle(color: Colors.grey),
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
              color: Colors.green,
              radius: 52,
              title: "${((_cashExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: _onlineExpense,
              color: Colors.blue,
              radius: 52,
              title: "${((_onlineExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
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

  Widget _buildPieLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(Colors.green, "Cash"),
        const SizedBox(width: 16),
        _legendItem(Colors.blue, "Online"),
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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            //  MODERN APPBAR HEADER
            SliverAppBar(
              pinned: true,
              expandedHeight: 10,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              title: const Text("WalletWatch"),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    _buildTotalRemainingCard(),
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
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.withOpacity(0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.savings, color: Colors.blue),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _amountColor(_totalRemaining),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Expense Breakdown",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              color: Colors.green,
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
              color: Colors.blue,
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
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
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
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    elevation: 0,
                    side: const BorderSide(color: Colors.blue, width: 1.4),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      getInitials(_username),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _useremail,
                          style: const TextStyle(color: Colors.white70),
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
            _drawerItem(Icons.wallet, "Expense Tracker", '/expense_tracker'),
            _drawerItem(Icons.money, "Manage Budget", '/budget_tracker'),
            _drawerItem(Icons.bar_chart, "Reports", "/reports"),
            _drawerItem(Icons.download, "Export Report", "/export_report"),
            _drawerItem(Icons.question_mark, "How To Use", '/how_to_use'),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              color: color,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            percentText,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
