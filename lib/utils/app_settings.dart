import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  static Box get _box => Hive.box('settings');

  static int get pregnancyDays => _box.get('pregnancyDays', defaultValue: 280);
  static Future<void> setPregnancyDays(int val) => _box.put('pregnancyDays', val);

  static int get recoveryDays => _box.get('recoveryDays', defaultValue: 65);
  static Future<void> setRecoveryDays(int val) => _box.put('recoveryDays', val);

  static int get heatCycleDays => _box.get('heatCycleDays', defaultValue: 21);
  static Future<void> setHeatCycleDays(int val) => _box.put('heatCycleDays', val);

  static bool get isDarkMode => _box.get('isDarkMode', defaultValue: false);
  static Future<void> setDarkMode(bool val) => _box.put('isDarkMode', val);

  static bool get exactSearchMatch => _box.get('exactSearchMatch', defaultValue: false);
  static Future<void> setExactSearchMatch(bool val) => _box.put('exactSearchMatch', val);

  static int get notificationHour => _box.get('notificationHour', defaultValue: 8);
  static Future<void> setNotificationHour(int val) => _box.put('notificationHour', val);

  static int get notificationMinute => _box.get('notificationMinute', defaultValue: 0);
  static Future<void> setNotificationMinute(int val) => _box.put('notificationMinute', val);

  static String get fontFamily => _box.get('fontFamily', defaultValue: 'Cairo');
  static Future<void> setFontFamily(String val) => _box.put('fontFamily', val);
}
