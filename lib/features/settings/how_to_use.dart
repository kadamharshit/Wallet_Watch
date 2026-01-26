import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HowToUse extends StatelessWidget {
  const HowToUse({super.key});

  Future<void> _replayHomeTour(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: "walletwatch_home_tour_done");

    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  Future<void> _replayAddExpenseTour(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: "walletwatch_add_expense_tour_done");

    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, "/add_expense");
    }
  }

  Future<void> _replayAddBudgetTour(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: "walletwatch_add_budget_tour_done");

    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushReplacementNamed(context, "/budget");
    }
  }

  Widget _header(BuildContext context) {
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
              "How to Use",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
            child: const Icon(Icons.help_outline, color: Colors.white),
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

  Widget _quickButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _stepCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 10, bottom: 18),
                child: Column(
                  children: [
                    _sectionContainer(
                      child: Column(
                        children: [
                          Container(
                            height: 72,
                            width: 72,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 38,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "How to Use WalletWatch",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "A quick guide to manage your expenses and budget",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    _sectionContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Guide",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _stepCard(
                            icon: Icons.add_circle_outline,
                            title: "Add an Expense",
                            content:
                                "Track your spending easily:\n\n"
                                "• Add Manually: Enter date, shop name, category, items, and payment mode.\n"
                                "• Receipt Scan: Capture or upload a bill to auto-fill data (Coming soon).",
                          ),
                          _stepCard(
                            icon: Icons.account_balance_wallet_outlined,
                            title: "Manage Your Budget",
                            content:
                                "Go to Manage Budget from the drawer:\n\n"
                                "• Cash: Enter available cash amount.\n"
                                "• Online: Add balances from bank or UPI accounts.",
                          ),
                          _stepCard(
                            icon: Icons.sync_alt,
                            title: "Auto Budget Deduction",
                            content:
                                "Whenever you add an expense, WalletWatch automatically deducts the amount "
                                "from Cash or Online budget based on the payment mode.",
                          ),
                          _stepCard(
                            icon: Icons.dashboard_outlined,
                            title: "View Dashboard",
                            content:
                                "The dashboard shows:\n\n"
                                "• Total expenses for the current month\n"
                                "• Total available budget (Cash + Online)",
                          ),
                          _stepCard(
                            icon: Icons.person_outline,
                            title: "My Profile",
                            content:
                                "View and edit your personal details like name, mobile number, "
                                "and date of birth from the My Profile page.",
                          ),
                          _stepCard(
                            icon: Icons.lock_outline,
                            title: "Login & Security",
                            content:
                                "Your login details are securely stored.\n"
                                "Once logged in, you remain signed in until you choose to sign out.",
                          ),
                          _stepCard(
                            icon: Icons.logout,
                            title: "Sign Out",
                            content:
                                "Use the Sign Out option from the drawer.\n"
                                "You will be asked to confirm before logging out.",
                          ),
                        ],
                      ),
                    ),

                    _sectionContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Support",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F6F6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.email, color: Colors.blue),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Contact Support",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text("harshit.expensetracker@gmail.com"),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),
                    Text(
                      "Simple. Secure. Smart.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
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
