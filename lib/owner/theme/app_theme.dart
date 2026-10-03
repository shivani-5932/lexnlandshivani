import 'package:flutter/material.dart';

class AppColors {
  static const primary      = Color(0xFFAA3D67);
  static const primaryLight = Color(0xFFF6E8EE);
  static const success      = Color(0xFF2E7D32);
  static const successBg    = Color(0xFFE8F5E9);
  static const error        = Color(0xFFC62828);
  static const background   = Color(0xFFFAF6F8);
  static const surface      = Color(0xFFFFFFFF); // ✅ added - used in login_screen
  static const textDark     = Color(0xFF1A1A1A);
  static const textMuted    = Color(0xFF757575);
  static const textLight    = Color(0xFFBDBDBD);
  static const border       = Color(0xFFEAD9E1);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
    ),
  );
}
