import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  //------------Derived values
  double get _cashRemaining => _cashBudget - _cashExpense;
  double get _onlineRemaining => _onlineBudget - _onlineExpense;
  double get _totalRemaining => _cashRemaining + _onlineRemaining;

  Color _amountColor(double value) =>
      value >= 0 ? Colors.green : Colors.redAccent;

  double get _cashProgress {
    if (_cashBudget <= 0) return 0.0;
    final ratio = _cashExpense / _cashBudget;
    return ratio.clamp(0.0, 1.0);
  }

  double get _onlineProgress {
    if (_onlineBudget <= 0) return 0.0;
    final ratio = _onlineExpense / _onlineBudget;
    return ratio.clamp(0.0, 1.0);
  }

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

    // Fetch user details from 'users' table
    final response = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      setState(() {
        _username = response['name'] ?? 'User';
        _useremail = response['email'] ?? 'example@gmail.com';
      });
    }
  }

  Future<void> _loadExpensesSeparately() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final currentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final response = await supabase
        .from('expenses')
        .select('date, mode, total')
        .eq('user_id', user.id);

    double cash = 0.0;
    double online = 0.0;

    for (final item in response) {
      final date = item['date']?.toString();
      if (date != null && date.startsWith(currentMonth)) {
        final amount = (item['total'] as num).toDouble();
        final modeRaw = (item['mode'] ?? 'Cash')
            .toString()
            .trim()
            .toLowerCase();

        if (modeRaw == 'cash') {
          cash += amount;
        } else if (modeRaw == 'online') {
          online += amount;
        } else {
          cash += amount;
        }
      }
    }

    setState(() {
      _cashExpense = cash;
      _onlineExpense = online;
    });
  }

  Future<void> _loadBudgetsSeparately() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('budgets')
        .select('mode, total')
        .eq('user_id', user.id);

    double cash = 0.0;
    double online = 0.0;

    for (final entry in response) {
      final mode = (entry['mode'] ?? 'Cash').toString();
      final amount = (entry['total'] as num).toDouble();

      if (mode == 'Cash') {
        cash += amount;
      } else if (mode == 'Online') {
        online += amount;
      }
    }

    setState(() {
      _cashBudget = cash;
      _onlineBudget = online;
    });
  }

  String getInitials(String name) {
    if (name.trim().isEmpty) return "";

    List<String> parts = name.trim().split(" ");

    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String currentMonthYear() {
    final now = DateTime.now();
    return DateFormat("MMMM yyyy").format(now);
  }

  Future<void> _logout() async {
    final shouldlogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    if (shouldlogout == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _refreshAll() async {
    await _loadBudgetsSeparately();
    await _loadExpensesSeparately();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        title: const Text("WalletWatch"),
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
                    //----------- Total Remaining Card------------------
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.savings),
                        title: Text("Total Remaining • ${currentMonthYear()}"),
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

                    //-------------------- Cash & Online Remaining -----------------
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                            child: ListTile(
                              leading: const Icon(Icons.money),
                              title: const Text("Cash Remaining"),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "₹ ${_cashRemaining.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: _amountColor(_cashRemaining),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(value: _cashProgress),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatPercent(_cashExpense, _cashBudget),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                              title: const Text("Online Remaining"),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "₹ ${_onlineRemaining.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: _amountColor(_onlineRemaining),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: _onlineProgress,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatPercent(
                                      _onlineExpense,
                                      _onlineBudget,
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 🔥 Bottom Fixed Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 350),
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
          ],
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  border: BoxBorder.all(width: 1),
                  color: Colors.blue,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Color.fromARGB(255, 165, 255, 137),
                      child: Text(
                        getInitials(_username),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      _useremail,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("My Profile"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profiles');
                },
              ),
              const Divider(thickness: 1),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About us'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/about');
                },
              ),
              const Divider(thickness: 1),
              ListTile(
                leading: const Icon(Icons.wallet),
                title: const Text("Expense Tracker"),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.pushNamed(context, '/expense_tracker');
                  _loadExpensesSeparately();
                },
              ),
              const Divider(thickness: 1),
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text("Manage Budget"),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.pushNamed(context, '/budget_tracker');
                  _loadBudgetsSeparately();
                },
              ),
              const Divider(thickness: 1),
              ListTile(
                leading: const Icon(Icons.question_mark),
                title: const Text("How To Use"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/how_to_use');
                },
              ),
              const Divider(thickness: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Sign Out"),
                onTap: () => _logout(),
              ),
              const Divider(thickness: 1),
            ],
          ),
        ),
      ),
      // floatingActionButton: Column(
      //   mainAxisSize: MainAxisSize.min,
      //   crossAxisAlignment: CrossAxisAlignment.end,
      //   children: [
      //     FloatingActionButton.extended(
      //       heroTag: 'fab_expense',
      //       onPressed: () async {
      //         await Navigator.pushNamed(context, '/add_expense');
      //         _loadExpensesSeparately(); // refresh after coming back
      //       },
      //       icon: const Icon(Icons.add),
      //       label: const Text('Add Expense'),
      //     ),
      //     const SizedBox(height: 12),
      //     FloatingActionButton.extended(
      //       heroTag: 'fab_budget',
      //       onPressed: () async {
      //         await Navigator.pushNamed(context, '/budget');
      //         _loadBudgetsSeparately(); // refresh after coming back
      //       },
      //       icon: const Icon(Icons.account_balance_wallet),
      //       label: const Text('Add Budget'),
      //     ),
      //   ],
      // ),
    );
  }
}
