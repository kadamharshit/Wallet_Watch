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

  bool _isMonthCompleted(String monthKey) {
    final selected = DateTime.parse("$monthKey-01");
    final now = DateTime.now();
    final nextMonth = DateTime(selected.year, selected.month + 1, 1);
    return now.isAfter(nextMonth) || now.isAtSameMomentAs(nextMonth);
  }

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

  Future<void> _exportPdf() async {
    if (!_isMonthCompleted(_selectedMonth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Monthly report can be exported only after month ends"),
        ),
      );
      return;
    }

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
    ).showSnackBar(SnackBar(content: Text("PDF saved: ${file.path}")));

    await Share.shareXFiles([XFile(file.path)], text: "WalletWatch Report PDF");
  }

  Future<void> _exportExcel() async {
    if (!_isMonthCompleted(_selectedMonth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Monthly report can be exported only after month ends"),
        ),
      );
      return;
    }

    final excel = Excel.createExcel();

    if (excel.sheets.keys.contains("Sheet1")) {
      excel.delete("Sheet1");
    }

    final sheet = excel['Report'];
    excel.setDefaultSheet("Report");

    CellValue t(String v) => TextCellValue(v);
    CellValue n(num v) => DoubleCellValue(v.toDouble());

    sheet.appendRow([t("WalletWatch Expense Report")]);
    sheet.appendRow([t("Month"), t(_monthLabel(_selectedMonth))]);
    sheet.appendRow([t("")]);

    sheet.appendRow([t("Summary")]);
    sheet.appendRow([t("Total Budget"), n(_totalBudget)]);
    sheet.appendRow([t("Total Expense"), n(_totalExpense)]);
    sheet.appendRow([t("Remaining"), n(_remaining)]);
    sheet.appendRow([t("")]);

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
    if (bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to generate Excel")));
      return;
    }

    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Excel saved: ${file.path}")));

    await Share.shareXFiles([
      XFile(file.path),
    ], text: "WalletWatch Report Excel");
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
              "Export Report",
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
            child: const Icon(Icons.download_for_offline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canExport = _isMonthCompleted(_selectedMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    )
                  : ListView(
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
                              await _loadMonthsAndData();
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _summaryRow(
                                title: "Total Budget",
                                value: "₹${_totalBudget.toStringAsFixed(2)}",
                                valueColor: Colors.blue,
                              ),
                              const SizedBox(height: 6),
                              _summaryRow(
                                title: "Total Expense",
                                value: "₹${_totalExpense.toStringAsFixed(2)}",
                                valueColor: Colors.redAccent,
                              ),
                              const SizedBox(height: 6),
                              _summaryRow(
                                title: "Remaining",
                                value: "₹${_remaining.toStringAsFixed(2)}",
                                valueColor: _remaining >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(height: 12),
                              if (!canExport)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Export will be enabled only after month ends.",
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: canExport ? _exportPdf : null,
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: Text(
                                    canExport
                                        ? "Export PDF"
                                        : "Export PDF (Locked)",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: canExport ? _exportExcel : null,
                                  icon: const Icon(Icons.table_chart),
                                  label: Text(
                                    canExport
                                        ? "Export Excel"
                                        : "Export Excel (Locked)",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    side: const BorderSide(
                                      color: Colors.blue,
                                      width: 1.3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
