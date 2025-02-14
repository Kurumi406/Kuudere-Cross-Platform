import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color.fromARGB(255, 255, 0, 0);
  static const background = Color(0xFF1A1A1A);
  static const surface = Color(0xFF2A2A2A);
  static const text = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9E9E9E);

  static final ThemeData darkTheme = ThemeData(
    primaryColor: const Color.fromARGB(255, 255, 0, 0),
    scaffoldBackgroundColor: background,
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.inter(
        color: text,
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyLarge: GoogleFonts.inter(
        color: text,
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 14,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: text.withOpacity(0.3), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: text.withOpacity(0.3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color.fromARGB(255, 255, 0, 0), width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
  );
}
