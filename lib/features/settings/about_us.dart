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
        title: const Text("About Us"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Center(
              child: Text(
                "Welcome to WalletWatch",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              "WalletWatch helps you manage your expenses and keep a clear record of your spending. "
              "You can enter expenses in two ways:\n\n"
              "1. By scanning a receipt (Currently not available)\n"
              "2. Manually entering details\n\n"
              "The app allows you to stay on top of your monthly budget and track where your money goes.\n\n"
              "If you have any queries or need support, feel free to contact us:\n"
              "📧 expensetracker@gmail.com",
              style: TextStyle(
                fontSize: 16,
                height: 1.6, // improved line spacing for readability
              ),
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }
}
