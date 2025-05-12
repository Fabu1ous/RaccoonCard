import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkTheme = false;
  bool get isDarkTheme => _isDarkTheme;

  ThemeProvider() {
    _loadThemePreference();
  }

  // Загрузка сохраненной темы
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    notifyListeners();
  }

  // Сохранение выбранной темы
  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkTheme = !_isDarkTheme;
    await prefs.setBool('isDarkTheme', _isDarkTheme);
    notifyListeners();
  }

  // Получение цветов в зависимости от темы
  Color get themeColor => _isDarkTheme ? Colors.white : Colors.brown[700]!;
  Color get themeBackgroundColor =>
      _isDarkTheme ? Colors.grey[800]! : Colors.white;
  Color get scaffoldBackgroundColor =>
      _isDarkTheme ? Colors.grey[900]! : Color(0xFFF5F5F5);

  // Получение темы для MaterialApp
  ThemeData get themeData {
    return ThemeData(
      brightness: _isDarkTheme ? Brightness.dark : Brightness.light,
      primarySwatch: Colors.brown,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: themeBackgroundColor,
        foregroundColor: themeColor,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: themeBackgroundColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: themeColor),
        filled: true,
        fillColor: themeBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: themeColor),
        bodyMedium: TextStyle(color: themeColor),
        titleLarge: TextStyle(color: themeColor),
        titleMedium: TextStyle(color: themeColor),
      ),
      iconTheme: IconThemeData(color: themeColor),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: _isDarkTheme 
            ? Colors.grey[700]!.withAlpha(128)
            : Colors.brown[400]!.withAlpha(128),
        cursorColor: _isDarkTheme ? Colors.grey[500]! : Colors.brown[500]!,
        selectionHandleColor: _isDarkTheme ? Colors.grey[500]! : Colors.brown[500]!,
      ),
    );
  }
}
