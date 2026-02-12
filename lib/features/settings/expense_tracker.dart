import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/features/expense/edit_expense.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ExpenseTracker extends StatefulWidget {
  const ExpenseTracker({super.key});

  @override
  State<ExpenseTracker> createState() => _ExpenseTrackerState();
}

class _ExpenseTrackerState extends State<ExpenseTracker> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _expenses = [];
  //bool _isLoading = true;
  bool _hasLoadedLocal = false;
  bool _isOnline = false;

  String _filterMode = 'All';

  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  List<String> _availableMonths = [];

  final GlobalKey _monthKey = GlobalKey();
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _expenseTrackerTourDoneKey =
      "walletwatch_expense_tracker_tour_done";

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _startExpenseTrackerTourOnlyOnce() async {
    final done = await _secureStorage.read(key: _expenseTrackerTourDoneKey);
    if (done == "true") return;

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    ShowCaseWidget.of(
      context,
    ).startShowCase([_monthKey, _chartKey, _summaryKey, _filterKey, _listKey]);

    await _secureStorage.write(key: _expenseTrackerTourDoneKey, value: "true");
  }

  Future<bool> _checkConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshExpenses() async {
    await _loadExpenses();
  }

  void _buildAvailableMonths(List<Map<String, dynamic>> expenses) {
    final months =
        expenses
            .map((e) => (e['date'] ?? '').toString().substring(0, 7))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (!_availableMonths.contains(_selectedMonth) && months.isNotEmpty) {
      _selectedMonth = months.first;
    }

    _availableMonths = months;
  }

  Future<void> _loadExpenses() async {
    // STEP 1: Load local instantly
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final localExpenses = await DatabaseHelper.instance.getExpenses(user.id);

    if (!mounted) return;

    setState(() {
      _expenses = localExpenses;
      _buildAvailableMonths(_expenses);
      _hasLoadedLocal = true;
    });

    // STEP 2: Sync in background (DO NOT await)
    _syncExpensesInBackground();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startExpenseTrackerTourOnlyOnce();
    });
  }

  Future<void> _syncExpensesInBackground() async {
    final isOnline = await _checkConnection();
    final user = supabase.auth.currentUser;

    if (!isOnline || user == null) return;

    try {
      // Sync local unsynced expenses
      await _syncLocalToSupabase();

      // Fetch latest from Supabase
      final response = await supabase
          .from('expenses')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false);

      final serverExpenses = List<Map<String, dynamic>>.from(response);

      for (final exp in serverExpenses) {
        await DatabaseHelper.instance.upsertExpenseByUuid({
          'uuid': exp['uuid'],
          'user_id': user.id,
          'supabase_id': exp['id'],
          'date': exp['date'],
          'shop': exp['shop'] ?? '',
          'category': exp['category'] ?? '',
          'items': exp['items'] ?? '',
          'total': exp['total'] ?? 0,
          'mode': exp['mode'] ?? 'Cash',
          'bank': exp['bank'] ?? '',
          'synced': 1,
        });
      }

      // Reload updated data silently
      final updatedExpenses = await DatabaseHelper.instance.getExpenses(
        user.id,
      );

      if (!mounted) return;

      if (mounted && !_listEqualsByUuid(_expenses, updatedExpenses)) {
        setState(() {
          _expenses = updatedExpenses;
          _buildAvailableMonths(_expenses);
        });
      }
    } catch (e) {
      debugPrint("Background sync error: $e");
    }
  }

  bool _listEqualsByUuid(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i]['uuid'] != b[i]['uuid']) return false;
    }

    return true;
  }

  // -----------------Shimmer effect---------------------
  Widget _buildShimmerList() {
    return Column(
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: CircleAvatar(radius: 20, backgroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        height: 12,
                        width: 140,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        height: 10,
                        width: 100,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    final itemsRaw = (expense['items'] ?? '').toString().trim();
    final isTravel = (expense['category'] ?? '').toString() == 'Travel';

    final headers = isTravel
        ? ['Mode', 'From', 'To', 'Amount']
        : ['Item', 'Qty', 'Unit', 'Amount'];

    List<Map<String, dynamic>> parsedItems = [];

    if (itemsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(itemsRaw);
        if (decoded is List) {
          parsedItems = decoded.map<Map<String, dynamic>>((e) {
            return Map<String, dynamic>.from(e as Map);
          }).toList();
        }
      } catch (_) {
        final lines = itemsRaw.split('\n');

        for (final line in lines) {
          final parts = line.split('|').map((e) => e.trim()).toList();

          if (isTravel && parts.length >= 4) {
            parsedItems.add({
              "mode": parts[0],
              "start": parts[1],
              "destination": parts[2],
              "amount": double.tryParse(parts[3]) ?? 0.0,
            });
          } else if (!isTravel && parts.length >= 3) {
            parsedItems.add({
              "name": parts[0],
              "qty": parts[1],
              "unit": "pcs",
              "amount": double.tryParse(parts[2]) ?? 0.0,
            });
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Expense Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              _infoRow('Shop/Type', expense['shop']),
              _infoRow('Date', expense['date']),
              _infoRow('Category', expense['category']),
              _infoRow('Mode', expense['mode']),
              if ((expense['bank'] ?? '').toString().isNotEmpty)
                _infoRow('Bank', expense['bank']),
              _infoRow('Total', '₹${expense['total']}'),

              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 280,
                child: parsedItems.isEmpty
                    ? const Center(child: Text('No item details'))
                    : Column(
                        children: [
                          _tableHeader(headers),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: parsedItems.length,
                              itemBuilder: (_, i) {
                                final item = parsedItems[i];

                                if (isTravel) {
                                  final mode = (item["mode"] ?? "-").toString();
                                  final start = (item["start"] ?? "-")
                                      .toString();
                                  final dest = (item["destination"] ?? "-")
                                      .toString();
                                  final amt = (item["amount"] is num)
                                      ? (item["amount"] as num).toDouble()
                                      : double.tryParse(
                                              item["amount"]?.toString() ?? "",
                                            ) ??
                                            0.0;

                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    color: const Color(0xFFF6F6F6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(mode)),
                                          Expanded(child: Text(start)),
                                          Expanded(child: Text(dest)),
                                          Expanded(
                                            child: Text(
                                              "₹${amt.toStringAsFixed(2)}",
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  final name = (item["name"] ?? "-").toString();
                                  final qty = (item["qty"] ?? "-").toString();
                                  final unit = (item["unit"] ?? "pcs")
                                      .toString();

                                  final amt = (item["amount"] is num)
                                      ? (item["amount"] as num).toDouble()
                                      : double.tryParse(
                                              item["amount"]?.toString() ?? "",
                                            ) ??
                                            0.0;

                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    color: const Color(0xFFF6F6F6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(name)),
                                          Expanded(child: Text(qty)),
                                          Expanded(child: Text(unit)),
                                          Expanded(
                                            child: Text(
                                              "₹${amt.toStringAsFixed(2)}",
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _syncLocalToSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses(user.id);

    for (final exp in unsynced) {
      try {
        final response = await supabase
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
              'bank': exp['bank'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateExpense(exp['id'], {
          'supabase_id': response['id'],
          'synced': 1,
        });
      } catch (e) {
        debugPrint("Sync error: $e");
      }
    }
  }

  String _formatDate(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;

    final diff = DateTime.now().difference(parsed).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  double get _totalCash => _filteredExpenses
      .where((e) => (e['mode'] ?? '').toString().toLowerCase() == 'cash')
      .fold(0.0, (sum, e) => sum + (e['total'] as num).toDouble());

  double get _totalOnline => _filteredExpenses
      .where((e) => (e['mode'] ?? '').toString().toLowerCase() == 'online')
      .fold(0.0, (sum, e) => sum + (e['total'] as num).toDouble());

  double get _grandTotal => _totalCash + _totalOnline;

  List<Map<String, dynamic>> get _filteredExpenses {
    return _expenses.where((e) {
      final date = (e['date'] ?? '').toString();
      final matchesMonth = date.startsWith(_selectedMonth);

      if (_filterMode == 'All') return matchesMonth;

      return matchesMonth &&
          (e['mode'] ?? '').toString().toLowerCase() ==
              _filterMode.toLowerCase();
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedByDate {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final e in _filteredExpenses) {
      final date = e['date'] ?? '';
      map.putIfAbsent(date, () => []).add(e);
    }

    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  Widget _buildExpensePieChart() {
    final total = _grandTotal;

    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          "No expenses for this month",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 42,
          sectionsSpace: 2,
          sections: [
            PieChartSectionData(
              value: _totalCash,
              color: Colors.green,
              title: "${((_totalCash / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              value: _totalOnline,
              color: Colors.blue,
              title: "${((_totalOnline / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(Map<String, dynamic> exp) async {
    final localId = exp['id'];
    final supabaseId = exp['supabase_id'];
    final uuid = exp['uuid'];

    await DatabaseHelper.instance.deleteExpense(localId);

    final user = supabase.auth.currentUser;
    if (user != null) {
      if (supabaseId != null) {
        await supabase.from('expenses').delete().eq('id', supabaseId);
      } else if (uuid != null) {
        await supabase.from('expenses').delete().eq('uuid', uuid);
      }
    }

    await _loadExpenses();
  }

  Widget _buildExpenseCard(Map<String, dynamic> exp) {
    final amount = (exp['total'] as num).toDouble();
    final isOnline = (exp['mode'] ?? '').toString().toLowerCase() == 'online';

    final badgeColor = isOnline ? Colors.blue : Colors.green;
    final badgeText = isOnline ? "Online" : "Cash";

    return InkWell(
      onTap: () => _showExpenseDetails(exp),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: badgeColor.withOpacity(0.12),
              child: Icon(
                isOnline ? Icons.account_balance_wallet_outlined : Icons.money,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (exp['shop'] ?? 'Unknown').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_formatDate(exp['date'])} • ${exp['category']}",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: badgeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "₹${amount.toStringAsFixed(2)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.5,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(List<String> headers) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: headers
            .map(
              (h) => Expanded(
                child: Text(
                  h,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete expense?'),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
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

  Widget _buildHeader() {
    return Container(
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
              "Expense Tracker",
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
            child: const Icon(Icons.receipt_long, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF6F6F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshExpenses,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 6, bottom: 18),
                  children: [
                    if (_availableMonths.isNotEmpty)
                      Showcase(
                        key: _monthKey,
                        description:
                            "Select month to see expenses for that month",
                        child: _sectionContainer(
                          child: DropdownButtonFormField<String>(
                            value: _availableMonths.contains(_selectedMonth)
                                ? _selectedMonth
                                : null,
                            decoration: _pillDecoration(
                              hint: "Select Month",
                              icon: Icons.calendar_month,
                            ),
                            items: _availableMonths
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      DateFormat(
                                        'MMMM yyyy',
                                      ).format(DateTime.parse('$m-01')),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedMonth = value);
                              }
                            },
                          ),
                        ),
                      ),
                    Showcase(
                      key: _chartKey,
                      description: "Shows Cash vs Online expense split",
                      child: _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Expense Breakdown",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildExpensePieChart(),
                            const SizedBox(height: 10),
                            _buildPieLegend(),
                          ],
                        ),
                      ),
                    ),
                    Showcase(
                      key: _summaryKey,
                      description:
                          "This shows total, cash and online spending for the month",
                      child: _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Summary",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "₹${_grandTotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Cash",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${_totalCash.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Online",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${_totalOnline.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Showcase(
                              key: _filterKey,
                              description:
                                  "Filter expenses by payment mode: All / Cash / Online",
                              child: Wrap(
                                spacing: 8,
                                children: ['All', 'Cash', 'Online']
                                    .map(
                                      (m) => ChoiceChip(
                                        label: Text(m),
                                        selected: _filterMode == m,
                                        selectedColor: Colors.blue.withOpacity(
                                          0.18,
                                        ),
                                        labelStyle: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _filterMode == m
                                              ? Colors.blue
                                              : Colors.black,
                                        ),
                                        onSelected: (_) =>
                                            setState(() => _filterMode = m),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Showcase(
                      key: _listKey,
                      description:
                          "Tap any expense to see details. Swipe to Edit/Delete",
                      child: !_hasLoadedLocal
                          ? _buildShimmerList() // or shimmer
                          : _filteredExpenses.isEmpty
                          ? _sectionContainer(
                              child: Column(
                                children: [
                                  Container(
                                    height: 70,
                                    width: 70,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long,
                                      color: Colors.blue,
                                      size: 38,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No expenses found",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Try selecting a different month or add a new expense.",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: _groupedByDate.entries.map((entry) {
                                final dateTotal = entry.value.fold<double>(
                                  0,
                                  (sum, e) =>
                                      sum + (e['total'] as num).toDouble(),
                                );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        14,
                                        18,
                                        4,
                                      ),
                                      child: Text(
                                        "${_formatDate(entry.key)} • ₹${dateTotal.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                    ...entry.value.map((e) {
                                      return Dismissible(
                                        key: ValueKey(e['uuid']),
                                        direction: DismissDirection.horizontal,

                                        background: Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.only(
                                            left: 18,
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Edit',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        secondaryBackground: Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(
                                            right: 18,
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                        ),

                                        confirmDismiss: (direction) async {
                                          if (direction ==
                                              DismissDirection.startToEnd) {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EditExpensePage(expense: e),
                                              ),
                                            );
                                            await _loadExpenses();
                                            return false;
                                          }

                                          if (direction ==
                                              DismissDirection.endToStart) {
                                            final confirm =
                                                await _confirmDeleteDialog();
                                            if (confirm) {
                                              await _deleteExpense(e);
                                            }
                                            return confirm;
                                          }

                                          return false;
                                        },

                                        child: _buildExpenseCard(e),
                                      );
                                    }),
                                  ],
                                );
                              }).toList(),
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
