import 'package:flutter/material.dart';

class AppTheme {
  static const Color leadColor = Color(0xFF37474F);
  static const Color greyColor = Color(0xFF78909C);
  static const Color darkBackground = Color(0xFF000000);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFF5F5F5);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: leadColor,
      secondary: greyColor,
      surface: surfaceLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: leadColor,
      elevation: 0,
    ),
    cardColor: Colors.white,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightBackground,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: leadColor, size: 30);
        }
        return const IconThemeData(color: Colors.grey, size: 26);
      }),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: greyColor,
      secondary: leadColor,
      surface: surfaceDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: surfaceDark,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkBackground,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 30);
        }
        return IconThemeData(color: Colors.grey[600], size: 26);
      }),
    ),
  );
}
