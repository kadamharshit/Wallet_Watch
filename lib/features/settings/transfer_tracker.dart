import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/features/budget/transfer_screen.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:walletwatch/widgets/tracker_widgets.dart';

class TransferTracker extends StatefulWidget {
  final double cashBalance;
  final double onlineBalance;
  const TransferTracker({
    super.key,
    required this.cashBalance,
    required this.onlineBalance,
  });

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
      if (_filterMode == 'Online → Online') {
        return from == 'online' &&
            to == 'online' &&
            (t['from_bank'] ?? '').toString().isNotEmpty &&
            (t['to_bank'] ?? '').toString().isNotEmpty;
      }

      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _groupedTransfers {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final t in _filteredTransfers) {
      final date = (t['date'] ?? '').toString().split(' ').first;
      map.putIfAbsent(date, () => []).add(t);
    }

    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));

    return {for (final k in keys) k: map[k]!};
  }

  String _formatDate(String date) {
    final parsed = DateTime.tryParse(date);

    if (parsed == null) return date;

    final diff = DateTime.now().difference(parsed).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    return DateFormat('dd MMM yyyy').format(parsed);
  }

  Future<void> _refreshTransfers() async {
    await _loadTransfersForMonth(_selectedMonth);
  }

  double get _cashToOnlineTotal {
    return _filteredTransfers
        .where(
          (t) =>
              (t['from_type'] ?? '').toString().toLowerCase() == 'cash' &&
              (t['to_type'] ?? '').toString().toLowerCase() == 'online',
        )
        .fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
  }

  double get _onlineToCashTotal {
    return _filteredTransfers
        .where(
          (t) =>
              (t['from_type'] ?? '').toString().toLowerCase() == 'online' &&
              (t['to_type'] ?? '').toString().toLowerCase() == 'cash',
        )
        .fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
  }

  double get _onlineToOnlineTotal {
    return _filteredTransfers
        .where(
          (t) =>
              (t['from_type'] ?? '').toString().toLowerCase() == 'online' &&
              (t['to_type'] ?? '').toString().toLowerCase() == 'online',
        )
        .fold(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
  }

  double get _grandTransferTotal {
    return _cashToOnlineTotal + _onlineToCashTotal + _onlineToOnlineTotal;
  }

  Future<void> _deleteTransfer(Map<String, dynamic> trf) async {
    final localId = trf['id'];
    final supabaseId = trf['supabase_id'];
    final uuid = trf['uuid'];

    await DatabaseHelper.instance.deleteTransfer(localId);

    final user = supabase.auth.currentUser;
    if (user != null) {
      if (supabaseId != null) {
        await supabase.from('transfers').delete().eq('id', supabaseId);
      } else if (uuid != null) {
        await supabase.from('transfers').delete().eq('uuid', uuid);
      }
    }

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

  Future<bool> _confirmDeleteDialog() async {
    final result = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Transfer?"),
        content: const Text(
          "Are you sure you want to delete this transfer? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.surface,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildSummarySection() {
    return buildSectionContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Transfer Summary",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          const SizedBox(height: 10),

          Text(
            "₹${_grandTransferTotal.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Cash → Online",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹${_cashToOnlineTotal.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
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
                    color: colorScheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Online → Cash",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹${_onlineToCashTotal.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Online → Online",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${_onlineToOnlineTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
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

    if (fromBank.isNotEmpty && toBank.isNotEmpty) {
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
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 6, bottom: 18),
                        children: [
                          buildSectionContainer(
                            context: context,
                            child: DropdownButtonFormField<String>(
                              value: _availableMonths.contains(_selectedMonth)
                                  ? _selectedMonth
                                  : (_availableMonths.isNotEmpty
                                        ? _availableMonths.first
                                        : null),
                              decoration: buildPillDecoration(
                                context: context,
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

                          _buildSummarySection(),

                          buildSectionContainer(
                            context: context,
                            child: DropdownButtonFormField<String>(
                              value: _filterMode,
                              decoration: buildPillDecoration(
                                context: context,
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
                                  value: 'Online → Online',
                                  child: Text('Online → Online'),
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
                          if (_filteredTransfers.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.sync_alt,
                                      size: 54,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "No transfers found",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Try changing filter or month",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._groupedTransfers.entries.map((entry) {
                              final dateTotal = entry.value.fold<double>(
                                0,
                                (sum, t) =>
                                    sum +
                                    ((t['amount'] as num?)?.toDouble() ?? 0),
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

                                  ...entry.value.map((t) {
                                    return Dismissible(
                                      key: ValueKey(t['uuid']),
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
                                        child: Row(
                                          children: const [
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
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 18,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: const [
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
                                          final user =
                                              supabase.auth.currentUser;

                                          if (user == null) return false;

                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TransferScreen(
                                                cashBalance: widget.cashBalance,
                                                onlineBalance:
                                                    widget.onlineBalance,
                                                existingTransfer: t,
                                              ),
                                            ),
                                          );

                                          await _loadTransfersForMonth(
                                            _selectedMonth,
                                          );

                                          return false;
                                        }
                                        final confirm =
                                            await _confirmDeleteDialog();

                                        if (confirm) {
                                          await _deleteTransfer(t);
                                        }

                                        return confirm;
                                      },

                                      child: _buildTransferCard(t),
                                    );
                                  }),
                                ],
                              );
                            }),
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
