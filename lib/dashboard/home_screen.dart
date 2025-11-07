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
        .from('budget')
        .select('mode, amount')
        .eq('user_id', user.id);

    double cash = 0.0;
    double online = 0.0;

    for (final entry in response) {
      final mode = (entry['mode'] ?? 'Cash').toString();
      final amount = (entry['amount'] as num).toDouble();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Tracker"),
        // actions: [
        //   IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        // ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text("Cash Expense ${currentMonthYear()}"),
                subtitle: Text("₹ ${_cashExpense.toStringAsFixed(2)}"),
                leading: const Icon(Icons.money),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text("Online Expense ${currentMonthYear()}"),
                subtitle: Text("₹ ${_onlineExpense.toStringAsFixed(2)}"),
                leading: const Icon(Icons.account_balance_wallet),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text("Cash Budget ${currentMonthYear()}"),
                subtitle: Text("₹ ${_cashBudget.toStringAsFixed(2)}"),
                leading: const Icon(Icons.money),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text("Online Budget ${currentMonthYear()}"),
                subtitle: Text("₹ ${_onlineBudget.toStringAsFixed(2)}"),
                leading: const Icon(Icons.account_balance_wallet),
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
                decoration: const BoxDecoration(color: Colors.blue),
                child: UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Colors.lightBlue),
                  accountName: Text(_username),
                  accountEmail: Text(_useremail),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Color.fromARGB(255, 165, 255, 137),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("My Profile"),
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/profiles'),
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About us'),
                onTap: () => Navigator.pushNamed(context, '/about'),
              ),
              ListTile(
                leading: const Icon(Icons.wallet),
                title: const Text("Expense Tracker"),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.pushNamed(context, '/expense_tracker');
                  _loadExpensesSeparately();
                },
              ),
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text("Manage Budget"),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.pushNamed(context, '/budget_tracker');
                  _loadBudgetsSeparately();
                },
              ),
              ListTile(
                leading: const Icon(Icons.question_mark),
                title: const Text("How To Use"),
                onTap: () => Navigator.pushNamed(context, '/how_to_use'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Sign Out"),
                onTap: () => _logout(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add Expense'),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.pushNamed(context, '/expense');
                        _loadExpensesSeparately();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: const Text('Add Budget'),
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.pushNamed(context, '/budget');
                        _loadBudgetsSeparately();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
