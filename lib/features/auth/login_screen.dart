import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:walletwatch/providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  final supabase = Supabase.instance.client;

  //----------------------Function for Login--------------------------------
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
        // EMAIL CONFIRMATION CHECK
        if (authRes.user!.emailConfirmedAt == null) {
          setState(() {
            _errorMessage = "Please confirm your email before logging in.";
          });

          await supabase.auth.signOut();
          return;
        }
        const storage = FlutterSecureStorage();
        await storage.write(key: 'useremail', value: email);
        await storage.write(key: 'username', value: email.split('@').first);

        await _initialSupabaseToLocalSync(authRes.user!);

        if (!mounted) return;

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
      String message = e.message.toLowerCase();

      if (message.contains("invalid login credentials")) {
        _errorMessage = "Invalid email or password";
      } else if (message.contains("failed host lookup") ||
          message.contains("network") ||
          message.contains("socket") ||
          message.contains("connection")) {
        _errorMessage = "No internet connection";
      } else {
        _errorMessage = "Login failed. Please try again.";
      }

      setState(() {});
    } on PostgrestException catch (_) {
      setState(() {
        _errorMessage = "No internet connection";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "No internet connection";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  //--------------------------------UI----------------------------
  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  //-----------------------Function to Sync Supabase to SQLite (For Offline Access)-------------------------------
  Future<void> _initialSupabaseToLocalSync(User user) async {
    // ALWAYS sync profile
    var profile = await supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      await supabase.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'name': user.userMetadata?['name'] ?? '',
        'mobile': user.userMetadata?['mobile'] ?? '',
        'dob': user.userMetadata?['dob'] ?? '',
      });

      profile = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    }

    if (profile != null) {
      await DatabaseHelper.instance.upsertUserProfile({
        'user_id': user.id,
        'name': profile['name'] ?? '',
        'email': profile['email'] ?? '',
        'mobile': profile['mobile'] ?? '',
        'dob': profile['dob'] ?? '',
      });
    }

    // Only skip expenses/budgets if exist
    final isEmpty = await DatabaseHelper.instance.isLocalDatabaseEmpty();

    if (!isEmpty) {
      return;
    }

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
        'user_id': user.id,
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
        'user_id': user.id,
        'supabase_id': b['id'],
        'date': b['date'],
        'mode': b['mode'],
        'total': b['total'],
        'bank': b['bank'] ?? '',
        'synced': 1,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              //  HEADER
              Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Center(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 12,
                        right: 12,
                        child: IconButton(
                          icon: Icon(
                            Theme.of(context).brightness == Brightness.dark
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: colorScheme.surface,
                          ),

                          onPressed: () {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            context.read<ThemeProvider>().toggleTheme(!isDark);
                          },
                        ),
                      ),

                      Center(
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: colorScheme.surface,
                            size: 44,
                          ),
                        ),
                      ),
                    ],
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
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.4)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          "WalletWatch",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),

                        Text(
                          "Smart Expense Tracking",
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 18),

                        //  EMAIL FIELD
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _pillDecoration(
                            hint: "Email",
                            icon: Icons.mail_lock_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Enter your email";
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
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
                          textInputAction: TextInputAction.done,
                          decoration: _pillDecoration(
                            hint: "Password",
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
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
                              style: TextStyle(
                                color: colorScheme.error,
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
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: colorScheme.surface,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.surface,
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
                          child: Text(
                            "Don't have an account? Register here",
                            style: TextStyle(
                              color: colorScheme.primary,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
