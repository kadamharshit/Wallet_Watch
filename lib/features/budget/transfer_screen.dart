import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:walletwatch/services/sync_service.dart';

enum TransferType { cashToOnline, onlineToCash }

class TransferScreen extends StatefulWidget {
  final double cashBalance;
  final double onlineBalance;
  final Map<String, dynamic>? existingTransfer;
  const TransferScreen({
    super.key,
    required this.cashBalance,
    required this.onlineBalance,
    this.existingTransfer,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  String? fromType;
  String? toType;
  String? fromBank;
  String? toBank;
  final TextEditingController amountController = TextEditingController();

  double currentCashBalance = 0;
  double currentOnlineBalance = 0;

  final List<String> options = ['Cash', 'Online'];

  TransferType? selectedTransferType;

  List<String> banks = [];
  bool get hasMultipleBanks => banks.length > 1;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    currentCashBalance = widget.cashBalance;
    currentOnlineBalance = widget.onlineBalance;

    _loadBanks();

    amountController.addListener(_onAmountChanged);

    final t = widget.existingTransfer;

    if (t != null) {
      selectedTransferType = _detectTransferType(t);

      amountController.text = (t['amount'] ?? '').toString();

      fromType = t['from_type'];
      toType = t['to_type'];

      fromBank = t['from_bank'];
      toBank = t['to_bank'];
    }
  }

  TransferType? _detectTransferType(Map<String, dynamic> t) {
    final from = (t['from_type'] ?? '').toString().toLowerCase();
    final to = (t['to_type'] ?? '').toString().toLowerCase();

    final fromBank = (t['from_bank'] ?? '').toString();
    final toBank = (t['to_bank'] ?? '').toString();

    if (from == 'cash' && to == 'online') {
      return TransferType.cashToOnline;
    }

    if (from == 'online' && to == 'cash') {
      return TransferType.onlineToCash;
    }

    // if (fromBank.isNotEmpty && toBank.isNotEmpty) {
    //   return TransferType.bankToBank;
    // }

    return null;
  }

  Future<void> _loadBanks() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final userBanks = await DatabaseHelper.instance.getUserBanks(user.id);

    setState(() {
      banks = userBanks;
    });
  }

  void _onAmountChanged() {
    setState(() {});
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleTransfer() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final amount = double.tryParse(amountController.text) ?? 0;
      double available = 0;

      if (fromType!.toLowerCase() == 'cash') {
        available = currentCashBalance;
      } else {
        available = currentOnlineBalance;
      }

      if (amount > available) {
        _showError("Insufficient Balance");
        return;
      }

      // VALIDATIONS
      if (fromType == null || toType == null) {
        _showError("Select both From and To");
        return;
      }

      if (fromType == toType) {
        _showError("Cannot transfer to same account");
        return;
      }

      if (amount <= 0) {
        _showError("Enter valid amount");
        return;
      }

      setState(() {
        isLoading = true;
      });

      if (widget.existingTransfer != null) {
        final supabaseId = widget.existingTransfer!['supabase_id'];

        if (supabaseId != null) {
          await Supabase.instance.client
              .from('transfers')
              .update({
                'from_type': fromType,
                'to_type': toType,
                'from_bank': fromBank,
                'to_bank': toBank,
                'amount': amount,
              })
              .eq('id', supabaseId);
        }

        await DatabaseHelper.instance
            .updateTransfer(widget.existingTransfer!['id'], {
              'from_type': fromType,
              'to_type': toType,
              'from_bank': fromBank,
              'to_bank': toBank,
              'amount': amount,
              'date': widget.existingTransfer!['date'],
              'synced': 0,
            });
      } else {
        await DatabaseHelper.instance.insertTransfer({
          'uuid': const Uuid().v4(),
          'user_id': user.id,
          'from_type': fromType,
          'to_type': toType,
          'from_bank': fromBank,
          'to_bank': toBank,
          'amount': amount,
          'date': DateTime.now().toIso8601String(),
          'synced': 0,
        });
      }

      await SyncService.syncAll();
      await Future.delayed(const Duration(milliseconds: 300));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transfer saved successfully")),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Transfer Error: $e");
      if (mounted) {
        _showError("Transfer Failed");
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _transferCard({
    required String title,
    required VoidCallback onTap,
    required IconData icon,
    required bool isDisabled,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,

      child: Container(
        width: double.infinity,
        height: 84,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: isSelected
                ? colorScheme.surface.withOpacity(0.9)
                : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
          color: isDisabled
              ? colorScheme.surfaceContainerHighest.withOpacity(0.35)
              : isSelected
              ? colorScheme.primary
              : colorScheme.primary.withOpacity(0.75),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDisabled ? Colors.grey : colorScheme.surface,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: isDisabled ? Colors.grey : colorScheme.surface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transferAmountUI({required String label, required double balance}) {
    return Column(
      children: [
        Text(
          "$label: ₹${balance.toStringAsFixed(2)}",
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 10),

        TextFormField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.currency_rupee),
            hintText: "Enter Amount",
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: isLoading
              ? null
              : amountController.text.trim().isNotEmpty
              ? _handleTransfer
              : null,

          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.existingTransfer != null
                      ? "Update Transfer"
                      : "Transfer",
                ),
        ),
      ],
    );
  }
  // Widget _cashToOnlineUI() {
  //   return Column(
  //     children: [
  //       Text(
  //         "Available Cash: ₹${widget.cashBalance}",
  //         style: TextStyle(color: Colors.grey),
  //       ),
  //       const SizedBox(height: 10),
  //       TextFormField(
  //         controller: amountController,
  //         keyboardType: TextInputType.number,
  //         decoration: InputDecoration(
  //           prefixIcon: Icon(Icons.currency_rupee),
  //           hintText: "Enter Amount",
  //         ),
  //       ),
  //       const SizedBox(height: 20),
  //       ElevatedButton(
  //         onPressed: isLoading
  //             ? null
  //             : amountController.text.trim().isNotEmpty
  //             ? _handleTransfer
  //             : null,
  //         child: isLoading
  //             ? const SizedBox(
  //                 height: 20,
  //                 width: 20,
  //                 child: CircularProgressIndicator(strokeWidth: 2),
  //               )
  //             : const Text("Transfer"),
  //       ),
  //     ],
  //   );
  // }

  // Widget _onlineToCashUI() {
  //   return Column(
  //     children: [
  //       Text(
  //         "Available Online: ₹${widget.onlineBalance}",
  //         style: TextStyle(color: Colors.grey),
  //       ),
  //       const SizedBox(height: 10),
  //       TextFormField(
  //         controller: amountController,
  //         keyboardType: TextInputType.number,
  //         decoration: InputDecoration(
  //           prefixIcon: Icon(Icons.currency_rupee),
  //           hintText: "Enter Amount",
  //         ),
  //       ),
  //       const SizedBox(height: 20),
  //       ElevatedButton(
  //         onPressed: isLoading
  //             ? null
  //             : amountController.text.trim().isNotEmpty
  //             ? _handleTransfer
  //             : null,
  //         child: isLoading
  //             ? const SizedBox(
  //                 height: 20,
  //                 width: 20,
  //                 child: CircularProgressIndicator(strokeWidth: 2),
  //               )
  //             : const Text("Transfer"),
  //       ),
  //     ],
  //   );
  // }

  Widget _bankToBankUI() {
    final filteredBanks = banks.where((b) => b != fromBank).toList();
    return Column(
      children: [
        const Text("Select Banks"),

        const SizedBox(height: 10),

        DropdownButtonFormField(
          hint: Text("From Bank"),

          items: banks.map((b) {
            return DropdownMenuItem(value: b, child: Text(b));
          }).toList(),
          onChanged: (val) {
            setState(() {
              fromType = val;
            });
          },
        ),

        const SizedBox(height: 10),

        DropdownButtonFormField(
          hint: Text("To Bank"),
          items: filteredBanks.map((b) {
            return DropdownMenuItem(value: b, child: Text(b));
          }).toList(),
          onChanged: (val) {
            setState(() {
              toType = val;
            });
          },
        ),

        const SizedBox(height: 10),

        TextFormField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.currency_rupee),
            hintText: "Enter amount",
          ),
        ),

        const SizedBox(height: 14),

        ElevatedButton(
          onPressed: isLoading
              ? null
              : amountController.text.trim().isNotEmpty
              ? _handleTransfer
              : null,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Transfer"),
        ),
      ],
    );
  }

  Widget _buildDynamicSection() {
    if (widget.existingTransfer != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Transfer type cannot be changed during edit.",
              style: TextStyle(color: Colors.orange),
            ),
          ),

          switch (selectedTransferType) {
            TransferType.cashToOnline => _transferAmountUI(
              label: "Available Cash",
              balance: currentCashBalance,
            ),

            TransferType.onlineToCash => _transferAmountUI(
              label: "Available Online",
              balance: currentOnlineBalance,
            ),

            _ => const SizedBox(),
          },
        ],
      );
    }
    switch (selectedTransferType) {
      case TransferType.cashToOnline:
        return _transferAmountUI(
          label: "Available Cash",
          balance: currentCashBalance,
        );

      case TransferType.onlineToCash:
        return _transferAmountUI(
          label: "Available Online",
          balance: currentOnlineBalance,
        );

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.75),
                  ],
                  begin: AlignmentGeometry.topLeft,
                  end: AlignmentGeometry.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: colorScheme.surface),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Transfer",
                      style: TextStyle(
                        color: colorScheme.surface,
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
                    child: Icon(Icons.currency_exchange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _transferCard(
                      title: "Cash → Online",
                      onTap: () {
                        if (widget.existingTransfer != null) return;
                        setState(() {
                          selectedTransferType = TransferType.cashToOnline;

                          //amountController.clear();

                          fromType = 'cash';
                          toType = 'online';

                          fromBank = null;
                          toBank = null;
                        });
                      },
                      icon: Icons.currency_exchange,
                      isDisabled:
                          widget.existingTransfer != null &&
                          selectedTransferType != TransferType.cashToOnline,
                      isSelected:
                          selectedTransferType == TransferType.cashToOnline,
                    ),
                    const SizedBox(height: 10),
                    _transferCard(
                      title: "Online → Cash",
                      onTap: () {
                        if (widget.existingTransfer != null) return;
                        setState(() {
                          selectedTransferType = TransferType.onlineToCash;

                          //amountController.clear();

                          fromType = 'online';
                          toType = 'cash';

                          fromBank = null;
                          toBank = null;
                        });
                      },
                      icon: Icons.attach_money,
                      isDisabled:
                          widget.existingTransfer != null &&
                          selectedTransferType != TransferType.onlineToCash,
                      isSelected:
                          selectedTransferType == TransferType.onlineToCash,
                    ),
                    const SizedBox(height: 10),
                    // _transferCard(
                    //   title: "Bank → Bank",
                    //   onTap: () {
                    //     setState(() {
                    //       selectedTransferType = TransferType.bankToBank;

                    //       amountController.clear();

                    //       fromType = null;
                    //       toType = null;
                    //     });
                    //   },
                    //   icon: Icons.account_balance,
                    //   isDisabled: !hasMultipleBanks,
                    //   isSelected:
                    //       selectedTransferType == TransferType.bankToBank,
                    // ),
                    const SizedBox(height: 16),
                    _buildDynamicSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // body: Padding(
      //   padding: const EdgeInsets.all(16),
      //   child: Column(
      //     children: [
      //       DropdownButtonFormField(
      //         value: fromType,
      //         hint: const Text("From"),
      //         items: options.map((e) {
      //           return DropdownMenuItem(value: e, child: Text(e));
      //         }).toList(),
      //         onChanged: (val) => setState(() => fromType = val),
      //       ),
      //       const SizedBox(height: 16),

      //       DropdownButtonFormField(
      //         value: toType,
      //         hint: const Text("To"),
      //         items: options.map((e) {
      //           return DropdownMenuItem(value: e, child: Text(e));
      //         }).toList(),
      //         onChanged: (val) => setState(() => toType = val),
      //       ),

      //       const SizedBox(height: 16),
      //       if (fromType != null)
      //         Text(
      //           "Available: ₹ ${fromType == 'Cash' ? widget.cashBalance : widget.onlineBalance}",
      //           style: TextStyle(color: Colors.grey),
      //         ),

      //       TextField(
      //         controller: amountController,
      //         keyboardType: TextInputType.number,
      //         decoration: const InputDecoration(
      //           labelText: "Amount",
      //           border: OutlineInputBorder(),
      //         ),
      //       ),
      //
      //     ],
      //   ),
      // ),
    );
  }

  @override
  void dispose() {
    amountController.removeListener(_onAmountChanged);
    amountController.dispose();
    super.dispose();
  }
}
