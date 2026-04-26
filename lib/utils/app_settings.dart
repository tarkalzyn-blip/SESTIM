import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  static Box get _box => Hive.box('settings');

  static int get pregnancyDays => _box.get('pregnancyDays', defaultValue: 280);
  static Future<void> setPregnancyDays(int val) => _box.put('pregnancyDays', val);

  static int get recoveryDays => _box.get('recoveryDays', defaultValue: 60);
  static Future<void> setRecoveryDays(int val) => _box.put('recoveryDays', val);

  static int get lateInseminationDays => _box.get('lateInseminationDays', defaultValue: 70);
  static Future<void> setLateInseminationDays(int val) => _box.put('lateInseminationDays', val);

  static int get dryingDays => _box.get('dryingDays', defaultValue: 60);
  static Future<void> setDryingDays(int val) => _box.put('dryingDays', val);

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

  static String get notificationSound => _box.get('notificationSound', defaultValue: 'default_sound');
  static Future<void> setNotificationSound(String val) => _box.put('notificationSound', val);

  static String get datePickerSound => _box.get('datePickerSound', defaultValue: 'tick.mp3');
  static Future<void> setDatePickerSound(String val) => _box.put('datePickerSound', val);
}
