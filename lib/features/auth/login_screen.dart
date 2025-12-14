import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  final supabase = Supabase.instance.client;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final authRes = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authRes.user != null) {
        if (!mounted) return;

        // ✅ STORE USER DATA LOCALLY (FOR OFFLINE DRAWER)
        const storage = FlutterSecureStorage();
        await storage.write(key: 'useremail', value: email);

        // Optional (safe fallback)
        await storage.write(key: 'username', value: email.split('@').first);

        // ✅ INITIAL SYNC (you already wrote this correctly)
        await _initialSupabaseToLocalSync(authRes.user!);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login successful')));

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = "Invalid email or password";
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint("Login error: $e");
      setState(() {
        _errorMessage = "Something went wrong. Try again.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initialSupabaseToLocalSync(User user) async {
    final isEmpty = await DatabaseHelper.instance.isLocalDatabaseEmpty();

    if (!isEmpty) {
      debugPrint("Local DB already has data. Skipping initial sync.");
      return;
    }

    debugPrint("Local DB empty. Syncing from Supabase...");

    final expenses = await supabase
        .from('expenses')
        .select()
        .eq('user_id', user.id);

    final budgets = await supabase
        .from('budgets')
        .select()
        .eq('user_id', user.id);

    // ⬇️ Expenses
    for (final e in expenses) {
      await DatabaseHelper.instance.upsertExpenseByUuid({
        'uuid': e['uuid'],
        'supabase_id': e['id'],
        'date': e['date'],
        'shop': e['shop'],
        'category': e['category'],
        'items': e['items'],
        'total': e['total'],
        'mode': e['mode'],
        'bank': e['bank'] ?? '',
        'synced': 1,
      });
    }

    // ⬇️ Budgets
    for (final b in budgets) {
      await DatabaseHelper.instance.insertBudget({
        'uuid': b['uuid'],
        'supabase_id': b['id'],
        'date': b['date'],
        'mode': b['mode'],
        'total': b['total'],
        'bank': b['bank'] ?? '',
        'synced': 1,
      });
    }

    debugPrint("Initial Supabase → SQLite sync completed.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "WalletWatch",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // EMAIL
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter your email";
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // PASSWORD
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter your password"
                          : null,
                    ),

                    const SizedBox(height: 16),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Login", style: TextStyle(fontSize: 18)),
                    ),

                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        "Don’t have an account? Register here",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
