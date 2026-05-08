import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';

class TransferTracker extends StatefulWidget {
  const TransferTracker({super.key});

  @override
  State<TransferTracker> createState() => _TransferTrackerState();
}

class _TransferTrackerState extends State<TransferTracker> {
  List<Map<String, dynamic>> _transfers = [];
  List<String> _availableMonths = [];

  String _selectedMonth =
      "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

  String _filterMode = 'ALL';

  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  @override
  void initState() {
    super.initState();
    _loadTransfersForMonth(_selectedMonth);
  }

  // Future<void> _loadTransfers() async {
  //   final user = supabase.auth.currentUser;

  //   if (user == null) return;

  //   final transfers = await DatabaseHelper.instance.getTransfers(user.id);

  //   if (!mounted) return;

  //   setState(() {
  //     _transfers = transfers;
  //     _isLoading = false;
  //   });
  // }

  Future<void> _loadTransfersForMonth(String month) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final allTransfers = await DatabaseHelper.instance.getTransfers(user.id);
    final months =
        allTransfers
            .map((t) => (t['date'] ?? '').toString().substring(0, 7))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (!months.contains(month)) {
      month = months.isNotEmpty ? months.first : month;
    }

    final filtered = allTransfers
        .where((t) => (t['date'] ?? '').toString().startsWith(month))
        .toList();

    setState(() {
      _availableMonths = months;
      _isLoading = false;
      _selectedMonth = month;
      _transfers = filtered;
    });
  }

  List<Map<String, dynamic>> get _filteredTransfers {
    if (_filterMode == 'ALL') return _transfers;

    return _transfers.where((t) {
      final from = (t['from_type'] ?? '').toString().toLowerCase();
      final to = (t['to_type'] ?? '').toString().toLowerCase();
      if (_filterMode == 'Cash → Online') {
        return from == 'cash' && to == 'online';
      }
      if (_filterMode == 'Online → Cash') {
        return from == 'online' && to == 'cash';
      }
      if (_filterMode == 'Bank → Bank') {
        return from == 'bank' && to == 'bank';
      }

      return true;
    }).toList();
  }

  Future<void> _refreshTransfers() async {
    await _loadTransfersForMonth(_selectedMonth);
  }

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
              "Transfer Tracker",
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
              color: colorScheme.surface.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.wallet_outlined,
              color: Theme.of(context).colorScheme.surface,
            ),
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
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        //border: Border.all(color: colorScheme.outlineVariant),
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
      fillColor: colorScheme.surfaceVariant.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> t) {
    final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;

    final fromType = (t['from_type'] ?? '').toString();
    final toType = (t['to_type'] ?? '').toString();

    final fromBank = t['from_bank'] ?? '';
    final toBank = t['to_bank'] ?? '';

    final date = DateTime.tryParse(t['date'] ?? '');

    String title;

    if (fromType == 'bank' && toType == 'bank') {
      title = "$fromBank → $toBank";
    } else {
      title = "${fromType.toUpperCase()} → ${toType.toUpperCase()}";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        //border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primary.withOpacity(0.12),
            child: Icon(Icons.sync_alt, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  date == null
                      ? ''
                      : DateFormat('dd MMM yyyy • hh:mm a').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "₹${amount.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
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
              child: RefreshIndicator(
                onRefresh: _refreshTransfers,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _transfers.isEmpty
                    ? Center(
                        child: Text(
                          "No transfers found",
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 6, bottom: 18),
                        children: [
                          _sectionContainer(
                            child: DropdownButtonFormField<String>(
                              value: _availableMonths.contains(_selectedMonth)
                                  ? _selectedMonth
                                  : (_availableMonths.isNotEmpty
                                        ? _availableMonths.first
                                        : null),
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
                                  _loadTransfersForMonth(value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          _sectionContainer(
                            child: DropdownButtonFormField<String>(
                              value: _filterMode,
                              decoration: _pillDecoration(
                                hint: "Filter",
                                icon: Icons.filter_alt,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: 'Cash → Online',
                                  child: Text('Cash → Online'),
                                ),
                                DropdownMenuItem(
                                  value: 'Online → Cash',
                                  child: Text('Online → Cash'),
                                ),
                                DropdownMenuItem(
                                  value: 'Bank → Bank',
                                  child: Text('Bank → Bank'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _filterMode = value;
                                  });
                                }
                              },
                            ),
                          ),

                          const SizedBox(height: 20),
                          _sectionContainer(
                            child: Column(
                              children: _filteredTransfers
                                  .map((t) => _buildTransferCard(t))
                                  .toList(),
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
