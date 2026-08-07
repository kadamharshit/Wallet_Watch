import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password updated successfully. Please login with your new password.",
          ),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } on AuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      isDense: true,
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // HEADER
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
                  child: Container(
                    height: 82,
                    width: 82,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.lock_reset,
                      color: colorScheme.surface,
                      size: 42,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
                          "Reset Password",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "Create a new password for your account.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),

                        const SizedBox(height: 22),

                        // PASSWORD
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: _pillDecoration(
                            hint: "New Password",
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
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Enter a password";
                            }

                            if (v.length < 7) {
                              return "At least 7 characters required";
                            }

                            if (!RegExp(
                              r'^(?=.*[A-Za-z])(?=.*\d)',
                            ).hasMatch(v)) {
                              return "Must contain letters and numbers";
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Password must be at least 7 characters and contain letters and numbers.",
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // CONFIRM PASSWORD
                        TextFormField(
                          controller: _confirmController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: _pillDecoration(
                            hint: "Confirm Password",
                            icon: Icons.lock_reset_outlined,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Confirm your password";
                            }

                            if (v != _passwordController.text) {
                              return "Passwords don't match";
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "Update Password",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
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
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
