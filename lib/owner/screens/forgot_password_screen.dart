import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Forgot Password'), backgroundColor: AppColors.background, elevation: 0),
    body: const Center(child: Text('Forgot password coming soon')));
}
