import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode') ?? 'system';
    _themeMode = saved == 'dark'
        ? ThemeMode.dark
        : saved == 'light'
        ? ThemeMode.light
        : ThemeMode.system;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', isDark ? 'dark' : 'light');
    notifyListeners();
  }

  // void toggleTheme(bool isDark) {
  //   _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
  //   notifyListeners();
  // }
  Future<void> setSystemMode() async {
    _themeMode = ThemeMode.system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', 'system');
    notifyListeners();
  }

  // void setSystemMode() {
  //   _themeMode = ThemeMode.system;
  //   notifyListeners();
  // }
}
