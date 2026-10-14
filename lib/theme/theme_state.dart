import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState extends ChangeNotifier {
  ThemeMode mode = ThemeMode.dark;
  bool _changed = false;
  bool _disposed = false;
  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed || _changed) return;
      mode = preferences.get('tcg404.theme') == 'light'
          ? ThemeMode.light
          : ThemeMode.dark;
      notifyListeners();
    } catch (_) {
      // Theme storage is optional; keep the current in-memory choice.
      return;
    }
  }

  Future<void> toggle() async {
    _changed = true;
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'tcg404.theme',
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // The switch remains usable when platform storage is unavailable.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ThemeScope extends InheritedNotifier<ThemeState> {
  const ThemeScope({super.key, required super.notifier, required super.child});
  static ThemeState? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
