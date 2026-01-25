import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:walletwatch/services/expense_database.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';

class ExportReportPage extends StatefulWidget {
  const ExportReportPage({super.key});

  @override
  State<ExportReportPage> createState() => _ExportReportPageState();
}

class _ExportReportPageState extends State<ExportReportPage> {
  bool _isLoading = true;

  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  List<String> _availableMonths = [];

  List<Map<String, dynamic>> _monthExpenses = [];
  List<Map<String, dynamic>> _monthBudgets = [];

  double _totalExpense = 0;
  double _totalBudget = 0;

  @override
  void initState() {
    super.initState();
    _loadMonthsAndData();
  }

  // ---------------- LOAD ----------------
  Future<void> _loadMonthsAndData() async {
    setState(() => _isLoading = true);

    final expenses = await DatabaseHelper.instance.getExpenses();
    final budgets = await DatabaseHelper.instance.getBudget();

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

    // Filter month wise
    final monthExpenses = expenses
        .where((e) => (e['date'] ?? '').toString().startsWith(_selectedMonth))
        .toList();

    final monthBudgets = budgets
        .where((b) => (b['date'] ?? '').toString().startsWith(_selectedMonth))
        .toList();

    double totalExp = 0;
    for (final e in monthExpenses) {
      totalExp += (e['total'] as num?)?.toDouble() ?? 0.0;
    }

    double totalBud = 0;
    for (final b in monthBudgets) {
      totalBud += (b['total'] as num?)?.toDouble() ?? 0.0;
    }

    setState(() {
      _availableMonths = monthList;
      _monthExpenses = monthExpenses;
      _monthBudgets = monthBudgets;
      _totalExpense = totalExp;
      _totalBudget = totalBud;
      _isLoading = false;
    });
  }

  String _monthLabel(String m) {
    try {
      return DateFormat('MMMM yyyy').format(DateTime.parse("$m-01"));
    } catch (_) {
      return m;
    }
  }

  double get _remaining => _totalBudget - _totalExpense;

  // ---------------- PDF EXPORT ----------------
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            "WalletWatch - Expense Report",
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text("Month: ${_monthLabel(_selectedMonth)}"),
          pw.SizedBox(height: 12),

          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Summary",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  "Total Budget: ₹${_totalBudget.toStringAsFixed(2)}",
                  style: pw.TextStyle(font: ttf),
                ),
                pw.Text(
                  "Total Expense: ₹${_totalExpense.toStringAsFixed(2)}",
                  style: pw.TextStyle(font: ttf),
                ),
                pw.Text(
                  "Remaining: ₹${_remaining.toStringAsFixed(2)}",
                  style: pw.TextStyle(font: ttf),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),
          pw.Text(
            "Transactions",
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),

          pw.Table.fromTextArray(
            headers: ["Date", "Shop", "Category", "Mode", "Total"],
            data: _monthExpenses.map((e) {
              return [
                (e['date'] ?? '').toString(),
                (e['shop'] ?? '').toString(),
                (e['category'] ?? '').toString(),
                (e['mode'] ?? '').toString(),
                "₹${(e['total'] ?? 0).toString()}",
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: ttf,
            ),
            cellStyle: pw.TextStyle(font: ttf),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/WalletWatch_Report_${_selectedMonth}.pdf");

    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("PDF saved ✅ ${file.path}")));

    await Share.shareXFiles([XFile(file.path)], text: "WalletWatch Report PDF");
  }

  // ---------------- EXCEL EXPORT ----------------
  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    CellValue? t(String v) => TextCellValue(v);
    CellValue? n(num v) => DoubleCellValue(v.toDouble());

    // Header
    sheet.appendRow([t("WalletWatch Expense Report")]);
    sheet.appendRow([t("Month"), t(_monthLabel(_selectedMonth))]);
    sheet.appendRow([t("")]);

    // Summary
    sheet.appendRow([t("Summary")]);
    sheet.appendRow([t("Total Budget"), n(_totalBudget)]);
    sheet.appendRow([t("Total Expense"), n(_totalExpense)]);
    sheet.appendRow([t("Remaining"), n(_remaining)]);
    sheet.appendRow([t("")]);

    // Transactions
    sheet.appendRow([t("Transactions")]);
    sheet.appendRow([
      t("Date"),
      t("Shop"),
      t("Category"),
      t("Mode"),
      t("Total"),
    ]);

    for (final e in _monthExpenses) {
      sheet.appendRow([
        t((e['date'] ?? '').toString()),
        t((e['shop'] ?? '').toString()),
        t((e['category'] ?? '').toString()),
        t((e['mode'] ?? '').toString()),
        n((e['total'] as num?)?.toDouble() ?? 0.0),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/WalletWatch_Report_${_selectedMonth}.xlsx");

    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Excel saved ✅ ${file.path}")));

    await Share.shareXFiles([
      XFile(file.path),
    ], text: "WalletWatch Report Excel");
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Export Report"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
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
                            child: Text(_monthLabel(m)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) async {
                      if (val == null) return;
                      setState(() => _selectedMonth = val);
                      await _loadMonthsAndData();
                    },
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: ListTile(
                      title: Text(
                        "Total Budget: ₹${_totalBudget.toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Total Expense: ₹${_totalExpense.toStringAsFixed(2)}\nRemaining: ₹${_remaining.toStringAsFixed(2)}",
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Export PDF"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // SizedBox(
                  //   width: double.infinity,
                  //   height: 50,
                  //   // child: OutlinedButton.icon(
                  //   //   onPressed: _exportExcel,
                  //   //   icon: const Icon(Icons.table_chart),
                  //   //   label: const Text("Export Excel"),
                  //   // ),
                  // ),
                ],
              ),
            ),
    );
  }
}
