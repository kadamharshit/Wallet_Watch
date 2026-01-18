import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _isLoading = true;
  bool _isOnline = false;

  String _filterMode = 'All'; // All / Cash / Online

  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  List<String> _availableMonths = [];

  // ✅ Showcase Keys
  final GlobalKey _monthKey = GlobalKey();
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();

  // ✅ Tour storage
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

  // ---------------- INTERNET ----------------
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

  //-----------------------Available Months Logid--------------------
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

  // ---------------- LOAD EXPENSES ----------------
  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    _isOnline = await _checkConnection();
    final user = supabase.auth.currentUser;

    // 1️⃣ Sync local → Supabase
    if (_isOnline && user != null) {
      await _syncLocalToSupabase();
    }

    // 2️⃣ Fetch from Supabase & cache locally
    if (_isOnline && user != null) {
      try {
        final response = await supabase
            .from('expenses')
            .select()
            .eq('user_id', user.id)
            .order('date', ascending: false);

        final serverExpenses = List<Map<String, dynamic>>.from(response);

        for (final exp in serverExpenses) {
          await DatabaseHelper.instance.upsertExpenseByUuid({
            'uuid': exp['uuid'],
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

        _expenses = await DatabaseHelper.instance.getExpenses();
      } catch (e) {
        debugPrint("Supabase fetch error: $e");
        _expenses = await DatabaseHelper.instance.getExpenses();
      }
    } else {
      // Offline
      _expenses = await DatabaseHelper.instance.getExpenses();
    }
    _buildAvailableMonths(_expenses);
    setState(() => _isLoading = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startExpenseTrackerTourOnlyOnce();
    });
  }

  //-----------------------INFO CARD WIDGET---------------------
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

  //-------------------SHOW EXPENSE DETAILS-------------------
  void _showExpenseDetails(Map<String, dynamic> expense) {
    final itemsRaw = (expense['items'] ?? '').toString();
    final items = itemsRaw.isNotEmpty ? itemsRaw.split('\n') : [];

    final isTravel = expense['category'] == 'Travel';

    final headers = isTravel
        ? ['Mode', 'From', 'To', 'Amount']
        : ['Item', 'Qty', 'Amount'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                child: items.isEmpty
                    ? const Center(child: Text('No item details'))
                    : Column(
                        children: [
                          _tableHeader(headers),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final parts = items[i]
                                    .split('|')
                                    .map((e) => e.trim())
                                    .toList();
                                if (isTravel && parts.length == 4) {
                                  // Detect amount position
                                  final amountIndex = parts.indexWhere(
                                    (p) => double.tryParse(p) != null,
                                  );

                                  if (amountIndex != 3 && amountIndex != -1) {
                                    final amount = parts.removeAt(amountIndex);
                                    parts.add(amount); // move amount to last
                                  }
                                }
                                if (!isTravel && parts.length == 3) {
                                  // Item | Qty | Amount
                                  final amountIndex = parts.indexWhere(
                                    (p) => double.tryParse(p) != null,
                                  );

                                  if (amountIndex != -1 && amountIndex != 2) {
                                    final amount = parts.removeAt(amountIndex);
                                    parts.add(amount);
                                  }
                                }
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      children: isTravel
                                          ? [
                                              Expanded(
                                                child: Text(
                                                  parts.length > 0
                                                      ? parts[0]
                                                      : '-',
                                                ),
                                              ), // Mode
                                              Expanded(
                                                child: Text(
                                                  parts.length > 1
                                                      ? parts[1]
                                                      : '-',
                                                ),
                                              ), // From
                                              Expanded(
                                                child: Text(
                                                  parts.length > 2
                                                      ? parts[2]
                                                      : '-',
                                                ),
                                              ), // To
                                              Expanded(
                                                child: Text(
                                                  parts.length > 3
                                                      ? '₹${double.tryParse(parts[3])?.toStringAsFixed(2) ?? parts[3]}'
                                                      : '-',
                                                  textAlign: TextAlign.right,
                                                ),
                                              ), // Amount
                                            ]
                                          : [
                                              Expanded(
                                                child: Text(
                                                  parts.length > 0
                                                      ? parts[0]
                                                      : '-',
                                                ),
                                              ), // Item
                                              Expanded(
                                                child: Text(
                                                  parts.length > 1
                                                      ? parts[1]
                                                      : '-',
                                                ),
                                              ), // Qty
                                              Expanded(
                                                child: Text(
                                                  parts.length > 2
                                                      ? '₹${parts[2]}'
                                                      : '-',
                                                  textAlign: TextAlign.right,
                                                ),
                                              ), // Amount
                                            ],
                                    ),
                                  ),
                                );
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

  // ---------------- SYNC ----------------
  Future<void> _syncLocalToSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses();

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

  // ---------------- HELPERS ----------------
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

  //-----------PIE CHART FOR EXPENSE TRACKER------------------
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
      height: 200,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 40,
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

  // ---------------- DELETE ----------------
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

  // ---------------- UI ----------------
  Widget _buildExpenseCard(Map<String, dynamic> exp) {
    final amount = (exp['total'] as num).toDouble();
    final isOnline = (exp['mode'] ?? '').toString().toLowerCase() == 'online';

    return ListTile(
      onTap: () => _showExpenseDetails(exp),
      leading: CircleAvatar(
        backgroundColor: isOnline
            ? Colors.blue.withOpacity(.1)
            : Colors.green.withOpacity(.1),
        child: Icon(
          isOnline ? Icons.account_balance_wallet : Icons.money,
          color: isOnline ? Colors.blue : Colors.green,
        ),
      ),
      title: Text(exp['shop'] ?? 'Unknown'),
      subtitle: Text("${_formatDate(exp['date'])} • ${exp['category']}"),
      trailing: Text(
        "₹${amount.toStringAsFixed(2)}",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  //-------------table to show the expense------------------
  Widget _tableHeader(List<String> headers) {
    return Card(
      color: Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(10),
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
      ),
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  //------------PIE CHART LEGEND LOGIC------------
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              ShowCaseWidget.of(context).startShowCase([
                _monthKey,
                _chartKey,
                _summaryKey,
                _filterKey,
                _listKey,
              ]);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshExpenses,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 300),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : Column(
                children: [
                  if (_availableMonths.isNotEmpty)
                    Showcase(
                      key: _monthKey,
                      description:
                          "Select month to see expenses for that month 📅",
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: DropdownButtonFormField<String>(
                          value: _availableMonths.contains(_selectedMonth)
                              ? _selectedMonth
                              : null,
                          decoration: const InputDecoration(
                            labelText: "Select Month",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month),
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
                    description: "Shows Cash vs Online expense split 📊",
                    child: _buildExpensePieChart(),
                  ),
                  _buildPieLegend(),
                  Showcase(
                    key: _summaryKey,
                    description:
                        "This shows total, cash and online spending for the month ✅",
                    child: Card(
                      margin: const EdgeInsets.all(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total: ₹${_grandTotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text("Cash: ₹${_totalCash.toStringAsFixed(2)}"),
                                const Spacer(),
                                Text(
                                  "Online: ₹${_totalOnline.toStringAsFixed(2)}",
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Showcase(
                              key: _filterKey,
                              description:
                                  "Filter expenses by payment mode: All / Cash / Online",
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('All'),
                                    selected: _filterMode == 'All',
                                    onSelected: (_) =>
                                        setState(() => _filterMode = 'All'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Cash'),
                                    selected: _filterMode == 'Cash',
                                    onSelected: (_) =>
                                        setState(() => _filterMode = 'Cash'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Online'),
                                    selected: _filterMode == 'Online',
                                    onSelected: (_) =>
                                        setState(() => _filterMode = 'Online'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Showcase(
                      key: _listKey,
                      description:
                          "Tap any expense to see details. Swipe to Edit/Delete 🧾",
                      child: ListView(
                        children: _groupedByDate.entries.map((entry) {
                          final dateTotal = entry.value.fold<double>(
                            0,
                            (sum, e) => sum + (e['total'] as num).toDouble(),
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  "${_formatDate(entry.key)} • ₹${dateTotal.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...entry.value.map((e) {
                                return Dismissible(
                                  key: ValueKey(e['uuid']),
                                  direction: DismissDirection.horizontal,

                                  // 👉 EDIT (Swipe right)
                                  background: Container(
                                    color: Colors.blue,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 16),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.white),
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

                                  // 👉 DELETE (Swipe left)
                                  secondaryBackground: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.delete, color: Colors.white),
                                      ],
                                    ),
                                  ),

                                  confirmDismiss: (direction) async {
                                    if (direction ==
                                        DismissDirection.startToEnd) {
                                      // 🟦 EDIT
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
                  ),
                ],
              ),
      ),
    );
  }
}
