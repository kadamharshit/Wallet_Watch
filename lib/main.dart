import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/dashboard/home_screen.dart';
import 'package:walletwatch/dashboard/splash_screen.dart';
import 'package:walletwatch/features/auth/create_account_screen.dart';
import 'package:walletwatch/features/auth/login_screen.dart';
import 'package:walletwatch/features/budget/add_budget.dart';
import 'package:walletwatch/features/expense/add_manual.dart';
import 'package:walletwatch/features/reports/export_report.dart';
import 'package:walletwatch/features/reports/reports_page.dart';
import 'package:walletwatch/features/settings/about_us.dart';
import 'package:walletwatch/features/settings/budget_tracker.dart';
import 'package:walletwatch/features/settings/edit_profile.dart';
import 'package:walletwatch/features/settings/expense_tracker.dart';
import 'package:walletwatch/features/settings/how_to_use.dart';
//import 'package:walletwatch/features/settings/shopping_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(ShowCaseWidget(builder: (context) => const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const CreateAccountScreen(),
        '/home': (_) => const HomeScreen(),
        '/expense_tracker': (_) => const ExpenseTracker(),
        '/profiles': (_) => const EditProfilePage(),
        '/about': (_) => const AboutUs(),
        '/budget_tracker': (_) => const BudgetTracker(),
        '/how_to_use': (_) => const HowToUse(),
        '/budget': (_) => const AddBudget(),
        '/reports': (_) => const ReportsPage(),
        '/add_expense': (_) => const AddManualExpense(),
        "/export_report": (context) => const ExportReportPage(),
        //"/shopping_list": (context) => const ShoppingListPage(),
      },
    );
  }
}
