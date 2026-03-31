import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final dobController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  // Convert DOB to YYYY-MM-DD (if provided)
  String? dobIso;

  final supabase = Supabase.instance.client;

  //-------------------------------Function for Register The User---------------------------
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final name = nameController.text.trim();
      final mobile = mobileController.text.trim();
      final dob = dobController.text.trim();

      if (dob.isNotEmpty) {
        try {
          final parts = dob.split('/');
          if (parts.length == 3) {
            dobIso =
                '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        } catch (_) {}
      }
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'mobile': mobile, 'dob': dobIso},
      );

      final user = authResponse.user;
      if (user == null) {
        setState(() => _errorMessage = "Account creation failed.");
        return;
      }

      try {
        await supabase.from('users').upsert({
          'id': user.id,
          'name': name,
          'mobile': mobile,
          'email': email,
          'dob': dobIso,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: const [
              Icon(Icons.mark_email_read, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Account created! Please confirm your email before logging in.",
                ),
              ),
            ],
          ),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pushReplacementNamed(context, '/login');
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = "Something went wrong. Try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //-------------------------------Date Picker--------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      dobController.text =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
    }
  }

  //--------------------------------------UI----------------------------------
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1,
                          color: colorScheme.surface,
                          size: 44,
                        ),
                      ),
                    ),
                  ],
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
                          "Create Account",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 18),

                        // NAME
                        TextFormField(
                          controller: nameController,
                          decoration: _pillDecoration(
                            hint: "Name",
                            icon: Icons.person_outline,
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? "Enter your name" : null,
                        ),
                        const SizedBox(height: 14),

                        // MOBILE
                        TextFormField(
                          controller: mobileController,
                          keyboardType: TextInputType.phone,
                          decoration: _pillDecoration(
                            hint: "Mobile Number",
                            icon: Icons.phone_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Enter your mobile number";
                            }
                            // Check if only digits
                            if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                              return "Only digitis allowed";
                            }
                            //Check exactly 10 digits
                            if (v.length != 10) {
                              return "Mobile number must be exactly 10 digits";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        //  EMAIL
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _pillDecoration(
                            hint: "Email",
                            icon: Icons.mail_outline,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return "Enter your email";
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(v)) {
                              return "Enter a valid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        //  PASSWORD
                        TextFormField(
                          controller: passwordController,
                          obscureText: !_isPasswordVisible,
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
                        const SizedBox(height: 14),

                        //  DOB
                        TextFormField(
                          controller: dobController,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: _pillDecoration(
                            hint: "Date of Birth (optional)",
                            icon: Icons.calendar_today_outlined,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.edit_calendar_outlined),
                              onPressed: _pickDate,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        //  ERROR MESSAGE
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        //  REGISTER BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _registerUser,
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
                                    "Create Account",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.surface,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        //  BACK TO LOGIN TEXT
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: Text(
                            "Already have an account? Login here",
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

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    passwordController.dispose();
    dobController.dispose();
    super.dispose();
  }
}
