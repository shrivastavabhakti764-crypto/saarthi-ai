import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFFFF8EF); // warm cream
  static const primary = Color(0xFFE8963C); // marigold
  static const textDark = Color(0xFF2D3B55); // deep indigo
  static const success = Color(0xFF7A9D7E); // sage green
  static const textMuted = Color(0xFF6B6459); // soft grey
  static const amberTint = Color(0xFFFBE9D0); // soft amber for alerts
}

class AppTextStyles {
  static const heading = 'Baloo2';
  static const body = 'Nunito';

  static const tagline = TextStyle(
    fontFamily: body,
    fontStyle: FontStyle.italic,
    fontSize: 18,
    color: AppColors.textMuted,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.textDark,
    secondary: AppColors.success,
    onSecondary: AppColors.textDark,
    surface: AppColors.background,
    onSurface: AppColors.textDark,
  );

  const textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontFamily: AppTextStyles.heading,
      fontWeight: FontWeight.w600,
      fontSize: 34,
      color: AppColors.textDark,
    ),
    headlineMedium: TextStyle(
      fontFamily: AppTextStyles.heading,
      fontWeight: FontWeight.w600,
      fontSize: 28,
      color: AppColors.textDark,
    ),
    titleLarge: TextStyle(
      fontFamily: AppTextStyles.heading,
      fontWeight: FontWeight.w600,
      fontSize: 24,
      color: AppColors.textDark,
    ),
    bodyLarge: TextStyle(
      fontFamily: AppTextStyles.body,
      fontWeight: FontWeight.w400,
      fontSize: 20,
      color: AppColors.textDark,
    ),
    bodyMedium: TextStyle(
      fontFamily: AppTextStyles.body,
      fontWeight: FontWeight.w400,
      fontSize: 18,
      color: AppColors.textDark,
    ),
    bodySmall: TextStyle(
      fontFamily: AppTextStyles.body,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      color: AppColors.textMuted,
    ),
    labelLarge: TextStyle(
      fontFamily: AppTextStyles.body,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      color: AppColors.textDark,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textDark,
        minimumSize: const Size.fromHeight(64),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
        textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textDark,
        textStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        minimumSize: const Size.fromHeight(56),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: textTheme.bodyMedium,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}