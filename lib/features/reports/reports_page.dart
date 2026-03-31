import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
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

  final supabase = Supabase.instance.client;

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

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  //------------------------Function to Load Data---------------------------------------
  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final expenses = await DatabaseHelper.instance.getExpenses(user.id);
    final budgets = await DatabaseHelper.instance.getBudget(user.id);

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

    if (monthList.isNotEmpty && !monthList.contains(_selectedMonth)) {
      _selectedMonth = monthList.first;
    }

    final monthExpenses = expenses
        .where((e) => (e['date'] ?? '').toString().startsWith(_selectedMonth))
        .toList();

    final monthBudgets = budgets
        .where((b) => (b['date'] ?? '').toString().startsWith(_selectedMonth))
        .toList();

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

  //---------------------------Helper----------------------------------
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

  //---------------------------------UI-----------------------------------------
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
              "Reports",
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
              Icons.pie_chart_outline,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.primary),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _summaryTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
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
              color: colorScheme.secondary,
              title: "${((_cashExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: TextStyle(
                color: Theme.of(context).colorScheme.surface,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              value: _onlineExpense,
              color: colorScheme.primary,
              title: "${((_onlineExpense / total) * 100).toStringAsFixed(0)}%",
              titleStyle: TextStyle(
                color: colorScheme.surface,
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
            final color =
                _categoryColors[e.key] ?? colorScheme.onSurfaceVariant;

            return PieChartSectionData(
              value: e.value,
              color: color,
              title: percent >= 8 ? "${percent.toStringAsFixed(0)}%" : "",
              titleStyle: TextStyle(
                color: colorScheme.surface,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 6, bottom: 18),
                        children: [
                          _sectionContainer(
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
                          _sectionContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Summary",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _summaryTile(
                                  title: "Total Expense",
                                  value: "₹${_totalExpense.toStringAsFixed(2)}",
                                  icon: Icons.money,
                                  iconColor: colorScheme.error,
                                  valueColor: colorScheme.error,
                                ),
                                const SizedBox(height: 10),
                                _summaryTile(
                                  title: "Total Budget",
                                  value: "₹${_totalBudget.toStringAsFixed(2)}",
                                  icon: Icons.account_balance_wallet_outlined,
                                  iconColor: colorScheme.primary,
                                  valueColor: colorScheme.primary,
                                ),
                                const SizedBox(height: 10),
                                _summaryTile(
                                  title: "Remaining",
                                  value: "₹${_remaining.toStringAsFixed(2)}",
                                  icon: _remaining >= 0
                                      ? Icons.check_circle_outline
                                      : Icons.warning_amber_outlined,
                                  iconColor: _remaining >= 0
                                      ? colorScheme.secondary
                                      : colorScheme.error,
                                  valueColor: _remaining >= 0
                                      ? colorScheme.secondary
                                      : colorScheme.error,
                                ),
                              ],
                            ),
                          ),
                          _sectionContainer(
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
                                    _legendRow(colorScheme.secondary, "Cash"),
                                    const SizedBox(width: 16),
                                    _legendRow(colorScheme.primary, "Online"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _sectionContainer(
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
                                ..._categoryTotals.entries
                                    .toList()
                                    .sortedByDesc((e) => e.value)
                                    .take(6)
                                    .map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color:
                                                    _categoryColors[e.key] ??
                                                    colorScheme
                                                        .onSurfaceVariant,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                e.key,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "₹${e.value.toStringAsFixed(2)}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          _sectionContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Insights",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                _insightRow("Top Category", _topCategory),
                                const SizedBox(height: 6),
                                _insightRow("Most used mode", _mostUsedMode),
                                const SizedBox(height: 6),
                                _insightRow(
                                  "Budget usage",
                                  _totalBudget <= 0
                                      ? "No budget set"
                                      : "${((_totalExpense / _totalBudget) * 100).toStringAsFixed(0)}%",
                                ),
                              ],
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

  Widget _insightRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

extension ListSortExt<T> on List<T> {
  List<T> sortedByDesc(num Function(T e) key) {
    final copy = [...this];
    copy.sort((a, b) => key(b).compareTo(key(a)));
    return copy;
  }
}
