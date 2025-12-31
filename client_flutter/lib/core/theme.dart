import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primary = Color(0xFF2B3745);
  static const Color background = Color(0xFF18222D);
  static const Color chatBackground = Color(0xFF16202A);

  static const Color bubbleMe = Color(0xFF406283);
  static const Color bubbleCompanion = Color(0xFF2B3745);

  static const Color accent = Color(0xFF5E9ED6);
  static const Color floatingButton = Color.fromARGB(255, 144, 203, 255);

  static const Color text = Color(0xFFEAEBEB);
  static const Color textSecondary = Color(0xFFEAEBEB);
  static const Color icon = Color(0xFF7A8B9A);

  static const Color dividerColor = Color(0xFF16202A);

  static ThemeData get darkTheme {
    return ThemeData(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        background: background,
        surface: primary,
        onPrimary: text,
        onSecondary: text,
        onBackground: text,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        elevation: 0.5,
        shadowColor: Colors.black,
        iconTheme: IconThemeData(color: icon),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w500,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: floatingButton,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text, fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w500),
        labelLarge:
            TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: background,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primary,
        hintStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 0.8,
      ),
    );
  }
}
