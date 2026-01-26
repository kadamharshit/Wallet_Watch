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

    // if (!_agreeTerms) {
    //   setState(() {
    //     _errorMessage = "Please accept terms and conditions";
    //   });
    //   return;
    // }

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

        const storage = FlutterSecureStorage();
        await storage.write(key: 'useremail', value: email);
        await storage.write(key: 'username', value: email.split('@').first);

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
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              //  HEADER
              Container(
                height: 260,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Center(
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              //  WHITE CARD FORM
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Text(
                          "WalletWatch",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 18),

                        //  EMAIL FIELD
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: "Email",
                            prefixIcon: const Icon(Icons.mail_outline),
                            filled: true,
                            fillColor: const Color(0xFFF6F6F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Enter your email";
                            }
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(value)) {
                              return "Enter a valid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        //  PASSWORD FIELD
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            hintText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
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
                            filled: true,
                            fillColor: const Color(0xFFF6F6F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter your password"
                              : null,
                        ),

                        const SizedBox(height: 12),
                        //  ERROR MESSAGE
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        //  LOGIN BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        //  REGISTER TEXT
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text(
                            "Don't have an account? Register here",
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        //  SOCIAL LOGIN UI (ONLY UI)
                        // Row(
                        //   children: const [
                        //     Expanded(child: Divider()),
                        //     Padding(
                        //       padding: EdgeInsets.symmetric(horizontal: 10),
                        //       child: Text("or"),
                        //     ),
                        //     Expanded(child: Divider()),
                        //   ],
                        // ),
                        const SizedBox(height: 14),

                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        //   children: [
                        //     _socialBox(Icons.g_mobiledata, Colors.red),
                        //     _socialBox(Icons.apple, Colors.black),
                        //     _socialBox(Icons.facebook, Colors.blue),
                        //   ],
                        // ),
                        const SizedBox(height: 14),

                        // const Text(
                        //   "Log in with your social media account",
                        //   style: TextStyle(fontSize: 12, color: Colors.grey),
                        // ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // static Widget _socialBox(IconData icon, Color color) {
  //   return Container(
  //     height: 48,
  //     width: 60,
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.12),
  //       borderRadius: BorderRadius.circular(14),
  //     ),
  //     child: Icon(icon, color: color, size: 28),
  //   );
  // }
}
