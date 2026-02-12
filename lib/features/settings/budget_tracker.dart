import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BudgetTracker extends StatefulWidget {
  const BudgetTracker({super.key});

  @override
  State<BudgetTracker> createState() => _BudgetTrackerState();
}

class _BudgetTrackerState extends State<BudgetTracker> {
  List<Map<String, dynamic>> _filteredBudgets = [];

  double _cashTotal = 0.0;
  double _onlineTotal = 0.0;

  List<String> _availableMonths = [];

  String _filterMode = 'All';
  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  final GlobalKey _monthKey = GlobalKey();
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _budgetTrackerTourDoneKey =
      "walletwatch_budget_tracker_tour_done";

  @override
  void initState() {
    super.initState();
    _loadBudgetsForMonth(_selectedMonth);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBudgetTrackerTourOnlyOnce();
    });
  }

  Future<void> _refreshBudgets() async {
    await _loadBudgetsForMonth(_selectedMonth);
  }

  Future<void> _startBudgetTrackerTourOnlyOnce() async {
    final done = await _secureStorage.read(key: _budgetTrackerTourDoneKey);
    if (done == "true") return;

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    ShowCaseWidget.of(
      context,
    ).startShowCase([_monthKey, _chartKey, _summaryKey, _filterKey, _listKey]);

    await _secureStorage.write(key: _budgetTrackerTourDoneKey, value: "true");
  }

  Future<void> _loadBudgetsForMonth(String month) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final allBudgets = await DatabaseHelper.instance.getBudget(
      user.id,
    ); // ✅ FIX

    final months =
        allBudgets
            .map((b) => (b['date'] ?? '').toString().substring(0, 7))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (!months.contains(month)) {
      month = months.isNotEmpty ? months.first : month;
    }

    final filtered = allBudgets
        .where((b) => (b['date'] ?? '').toString().startsWith(month))
        .toList();

    double cash = 0;
    double online = 0;

    for (final b in filtered) {
      final amount = (b['total'] as num?)?.toDouble() ?? 0;
      if ((b['mode'] ?? '') == 'Cash') {
        cash += amount;
      } else {
        online += amount;
      }
    }

    setState(() {
      _availableMonths = months;
      _selectedMonth = month;
      _filteredBudgets = filtered;
      _cashTotal = cash;
      _onlineTotal = online;
    });
  }

  List<Map<String, dynamic>> get _filteredByMode {
    if (_filterMode == 'All') return _filteredBudgets;

    return _filteredBudgets.where((b) {
      return (b['mode'] ?? '').toString().toLowerCase() ==
          _filterMode.toLowerCase();
    }).toList();
  }

  Future<void> _showEditDialog(Map<String, dynamic> entry) async {
    final controller = TextEditingController(text: entry['total'].toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Budget"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Amount"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value != null) {
                await DatabaseHelper.instance.updateBudget(entry['id'], {
                  'total': value,
                });

                final supabaseId = entry['supabase_id'];
                if (supabaseId != null) {
                  await Supabase.instance.client
                      .from('budgets')
                      .update({'total': value})
                      .eq('id', supabaseId);
                }

                Navigator.pop(context);
                _loadBudgetsForMonth(_selectedMonth);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(Map<String, dynamic> entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete budget?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (result == true) {
      await DatabaseHelper.instance.deleteBudget(entry['id']);

      if (entry['supabase_id'] != null) {
        await Supabase.instance.client
            .from('budgets')
            .delete()
            .eq('id', entry['supabase_id']);
      }

      _loadBudgetsForMonth(_selectedMonth);
      return true;
    }
    return false;
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
              "Budget Tracker",
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
            child: const Icon(Icons.wallet_outlined, color: Colors.white),
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

  Widget _buildBudgetPieChart() {
    final total = _cashTotal + _onlineTotal;

    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: Text(
          "No budget data for this month",
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
              value: _cashTotal,
              color: Colors.green,
              title: "${((_cashTotal / total) * 100).toStringAsFixed(0)}%",
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              value: _onlineTotal,
              color: Colors.blue,
              title: "${((_onlineTotal / total) * 100).toStringAsFixed(0)}%",
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

  Widget _buildSummary() {
    final total = _cashTotal + _onlineTotal;

    final cashFrac = total == 0 ? 0 : _cashTotal / total;
    final onlineFrac = total == 0 ? 0 : _onlineTotal / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "This Month's Budget",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Text(
          "₹${total.toStringAsFixed(2)}",
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cash",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${_cashTotal.toStringAsFixed(2)}",
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Online",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${_onlineTotal.toStringAsFixed(2)}",
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
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              Expanded(
                flex: (cashFrac * 1000).round().clamp(0, 1000),
                child: Container(height: 7, color: Colors.green),
              ),
              Expanded(
                flex: (onlineFrac * 1000).round().clamp(0, 1000),
                child: Container(height: 7, color: Colors.blue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> item) {
    final amount = (item['total'] as num?)?.toDouble() ?? 0;
    final isOnline = (item['mode'] ?? '') == 'Online';

    return Dismissible(
      key: ValueKey(item['id']),
      background: _slideBg(
        Icons.edit,
        'Edit',
        Colors.blue,
        Alignment.centerLeft,
      ),
      secondaryBackground: _slideBg(
        Icons.delete,
        'Delete',
        Colors.redAccent,
        Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _showEditDialog(item);
          return false;
        }
        return await _confirmDelete(item);
      },
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
              backgroundColor: isOnline
                  ? Colors.blue.withOpacity(0.12)
                  : Colors.green.withOpacity(0.12),
              child: Icon(
                isOnline ? Icons.account_balance_wallet_outlined : Icons.money,
                color: isOnline ? Colors.blue : Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline && (item['bank'] ?? '').toString().isNotEmpty
                        ? item['bank']
                        : '${item['mode']} Budget',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Date: ${item['date']}",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              "₹${amount.toStringAsFixed(2)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slideBg(
    IconData icon,
    String text,
    Color color,
    Alignment alignment,
  ) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white)),
          ] else ...[
            Text(text, style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredByMode;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshBudgets,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 6, bottom: 18),
                  children: [
                    Showcase(
                      key: _monthKey,
                      description:
                          "Select month to view budgets for that month",
                      child: _sectionContainer(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
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
                              _loadBudgetsForMonth(value);
                            }
                          },
                        ),
                      ),
                    ),
                    Showcase(
                      key: _chartKey,
                      description:
                          "This chart shows Cash vs Online budget split",
                      child: _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Budget Breakdown",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildBudgetPieChart(),
                            const SizedBox(height: 10),
                            _buildPieLegend(),
                          ],
                        ),
                      ),
                    ),
                    Showcase(
                      key: _summaryKey,
                      description:
                          "This shows total budget, cash total & online total",
                      child: _sectionContainer(child: _buildSummary()),
                    ),
                    Showcase(
                      key: _filterKey,
                      description:
                          "Filter budget entries by mode: All / Cash / Online",
                      child: _sectionContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Filter",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
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
                          ],
                        ),
                      ),
                    ),
                    Showcase(
                      key: _listKey,
                      description:
                          "Swipe cards to Edit or Delete budget entries",
                      child: list.isEmpty
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
                                      Icons.wallet_outlined,
                                      color: Colors.blue,
                                      size: 38,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No budget entries found",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Try selecting a different month or add a budget.",
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
                              children: list.map(_buildBudgetCard).toList(),
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
