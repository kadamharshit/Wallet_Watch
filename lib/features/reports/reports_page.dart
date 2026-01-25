import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:walletwatch/services/expense_database.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;

  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  List<String> _availableMonths = [];

  double _totalExpense = 0.0;
  double _cashExpense = 0.0;
  double _onlineExpense = 0.0;

  double _totalBudget = 0.0;
  double _cashBudget = 0.0;
  double _onlineBudget = 0.0;

  Map<String, double> _categoryTotals = {};

  final Map<String, Color> _categoryColors = {
    "Grocery": Colors.green,
    "Travel": Colors.orange,
    "Food": Colors.red,
    "Medical": Colors.purple,
    "Bills": Colors.blueGrey,
    "Other": Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // ---------------- MAIN LOAD ----------------
  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    final expenses = await DatabaseHelper.instance.getExpenses();
    final budgets = await DatabaseHelper.instance.getBudget();

    // ✅ build available months from BOTH budgets + expenses
    final months = <String>{};

    for (final e in expenses) {
      final date = (e['date'] ?? '').toString();
      if (date.length >= 7) months.add(date.substring(0, 7));
    }
    for (final b in budgets) {
      final date = (b['date'] ?? '').toString();
      if (date.length >= 7) months.add(date.substring(0, 7));
    }

    final monthList = months.toList()..sort((a, b) => b.compareTo(a));

    // if selected month is not available, pick latest
    if (monthList.isNotEmpty && !monthList.contains(_selectedMonth)) {
      _selectedMonth = monthList.first;
    }

    // ✅ filter month-wise
    final monthExpenses = expenses
        .where((e) => (e['date'] ?? '').toString().startsWith(_selectedMonth))
        .toList();

    final monthBudgets = budgets
        .where((b) => (b['date'] ?? '').toString().startsWith(_selectedMonth))
        .toList();

    // ✅ calculate expense totals
    double totalExp = 0;
    double cashExp = 0;
    double onlineExp = 0;

    final categoryMap = <String, double>{};

    for (final e in monthExpenses) {
      final amount = (e['total'] as num?)?.toDouble() ?? 0.0;
      totalExp += amount;

      final mode = (e['mode'] ?? 'Cash').toString().toLowerCase();
      if (mode == 'online') {
        onlineExp += amount;
      } else {
        cashExp += amount;
      }

      final cat = (e['category'] ?? 'Other').toString();
      categoryMap[cat] = (categoryMap[cat] ?? 0) + amount;
    }

    // ✅ calculate budget totals
    double totalBud = 0;
    double cashBud = 0;
    double onlineBud = 0;

    for (final b in monthBudgets) {
      final amount = (b['total'] as num?)?.toDouble() ?? 0.0;
      totalBud += amount;

      final mode = (b['mode'] ?? 'Cash').toString();
      if (mode == 'Online') {
        onlineBud += amount;
      } else {
        cashBud += amount;
      }
    }

    setState(() {
      _availableMonths = monthList;
      _totalExpense = totalExp;
      _cashExpense = cashExp;
      _onlineExpense = onlineExp;

      _totalBudget = totalBud;
      _cashBudget = cashBud;
      _onlineBudget = onlineBud;

      _categoryTotals = categoryMap;
      _isLoading = false;
    });
  }

  // ---------------- HELPERS ----------------
  String _monthLabel(String m) {
    try {
      return DateFormat('MMMM yyyy').format(DateTime.parse("$m-01"));
    } catch (_) {
      return m;
    }
  }

  double get _remaining => _totalBudget - _totalExpense;

  String get _topCategory {
    if (_categoryTotals.isEmpty) return "-";
    final sorted = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String get _mostUsedMode {
    if (_cashExpense == 0 && _onlineExpense == 0) return "-";
    return _cashExpense >= _onlineExpense ? "Cash" : "Online";
  }

  // ---------------- UI WIDGETS ----------------
  Widget _summaryCard(String title, String value, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.12),
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCashOnlinePie() {
    final total = _cashExpense + _onlineExpense;
    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("No expense data for this month"),
      );
    }

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 45,
          sectionsSpace: 2,
          sections: [
            PieChartSectionData(
              value: _cashExpense,
              color: Colors.green,
              title: "${((_cashExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              value: _onlineExpense,
              color: Colors.blue,
              title: "${((_onlineExpense / total) * 100).toStringAsFixed(0)}%",
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

  Widget _buildCategoryPie() {
    if (_categoryTotals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("No category data found"),
      );
    }

    final total = _categoryTotals.values.fold<double>(0, (a, b) => a + b);

    final entries = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 45,
          sectionsSpace: 2,
          sections: entries.map((e) {
            final percent = total == 0 ? 0 : (e.value / total * 100);

            final color = _categoryColors[e.key] ?? Colors.grey;

            return PieChartSectionData(
              value: e.value,
              color: color,
              title: percent >= 8 ? "${percent.toStringAsFixed(0)}%" : "",
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _legendRow(Color c, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          //IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  // Month Dropdown
                  Row(
                    children: [
                      const Icon(Icons.calendar_month),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _availableMonths.contains(_selectedMonth)
                              ? _selectedMonth
                              : null,
                          decoration: const InputDecoration(
                            labelText: "Select Month",
                            border: OutlineInputBorder(),
                          ),
                          items: _availableMonths
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(_monthLabel(m)),
                                ),
                              )
                              .toList(),
                          onChanged: (val) async {
                            if (val == null) return;
                            setState(() => _selectedMonth = val);
                            await _loadReports();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _summaryCard(
                    "Total Expense",
                    "₹${_totalExpense.toStringAsFixed(2)}",
                    Icons.money,
                  ),
                  _summaryCard(
                    "Total Budget",
                    "₹${_totalBudget.toStringAsFixed(2)}",
                    Icons.account_balance_wallet,
                  ),
                  _summaryCard(
                    "Remaining",
                    "₹${_remaining.toStringAsFixed(2)}",
                    _remaining >= 0 ? Icons.check_circle : Icons.warning,
                  ),

                  const SizedBox(height: 14),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Cash vs Online Expenses",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          _buildCashOnlinePie(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _legendRow(Colors.green, "Cash"),
                              const SizedBox(width: 16),
                              _legendRow(Colors.blue, "Online"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Category-wise Expenses",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          _buildCategoryPie(),
                          const SizedBox(height: 10),

                          // show top categories list
                          ..._categoryTotals.entries
                              .toList()
                              .sortedByDesc((e) => e.value)
                              .take(6)
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(e.key)),
                                      Text(
                                        "₹${e.value.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
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

                  const SizedBox(height: 14),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Insights",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text("• Top Category: $_topCategory"),
                          Text("• Most used payment mode: $_mostUsedMode"),
                          Text(
                            "• Budget Usage: ${_totalBudget <= 0 ? "No budget set" : "${((_totalExpense / _totalBudget) * 100).toStringAsFixed(0)}%"}",
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

// ✅ small extension for sorting
extension ListSortExt<T> on List<T> {
  List<T> sortedByDesc(num Function(T e) key) {
    final copy = [...this];
    copy.sort((a, b) => key(b).compareTo(key(a)));
    return copy;
  }
}
