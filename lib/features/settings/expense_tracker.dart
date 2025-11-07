import 'package:flutter/material.dart';
import 'package:walletwatch/services/expense_database.dart';

class ExpenseTracker extends StatefulWidget {
  const ExpenseTracker({super.key});

  @override
  State<ExpenseTracker> createState() => _ExpenseTrackerState();
}

class _ExpenseTrackerState extends State<ExpenseTracker> {
  late Future<List<Map<String, dynamic>>> _expenseList;
  List<Map<String, dynamic>> _filteredExpenses = [];
  String _selectedMonth = '';
  List<String> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _initializeMonthList();
  }

  void _initializeMonthList() async {
    final allExpenses = await DatabaseHelper.instance.getExpenses();
    final monthSet = <String>{};

    for (var expense in allExpenses) {
      final date = expense['date'] ?? '';
      if (date.length >= 7) {
        monthSet.add(date.substring(0, 7));
      }
    }

    final sortedMonths = monthSet.toList()..sort((a, b) => b.compareTo(a));
    setState(() {
      _availableMonths = sortedMonths;
      _selectedMonth = sortedMonths.isNotEmpty
          ? sortedMonths.first
          : "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}";
    });

    _loadExpensesForMonth(_selectedMonth);
  }

  void _loadExpensesForMonth(String month) async {
    final allExpenses = await DatabaseHelper.instance.getExpenses();
    final filtered = allExpenses.where((expense) {
      final date = expense['date'] ?? '';
      return date.startsWith(month);
    }).toList();

    setState(() {
      _filteredExpenses = filtered;
      _expenseList = Future.value(filtered);
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatMonthLabel(String monthYear) {
    final parts = monthYear.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return "${_getMonthName(month)} $year";
  }

  String _formatAmount(double amount) {
    return "₹${amount.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text("Expense Tracker"),
      ),
      body: Column(
        children: [
          if (_availableMonths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: _selectedMonth,
                isExpanded: true,
                items: _availableMonths.map((month) {
                  return DropdownMenuItem<String>(
                    value: month,
                    child: Text(_formatMonthLabel(month)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMonth = value;
                    });
                    _loadExpensesForMonth(value);
                  }
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _expenseList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No expenses recorded yet."));
                }

                final expenses = snapshot.data!;
                double total = expenses.fold(
                  0,
                  (sum, item) =>
                      sum + ((item['total'] as num?)?.toDouble() ?? 0),
                );

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      color: Colors.teal,
                      child: Text(
                        "Total Expense - ${_formatMonthLabel(_selectedMonth)}: ${_formatAmount(total)}",
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final item = expenses[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.receipt),
                              title: Text(item['shop'] ?? 'Unknown'),
                              subtitle: Text(
                                "${item['date'] ?? ''} • ${item['category'] ?? ''} • ${item['mode'] ?? item['paymentMode'] ?? 'Cash'}",
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.orange,
                                    ),
                                    onPressed: () => _showEditDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _confirmDelete(item['id']),
                                  ),
                                ],
                              ),
                              onTap: () => _showDetailsDialog(item),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> item) {
    final String category = item['category'] ?? '';
    final String items = item['items'] ?? '';
    final String mode = item['mode'] ?? item['paymentMode'] ?? 'Cash';
    List<List<String>> rows = [];

    if (items.trim().isNotEmpty) {
      final lines = items.trim().split('\n');
      for (var line in lines) {
        final parts = line.split('|').map((e) => e.trim()).toList();
        rows.add(parts);
      }
    }

    List<TableRow> tableRows = [];

    if (category == 'Travel') {
      tableRows.add(
        const TableRow(
          children: [
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                "Amount",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                "Mode",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                "Start",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                "Destination",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      for (var row in rows) {
        if (row.length == 4) {
          tableRows.add(
            TableRow(
              children: row
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(e),
                    ),
                  )
                  .toList(),
            ),
          );
        }
      }
    } else {
      tableRows.add(
        const TableRow(
          children: [
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                "Amount",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                "Item",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text("Qty", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      for (var row in rows) {
        if (row.length >= 3) {
          tableRows.add(
            TableRow(
              children: row
                  .take(3)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(e),
                    ),
                  )
                  .toList(),
            ),
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['shop'] ?? 'Unknown'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Date: ${item['date'] ?? ''}"),
              Text("Category: ${category}"),
              Text("Paid By: $mode"),
              const SizedBox(height: 8),
              const Text(
                "Items:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Table(
                border: TableBorder.all(),
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                },
                children: tableRows,
              ),
              const SizedBox(height: 8),
              Text(
                "Total: ₹${(item['total'] as num?)?.toStringAsFixed(2) ?? '0.00'}",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    final TextEditingController shopController = TextEditingController(
      text: item['shop'],
    );
    final TextEditingController categoryController = TextEditingController(
      text: item['category'],
    );
    final TextEditingController totalController = TextEditingController(
      text: (item['total'] as num?)?.toString() ?? '0',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Expense"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: shopController,
              decoration: const InputDecoration(labelText: "Shop Name"),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: "Category"),
            ),
            TextField(
              controller: totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Amount"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final updated = {
                'shop': shopController.text,
                'category': categoryController.text,
                'total': double.tryParse(totalController.text) ?? 0.0,
                'items': item['items'],
                'date': item['date'],
                'mode': item['mode'] ?? item['paymentMode'] ?? 'Cash',
              };
              await DatabaseHelper.instance.updateExpense(item['id'], updated);
              Navigator.pop(context);
              _loadExpensesForMonth(_selectedMonth);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Entry"),
        content: const Text("Are you sure you want to delete this expense?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = DatabaseHelper.instance;
    final allExpenses = await db.getExpenses();
    final expense = allExpenses.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {},
    );

    if (expense.isEmpty) return;

    final String date = expense['date'] ?? '';
    final double amount = (expense['total'] as num?)?.toDouble() ?? 0;
    final String mode = expense['mode'] ?? expense['paymentMode'] ?? 'Cash';
    final String? bank = expense['bank'];

    // Delete the expense
    await db.deleteExpense(id);

    // Delete corresponding budget deduction if exists
    final allBudgets = await db.getBudget();
    final match = allBudgets.firstWhere(
      (b) =>
          b['date'] == date &&
          (b['amount'] as num?)?.toDouble() == -amount &&
          b['mode'] == mode,
      orElse: () => {},
    );

    if (match.isNotEmpty) {
      await db.deleteBudget(match['id']);
    }

    // Restore budget entry
    final restoreEntry = {'date': date, 'amount': amount, 'mode': mode};
    if (mode != 'Cash' && bank != null) restoreEntry['bank'] = bank;

    await db.insertBudget(restoreEntry);

    _loadExpensesForMonth(_selectedMonth);
  }
}
