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

class FontNotifier extends Notifier<String> {
  @override
  String build() {
    return AppSettings.fontFamily;
  }

  void setFont(String fontFamily) {
    AppSettings.setFontFamily(fontFamily);
    state = fontFamily;
  }
}

final fontProvider = NotifierProvider<FontNotifier, String>(() => FontNotifier());

class SyncStatusNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setStatus(String? status) => state = status;
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, String?>(() => SyncStatusNotifier());
