import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'dart:io' show Platform;
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:app_settings/app_settings.dart' as ExternalSettings;
import 'package:cow_pregnancy/providers/alerts_provider.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // v21.0.0 API: initialize uses named 'settings' parameter
  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
      );
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  static Future<void> requestPermission() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          try {
            await androidPlugin.requestNotificationsPermission();
          } catch (e) {
            debugPrint('requestNotificationsPermission error: $e');
          }
          try {
            await androidPlugin.requestExactAlarmsPermission();
          } catch (e) {
            debugPrint('requestExactAlarmsPermission error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('requestPermission error: $e');
    }
  }

  Future<void> scheduleCowNotifications(Cow cow) async {
    try {
      await cancelCowNotifications(cow.uniqueKey);

      final DateTime insemination = cow.inseminationDate;
      final int baseId = cow.uniqueKey.hashCode;

      if (cow.isPostBirth) {
        await _schedule(
          id: baseId + 5,
          title: 'تنبيه تأخير تلقيح: البقرة ${cow.id}',
          body: 'البقرة صار لها والدة 65 يوم ولم تُلقّح بعد.',
          scheduledDate: cow.birthDate!.add(const Duration(days: 65)),
        );
      } else if (!cow.isInseminated) {
        await _schedule(
          id: baseId + 1,
          title: 'اقتراب موعد الشبق: البقرة ${cow.id}',
          body: 'راقب البقرة لاحتمال عودة الشبق (مر 19 يوم)',
          scheduledDate: insemination.add(const Duration(days: 19)),
        );
        await _schedule(
          id: baseId + 2,
          title: 'موعد الشبق المتوقع: البقرة ${cow.id}',
          body: 'موعد الشبق المتوقع اليوم، جهّز البقرة للتلقيح',
          scheduledDate: insemination.add(const Duration(days: 21)),
        );
      } else {
        await _schedule(
          id: baseId + 1,
          title: 'تنبيه مراقبة: البقرة ${cow.id}',
          body: 'راقب البقرة لاحتمال عدم الحمل (مر 19 يوم)',
          scheduledDate: insemination.add(const Duration(days: 19)),
        );
        await _schedule(
          id: baseId + 2,
          title: 'فحص الحمل: البقرة ${cow.id}',
          body: 'يفضل فحص الحمل (مر 30 يوم)',
          scheduledDate: insemination.add(const Duration(days: 30)),
        );
        await _schedule(
          id: baseId + 3,
          title: 'تجفيف البقرة: ${cow.id}',
          body: 'يجب تجفيف البقرة (إيقاف الحليب) لاقتراب موعد الولادة',
          scheduledDate: insemination.add(const Duration(days: 220)),
        );
        await _schedule(
          id: baseId + 4,
          title: 'موعد الولادة: البقرة ${cow.id}',
          body: 'موعد الولادة المتوقع اليوم',
          scheduledDate: insemination.add(const Duration(days: 280)),
        );
      }
    } catch (e) {
      debugPrint('scheduleCowNotifications error: $e');
    }
  }

  // v21.0.0 API: zonedSchedule uses named parameters
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String channelId = 'cow_pregnancy_channel',
    String channelName = 'تنبيهات الحمل',
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) return;

      final selectedSound = AppSettings.notificationSound;
      final isDefault = selectedSound == 'default_sound';
      final finalChannelId =
          isDefault ? channelId : '${channelId}_$selectedSound';
      final RawResourceAndroidNotificationSound? androidSound = isDefault
          ? null
          : RawResourceAndroidNotificationSound(selectedSound);

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            finalChannelId,
            channelName,
            channelDescription: 'تنبيهات هامة للملاحظات والمواعيد',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: androidSound,
            enableVibration: true,
            fullScreenIntent: true,
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('_schedule error: $e');
    }
  }

  Future<void> scheduleCustomNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _schedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      channelId: 'notes_reminders_channel',
      channelName: 'تنبيهات الملاحظات والمهمات',
    );
  }

  // v21.0.0 API: cancel uses named 'id' parameter
  Future<void> cancelCustomNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('cancelCustomNotification error: $e');
    }
  }

  Future<void> cancelCowNotifications(String uniqueKey) async {
    try {
      final int baseId = uniqueKey.hashCode;
      await _notificationsPlugin.cancel(id: baseId + 1);
      await _notificationsPlugin.cancel(id: baseId + 2);
      await _notificationsPlugin.cancel(id: baseId + 3);
      await _notificationsPlugin.cancel(id: baseId + 4);
      await _notificationsPlugin.cancel(id: baseId + 5);
    } catch (e) {
      debugPrint('cancelCowNotifications error: $e');
    }
  }

  Future<void> scheduleDailyMorningSummary(
      int urgentCount, int totalCount) async {
    try {
      await _notificationsPlugin.cancel(id: 99999);
      if (totalCount == 0) return;

      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        AppSettings.notificationHour,
        AppSettings.notificationMinute,
        0,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final String title = urgentCount > 0
          ? '🚨 تنبيه عاجل: $urgentCount مهام عاجلة'
          : '📋 ملخص مزرعتك الصباحي';
      final String body = urgentCount > 0
          ? 'لديك $urgentCount مهام عاجلة و$totalCount تنبيه. افتح التطبيق.'
          : 'لديك $totalCount تنبيه تستحق المتابعة اليوم.';

      await _notificationsPlugin.zonedSchedule(
        id: 99999,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_summary_channel',
            'الملخص اليومي',
            channelDescription: 'إشعار صباحي يومي بملخص مهام المزرعة',
            importance: Importance.high,
            priority: Priority.high,
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('scheduleDailyMorningSummary error: $e');
    }
  }

  static Future<void> scheduleDailyNotification(
      List<SmartAlert> alerts) async {
    final int urgentCount =
        alerts.where((a) => a.severity == AlertSeverity.high).length;
    final int totalCount = alerts.length;
    await NotificationService()
        .scheduleDailyMorningSummary(urgentCount, totalCount);
  }

  Future<void> openNotificationSettings() async {
    try {
      await ExternalSettings.AppSettings.openAppSettings(
        type: ExternalSettings.AppSettingsType.notification,
      );
    } catch (e) {
      debugPrint('openNotificationSettings error: $e');
    }
  }
}
