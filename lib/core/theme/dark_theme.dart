import 'package:flutter/material.dart';

final ThemeData appDarkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF2E6F40), // Vibrant Green Accent
  scaffoldBackgroundColor: const Color(0xFF121212), // Deep Black
  canvasColor: const Color(0xFF1E1E1E), // Dark Grey for Cards
  useMaterial3: true,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: const Color(0xFF2E6F40),
    inactiveTrackColor: Colors.grey.shade800,
    thumbColor: Colors.white,
    overlayColor: const Color(0xFF2E6F40).withOpacity(0.2),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white70, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.white60, fontSize: 14),
    titleLarge: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
  ),
);
