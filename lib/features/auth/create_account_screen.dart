import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final dobController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool _isPasswordVisible = false;

  final supabase = Supabase.instance.client;

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final username = usernameController.text.trim();
      final name = nameController.text.trim();
      final mobile = mobileController.text.trim();
      final dob = dobController.text.trim(); // currently in dd/MM/yyyy

      // 1️⃣ Check if username already exists in `users` table
      // 1️⃣ Check if username already exists in `users` table
      final existingUser = await supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (existingUser != null) {
        setState(() {
          _errorMessage = "Username already exists. Try another.";
        });
        setState(() => _isLoading = false);
        return;
      }

      // 1️⃣.5 Check if email already exists in `users` table
      final existingEmail = await supabase
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingEmail != null) {
        setState(() {
          _errorMessage = "An account with this email already exists.";
        });
        setState(() => _isLoading = false);
        return;
      }

      // 2️⃣ Create account using Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userId = response.user!.id;

        // Optional: convert dob to YYYY-MM-DD to match EditProfilePage
        String? dobIso;
        if (dob.isNotEmpty) {
          try {
            // You currently set "day/month/year"
            final parts = dob.split('/');
            if (parts.length == 3) {
              final day = parts[0].padLeft(2, '0');
              final month = parts[1].padLeft(2, '0');
              final year = parts[2];
              dobIso = '$year-$month-$day'; // YYYY-MM-DD
            }
          } catch (_) {
            dobIso = null;
          }
        }

        // 3️⃣ Insert extra user details into `users` table
        await supabase.from('users').insert({
          'id': userId,
          'name': name,
          'mobile': mobile,
          'email': email,
          'username': username,
          'password': password, // ⚠️ Plaintext for now; hash later
          'dob': dobIso ?? (dob.isNotEmpty ? dob : null),
          'created_at': DateTime.now().toIso8601String(),
        });

        // // 4️⃣ Insert into `profiles` table for EditProfilePage
        // await supabase.from('profiles').insert({
        //   'id': userId,
        //   'name': name,
        //   'mobile': mobile,
        //   'email': email,
        //   'dob': dobIso, // same format as EditProfilePage expects
        // });

        // 5️⃣ Notify and redirect
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Account created successfully! Please Confirm From Email",
              ),
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        setState(() {
          _errorMessage = "Could not create account. Try again.";
        });
      }
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      debugPrint('register error: $error');
      setState(() {
        _errorMessage = "Unexpected error. Please try again.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🔲 Input decoration with black border
  InputDecoration _buildDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.black),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey[100],
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 2),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      dobController.text = "${picked.day}/${picked.month}/${picked.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
      body: Center(
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: _buildDecoration(
                        label: "Name",
                        icon: Icons.person,
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Enter your name" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: mobileController,
                      decoration: _buildDecoration(
                        label: "Mobile Number",
                        icon: Icons.phone,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value!.isEmpty ? "Enter your mobile number" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      decoration: _buildDecoration(
                        label: "Email",
                        icon: Icons.email_outlined,
                      ),
                      keyboardType: TextInputType.emailAddress,
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
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: usernameController,
                      decoration: _buildDecoration(
                        label: "Username",
                        icon: Icons.person_outline,
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Enter a username" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: _buildDecoration(
                        label: "Password",
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.black54,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Enter a password";
                        } else if (value.length < 7) {
                          return "Password must be at least 7 characters";
                        } else if (!RegExp(
                          r'^(?=.*[a-zA-Z])(?=.*\d)[a-zA-Z\d]+$',
                        ).hasMatch(value)) {
                          return "Password must contain letters and numbers";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: dobController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: _buildDecoration(
                        label: "Date of Birth (optional)",
                        icon: Icons.calendar_today,
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.edit_calendar_outlined,
                            color: Colors.black54,
                          ),
                          onPressed: _pickDate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Register",
                              style: TextStyle(fontSize: 18),
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
