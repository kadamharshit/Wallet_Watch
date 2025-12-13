import 'package:flutter/material.dart';

class AboutUs extends StatelessWidget {
  const AboutUs({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text("About WalletWatch"),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(color: Colors.grey.shade50),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------- App Intro --------
            Center(
              child: Column(
                children: const [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "WalletWatch",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Track • Budget • Control",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // -------- Description Card --------
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "WalletWatch helps you manage your expenses and maintain a clear record of your spending. "
                  "It is designed to keep your finances simple, transparent, and under control.",
                  style: TextStyle(fontSize: 16, height: 1.6),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -------- Features --------
            const Text(
              "Key Features",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _featureTile(
              icon: Icons.edit_note,
              title: "Manual Expense Entry",
              subtitle: "Add and categorize expenses easily.",
            ),
            _featureTile(
              icon: Icons.receipt_long,
              title: "Receipt Scan",
              subtitle: "Scan receipts to auto-fill data.",
              trailing: _comingSoonChip(),
            ),
            _featureTile(
              icon: Icons.pie_chart,
              title: "Budget Tracking",
              subtitle: "Monitor monthly cash and online budgets.",
            ),
            _featureTile(
              icon: Icons.bar_chart,
              title: "Insights & History",
              subtitle: "Understand where your money goes.",
            ),

            const SizedBox(height: 24),

            // -------- Contact --------
            const Text(
              "Support",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: const Text("Contact Us"),
                subtitle: const Text("expensetracker@gmail.com"),
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                "Made with ❤️ to help you manage money better",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- Feature Tile Widget --------
  static Widget _featureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }

  static Widget _comingSoonChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "Coming Soon",
        style: TextStyle(
          fontSize: 11,
          color: Colors.orange,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
