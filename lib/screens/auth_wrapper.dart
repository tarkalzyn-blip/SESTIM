import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/auth_provider.dart';
import 'package:cow_pregnancy/screens/login_screen.dart';
import 'package:cow_pregnancy/screens/main_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('حدث خطأ في المصادقة: $error'),
        ),
      ),
    );
  }
}
