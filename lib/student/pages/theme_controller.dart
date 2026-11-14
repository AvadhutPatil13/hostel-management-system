import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme controller.
///
/// Wrap your `MaterialApp` with an `AnimatedBuilder` (or
/// `ListenableBuilder`) listening to [ThemeController.instance] and read
/// `themeMode` from it, e.g.:
///
/// ```dart
/// class MyApp extends StatelessWidget {
///   const MyApp({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     return ListenableBuilder(
///       listenable: ThemeController.instance,
///       builder: (context, _) {
///         return MaterialApp(
///           themeMode: ThemeController.instance.themeMode,
///           theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
///           darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
///           home: const StudentDashboardPage(),
///         );
///       },
///     );
///   }
/// }
/// ```
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'pref_dark_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_prefsKey);

    if (stored == null) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = stored ? ThemeMode.dark : ThemeMode.light;
    }

    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}