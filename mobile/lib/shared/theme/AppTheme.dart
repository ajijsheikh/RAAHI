import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6750A4),
      secondary: Color(0xFF00D1B2),
      surface: Colors.white,
      onSurface: Colors.black87,
      error: Color(0xFFCF6679),
      outline: Colors.grey,
    ),
    scaffoldBackgroundColor: Colors.grey[50],
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Color(0xFF6750A4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Color(0xFF6750A4),
      ),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF6750A4),
      size: 24,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF6750A4),
      elevation: 0,
    ),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF6750A4),
      secondary: Color(0xFF00D1B2),
      surface: Color(0xFF161B22),
      onSurface: Colors.white,
      error: Color(0xFFCF6679),
      outline: Colors.grey,
    ),
    scaffoldBackgroundColor: Color(0xFF161B22),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Color(0xFF6750A4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF6750A4),
      size: 24,
    ),
  );
}