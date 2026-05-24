import 'package:flutter/material.dart';

class HowToUse extends StatefulWidget {
  const HowToUse({super.key});

  @override
  State<HowToUse> createState() => _HowToUseState();
}

class _HowToUseState extends State<HowToUse> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  //------------------------------------UI----------------------------------------------------------------
  Widget _header(BuildContext context) {
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
            icon: Icon(Icons.arrow_back, color: colorScheme.surface),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "How to Use",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.surface,
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
            child: Icon(Icons.help_outline, color: colorScheme.surface),
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _stepCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
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
                  color: colorScheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colorScheme.primary),
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
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorScheme.background,
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
                      context,
                      child: Column(
                        children: [
                          Container(
                            height: 72,
                            width: 72,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 38,
                              color: colorScheme.primary,
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
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    _sectionContainer(
                      context,
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
                    const SizedBox(height: 6),
                    Text(
                      "Simple. Secure. Smart.",
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
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
