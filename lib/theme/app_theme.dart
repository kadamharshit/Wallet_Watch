import 'package:flutter/material.dart';

final lightTheme = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: const Color(0xFF3B82F6),
    secondary: const Color(0xFF22C55E),
    surface: Colors.white,
    background: const Color(0xFFF5F7FA),
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  cardColor: Colors.white,
  useMaterial3: true,
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,

  scaffoldBackgroundColor: const Color(0xFF0F172A),

  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF22C55E),
    surface: Color(0xFF1E293B),
    background: Color(0xFF0F172A),
  ),

  cardColor: const Color(0xFF1E293B),

  progressIndicatorTheme: const ProgressIndicatorThemeData(
    linearTrackColor: Colors.white12,
  ),
);
