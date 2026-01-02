import 'package:flutter/material.dart';

class AppTheme {
  // Palette
  static const Color primaryBlue = Color(0xFF0F4C75); // Deep Navy Blue
  static const Color secondaryBlue = Color(0xFF3282B8); // Bright Blue
  static const Color accentBlue = Color(0xFFBBE1FA); // Very Light Blue
  static const Color darkBackground = Color(
    0xFF1B262C,
  ); // Dark Minimal Background
  static const Color lightBackground = Color(
    0xFFF1F6F9,
  ); // Light Minimal Background

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: secondaryBlue,
      surface: lightBackground,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF1B262C),
    ),
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    // cardTheme: const CardTheme(
    //   color: Colors.white,
    //   elevation: 2,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // ),
    cardColor: Colors.white,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: secondaryBlue,
      secondary: accentBlue,
      surface: Color(0xFF222E35),
      onPrimary: Colors.white,
      onSecondary: Color(0xFF1B262C),
      onSurface: accentBlue,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: accentBlue,
      elevation: 0,
      centerTitle: true,
    ),
    // cardTheme: CardTheme(
    //   color: const Color(0xFF222E35),
    //   elevation: 2,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // ),
    cardColor: const Color(0xFF222E35),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkBackground,
      selectedItemColor: secondaryBlue,
      unselectedItemColor: Colors.grey,
    ),
  );
}
