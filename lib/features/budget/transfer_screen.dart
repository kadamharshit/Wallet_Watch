import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:walletwatch/services/sync_service.dart';

enum TransferType { cashToOnline, onlineToCash, bankToBank }

class TransferScreen extends StatefulWidget {
  final double cashBalance;
  final double onlineBalance;
  const TransferScreen({
    super.key,
    required this.cashBalance,
    required this.onlineBalance,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  String? fromType;
  String? toType;
  final TextEditingController amountController = TextEditingController();

  final List<String> options = ['Cash', 'Online'];

  TransferType? selectedTransferType;

  List<String> banks = [];
  bool get hasMultipleBanks => banks.length > 1;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    amountController.addListener(_onAmountChanged);
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

      final transferUuid = const Uuid().v4();
      final now = DateTime.now().toString();

      final amount = double.tryParse(amountController.text) ?? 0;
      double available = 0;
      if (fromType == null || toType == null) {
        _showError("Select transfer type");
        return;
      }
      if (selectedTransferType == TransferType.bankToBank) {
        _showError("Bank transfer balance tracking coming soon");
        return;
      }
      if (fromType!.toLowerCase() == 'cash') {
        available = widget.cashBalance;
      } else {
        available = widget.onlineBalance;
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

      await DatabaseHelper.instance.insertTransfer({
        'uuid': transferUuid,
        'user_id': user.id,
        'from_type': selectedTransferType == TransferType.cashToOnline
            ? 'cash'
            : selectedTransferType == TransferType.onlineToCash
            ? 'online'
            : 'bank',

        'to_type': selectedTransferType == TransferType.cashToOnline
            ? 'online'
            : selectedTransferType == TransferType.onlineToCash
            ? 'cash'
            : 'bank',

        'from_bank': selectedTransferType == TransferType.bankToBank
            ? fromType
            : null,

        'to_bank': selectedTransferType == TransferType.bankToBank
            ? toType
            : null,
        'amount': amount,
        'date': now,
        'synced': 0,
        'supabase_id': null,
      });

      await SyncService.syncAll();
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
        height: 100,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
          color: isDisabled
              ? Colors.grey.withOpacity(0.4)
              : isSelected
              ? colorScheme.primary
              : colorScheme.primary.withOpacity(0.75),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colorScheme.surface),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.surface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cashToOnlineUI() {
    return Column(
      children: [
        Text(
          "Available Cash: ₹${widget.cashBalance}",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
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
              : const Text("Transfer"),
        ),
      ],
    );
  }

  Widget _onlineToCashUI() {
    return Column(
      children: [
        Text(
          "Available Online: ₹${widget.onlineBalance}",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
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
              : const Text("Transfer"),
        ),
      ],
    );
  }

  Widget _bankToBankUI() {
    final filteredBanks = banks.where((b) => b != fromType).toList();
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
              : const Text("Transfer"),
        ),
      ],
    );
  }

  Widget _buildDynamicSection() {
    switch (selectedTransferType) {
      case TransferType.cashToOnline:
        return _cashToOnlineUI();

      case TransferType.onlineToCash:
        return _onlineToCashUI();

      case TransferType.bankToBank:
        return _bankToBankUI();
      default:
        return SizedBox();
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
                        setState(() {
                          selectedTransferType = TransferType.cashToOnline;

                          amountController.clear();

                          fromType = 'cash';
                          toType = 'online';
                        });
                      },
                      icon: Icons.currency_exchange,
                      isDisabled: false,
                      isSelected:
                          selectedTransferType == TransferType.cashToOnline,
                    ),
                    const SizedBox(height: 10),
                    _transferCard(
                      title: "Online → Cash",
                      onTap: () {
                        setState(() {
                          selectedTransferType = TransferType.onlineToCash;

                          amountController.clear();

                          fromType = 'online';
                          toType = 'cash';
                        });
                      },
                      icon: Icons.attach_money,
                      isDisabled: false,
                      isSelected:
                          selectedTransferType == TransferType.onlineToCash,
                    ),
                    const SizedBox(height: 10),
                    _transferCard(
                      title: "Bank → Bank",
                      onTap: () {
                        setState(() {
                          selectedTransferType = TransferType.bankToBank;

                          amountController.clear();

                          fromType = null;
                          toType = null;
                        });
                      },
                      icon: Icons.account_balance,
                      isDisabled: !hasMultipleBanks,
                      isSelected:
                          selectedTransferType == TransferType.bankToBank,
                    ),
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
