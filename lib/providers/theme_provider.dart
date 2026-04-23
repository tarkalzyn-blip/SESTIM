import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() {
    return AppSettings.isDarkMode;
  }

  void toggleTheme(bool isDark) {
    AppSettings.setDarkMode(isDark);
    state = isDark;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(() => ThemeNotifier());
