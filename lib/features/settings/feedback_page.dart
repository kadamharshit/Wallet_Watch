import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:walletwatch/services/expense_database.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final supabase = Supabase.instance.client;

  final _messageController = TextEditingController();
  final _senderEmailController = TextEditingController();
  String _selectedCategory = "Bug";
  final List<String> feedbackCategory = [
    'Bug',
    'Suggestion',
    'Account Issue',
    'Other',
  ];
  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
  }

  Future<void> _fetchUserEmail() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final local = await DatabaseHelper.instance.getUserProfile(user.id);

    if (local != null) {
      _senderEmailController.text = local['email'] ?? '';
    }
    setState(() {
      _isLoading = false;
    });

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _senderEmailController.text = response['email'] ?? '';

        await DatabaseHelper.instance.upsertUserProfile({
          'email': _senderEmailController.text.trim(),
        });
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _saveFeedback() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    bool saved = false;

    try {
      final uuid = const Uuid().v4();
      final email = _senderEmailController.text;
      final message = _messageController.text;
      final category = _selectedCategory;
      final res = await supabase
          .from('feedback')
          .insert({
            'uuid': uuid,
            'user_id': user.id,
            'email': email,
            'message': message,
            'category': category,
          })
          .select('id')
          .single();

      saved = true;

      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback Saved Successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error message: $e");
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildHeader() {
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
              "Feedback",
              style: TextStyle(
                color: colorScheme.surface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
            child: Icon(Icons.feedback, color: colorScheme.surface),
          ),
        ],
      ),
    );
  }

  InputDecoration _pillDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.5),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  Widget _sectionContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
              _buildHeader(),
              _sectionContainer(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(
                                0.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: colorScheme.onSurfaceVariant
                                      .withOpacity(0.05),
                                  child: Icon(
                                    Icons.email_outlined,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Email (Read-only)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _senderEmailController.text,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _messageController,
                            maxLines: 10,
                            minLines: 5,
                            decoration: InputDecoration(
                              hintText: "Message",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              filled: true,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter the message";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField(
                            value: _selectedCategory,
                            items: feedbackCategory
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
                            decoration: _pillDecoration(
                              hint: "Feedback Category",
                              icon: Icons.category,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      _saveFeedback();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    "Save Feedback",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ElevatedButton.icon(
                //   onPressed: _saveFeedback,
                //   icon: Icon(Icons.save),
                //   label: Text("Save Feedback"),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: colorScheme.surfaceVariant,
                //   ),
                // ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
