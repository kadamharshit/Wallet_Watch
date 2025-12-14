import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
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

  final supabase = Supabase.instance.client;

  // Derived values
  double get _cashRemaining => _cashBudget - _cashExpense;
  double get _onlineRemaining => _onlineBudget - _onlineExpense;
  double get _totalRemaining => _cashRemaining + _onlineRemaining;

  Color _amountColor(double value) =>
      value >= 0 ? Colors.green : Colors.redAccent;

  double get _cashProgress =>
      _cashBudget <= 0 ? 0.0 : (_cashExpense / _cashBudget).clamp(0.0, 1.0);

  double get _onlineProgress => _onlineBudget <= 0
      ? 0.0
      : (_onlineExpense / _onlineBudget).clamp(0.0, 1.0);

  String _formatPercent(double used, double total) {
    if (total <= 0) return "No budget set";
    final percent = (used / total * 100).clamp(0, 999).toStringAsFixed(0);
    return "$percent% of budget used";
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadExpensesSeparately();
    _loadBudgetsSeparately();
  }

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

  //------------------Pie Chart----------------------------
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
      height: 220,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: [
            PieChartSectionData(
              value: _cashExpense,
              color: Colors.green,
              radius: 50,
              title: "${((_cashExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: _onlineExpense,
              color: Colors.blue,
              radius: 50,
              title: "${((_onlineExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
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

      if (mode == 'Online') {
        online += amount;
      } else {
        cash += amount;
      }
    }

    setState(() {
      _cashBudget = cash;
      _onlineBudget = online;
    });
  }

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
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WalletWatch"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Total Remaining
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.savings, size: 32),
                        title: Text(
                          "Total Remaining • ${currentMonthYear()}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "₹ ${_totalRemaining.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _amountColor(_totalRemaining),
                          ),
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Expense Breakdown",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildExpensePieChart(),
                            const SizedBox(height: 12),
                            _buildPieLegend(),
                          ],
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        _buildRemainingCard(
                          title: "Cash Remaining",
                          icon: Icons.money,
                          amount: _cashRemaining,
                          progress: _cashProgress,
                          percentText: _formatPercent(
                            _cashExpense,
                            _cashBudget,
                          ),
                          color: Colors.green,
                          margin: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        ),
                        _buildRemainingCard(
                          title: "Online Remaining",
                          icon: Icons.account_balance_wallet_outlined,
                          amount: _onlineRemaining,
                          progress: _onlineProgress,
                          percentText: _formatPercent(
                            _onlineExpense,
                            _onlineBudget,
                          ),
                          color: Colors.blue,
                          margin: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Expense"),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/add_expense');
                          _loadExpensesSeparately();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text("Add Budget"),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/budget');
                          _loadBudgetsSeparately();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: Text(
                        getInitials(_username),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _useremail,
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _drawerItem(Icons.person, "My Profile", '/profiles'),
              _drawerItem(Icons.info, "About Us", '/about'),
              _drawerItem(Icons.wallet, "Expense Tracker", '/expense_tracker'),
              _drawerItem(Icons.money, "Manage Budget", '/budget_tracker'),
              _drawerItem(Icons.question_mark, "How To Use", '/how_to_use'),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Sign Out"),
                onTap: _logout,
              ),
            ],
          ),
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

  Widget _buildRemainingCard({
    required String title,
    required IconData icon,
    required double amount,
    required double progress,
    required String percentText,
    required Color color,
    required EdgeInsets margin,
  }) {
    return Expanded(
      child: Card(
        margin: margin,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "₹ ${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  color: _amountColor(amount),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                color: color,
                backgroundColor: Colors.grey.shade300,
              ),
              const SizedBox(height: 2),
              Text(percentText, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
