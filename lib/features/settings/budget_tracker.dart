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

  String _filterMode = 'All'; // All / Cash / Online
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

  // List<String> _getAvailableMonths() {
  //   final months = _filteredBudgets
  //       .map((b) => (b['date'] ?? '').toString().substring(0, 7))
  //       .toSet()
  //       .toList();

  //   months.sort((a, b) => b.compareTo(a)); // latest first
  //   return months;
  // }

  Future<void> _startBudgetTrackerTourOnlyOnce() async {
    final done = await _secureStorage.read(key: _budgetTrackerTourDoneKey);
    if (done == "true") return;

    if (!mounted) return;

    // small delay so UI loads nicely
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    ShowCaseWidget.of(
      context,
    ).startShowCase([_monthKey, _chartKey, _summaryKey, _filterKey, _listKey]);

    await _secureStorage.write(key: _budgetTrackerTourDoneKey, value: "true");
  }

  // ---------------- LOAD ----------------
  Future<void> _loadBudgetsForMonth(String month) async {
    final allBudgets = await DatabaseHelper.instance.getBudget();

    // ✅ Build available months safely
    final months =
        allBudgets
            .map((b) => (b['date'] ?? '').toString().substring(0, 7))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    // ✅ Ensure selected month exists
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

  // ---------------- FILTER ----------------
  List<Map<String, dynamic>> get _filteredByMode {
    if (_filterMode == 'All') return _filteredBudgets;

    return _filteredBudgets.where((b) {
      return (b['mode'] ?? '').toString().toLowerCase() ==
          _filterMode.toLowerCase();
    }).toList();
  }

  // ---------------- EDIT ----------------
  Future<void> _showEditDialog(Map<String, dynamic> entry) async {
    final controller = TextEditingController(text: entry['total'].toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ---------------- DELETE ----------------
  Future<bool> _confirmDelete(Map<String, dynamic> entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete budget?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  // ---------------- SUMMARY ----------------
  Widget _buildSummary() {
    final total = _cashTotal + _onlineTotal;

    final cashFrac = total == 0 ? 0 : _cashTotal / total;
    final onlineFrac = total == 0 ? 0 : _onlineTotal / total;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This Month's Budget",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              "Total: ₹${total.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: Text("Cash: ₹${_cashTotal.toStringAsFixed(2)}"),
                ),
                Expanded(
                  child: Text(
                    "Online: ₹${_onlineTotal.toStringAsFixed(2)}",
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Row(
                children: [
                  Expanded(
                    flex: (cashFrac * 1000).round(),
                    child: Container(height: 6, color: Colors.green),
                  ),
                  Expanded(
                    flex: (onlineFrac * 1000).round(),
                    child: Container(height: 6, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- CARD ----------------
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
        Colors.red,
        Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _showEditDialog(item);
          return false;
        }
        return await _confirmDelete(item);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isOnline
                ? Colors.blue.withOpacity(0.12)
                : Colors.green.withOpacity(0.12),
            child: Icon(
              isOnline ? Icons.account_balance_wallet : Icons.money,
              color: isOnline ? Colors.blue : Colors.green,
            ),
          ),
          title: Text(
            isOnline && (item['bank'] ?? '').toString().isNotEmpty
                ? item['bank']
                : '${item['mode']} Budget',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text("Date: ${item['date']}"),
          trailing: Text(
            "₹${amount.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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

  // -------------PIE CHART FOR BUDGET TRACKER-------------
  Widget _buildBudgetPieChart() {
    final total = _cashTotal + _onlineTotal;

    if (total <= 0) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          "No budget data for this month",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 40,
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

  //--------------------------PIE CHART LEGEND----------------
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

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final list = _filteredByMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Budget Tracker"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.help_outline),
          //   onPressed: () {
          //     ShowCaseWidget.of(context).startShowCase([
          //       _monthKey,
          //       _chartKey,
          //       _summaryKey,
          //       _filterKey,
          //       _listKey,
          //     ]);
          //   },
          // ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBudgets,
        child: Column(
          children: [
            Showcase(
              key: _monthKey,
              description: "Select month to view budgets for that month 📅",
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month),
                    const SizedBox(width: 8),

                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMonth,
                        decoration: const InputDecoration(
                          labelText: "Select Month",
                          border: OutlineInputBorder(),
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
                  ],
                ),
              ),
            ),
            Showcase(
              key: _chartKey,
              description: "This chart shows Cash vs Online budget split 📊",
              child: _buildBudgetPieChart(),
            ),
            _buildPieLegend(),
            Showcase(
              key: _summaryKey,
              description:
                  "This shows total budget, cash total & online total ✅",
              child: _buildSummary(),
            ),
            Showcase(
              key: _filterKey,
              description: "Filter budget entries by mode: All / Cash / Online",
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: ['All', 'Cash', 'Online']
                      .map(
                        (m) => ChoiceChip(
                          label: Text(m),
                          selected: _filterMode == m,
                          onSelected: (_) => setState(() => _filterMode = m),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Showcase(
                key: _listKey,
                description: "Swipe cards to Edit or Delete budget entries 🧾",
                child: list.isEmpty
                    ? const Center(child: Text("No budget entries found"))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) => _buildBudgetCard(list[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
