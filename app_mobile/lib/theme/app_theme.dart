import 'package:flutter/material.dart';

class AppTheme {
  // Palette
  // Palette - Matte Lead / Gray Scale
  static const Color primaryBlue = Color(
    0xFF455A64,
  ); // Matte Lead (Blue Grey 700)
  static const Color secondaryBlue = Color(0xFF607D8B); // Blue Grey 500
  static const Color accentBlue = Color(0xFFCFD8DC); // Blue Grey 100
  static const Color darkBackground = Color(0xFF121212); // Pure Dark Background
  static const Color lightBackground = Color(
    0xFFECEFF1,
  ); // Very Light Blue Grey

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
      surface: Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
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
    cardColor: const Color(0xFF1E1E1E),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkBackground,
      selectedItemColor: secondaryBlue,
      unselectedItemColor: Colors.grey,
    ),
  );
}
