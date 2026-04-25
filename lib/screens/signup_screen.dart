import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authActionProvider.notifier).signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        // If successful, the auth state change will be handled by the wrapper
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authActionProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal, Colors.blueGrey],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_outlined, size: 70, color: Colors.teal),
                      const SizedBox(height: 16),
                      const Text(
                        'إنشاء حساب جديد',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 32),
                      
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'يرجى إدخال الاسم' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                          if (!value.contains('@')) return 'بريد إلكتروني غير صالح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (value) => (value == null || value.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_reset),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) return 'كلمات المرور غير متطابقة';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      
                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: authState.isLoading ? null : _handleSignUp,
                          child: authState.isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('إنشاء الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('لديك حساب بالفعل؟'),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
