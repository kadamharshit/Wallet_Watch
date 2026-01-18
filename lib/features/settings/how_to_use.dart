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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------- Header --------
            Center(
              child: Column(
                children: const [
                  Icon(Icons.help_outline, size: 56, color: Colors.blue),
                  SizedBox(height: 10),
                  Text(
                    "How to Use WalletWatch",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "A quick guide to manage your expenses",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // -------- Steps --------
            _stepCard(
              icon: Icons.add_circle_outline,
              title: "Add an Expense",
              content:
                  "You can track your spending in two ways:\n\n"
                  "• Add Manually: Enter date, shop name, category, items, and payment mode.\n"
                  "• Receipt Scan: Capture or upload a bill to auto-extract details (Coming soon).",
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
                  "Whenever you add an expense, the app automatically deducts the amount "
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
                  "Your login details are securely stored. "
                  "Once logged in, you remain signed in until you choose to sign out.",
            ),

            _stepCard(
              icon: Icons.logout,
              title: "Sign Out",
              content:
                  "Use the Sign Out option from the drawer. "
                  "You will be asked to confirm before logging out.",
            ),

            const SizedBox(height: 24),

            // -------- Support --------
            const Text(
              "Need Help?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const ListTile(
                leading: Icon(Icons.email, color: Colors.blue),
                title: Text("Contact Support"),
                subtitle: Text("harshit.expensetracker@gmail.com"),
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                "Simple. Secure. Smart.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- Reusable Step Card --------
  static Widget _stepCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(fontSize: 15, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
