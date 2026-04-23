import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // إضافة إعدادات الويندوز إن كانت مدعومة في الحزمة
      // وإذا لم تكن متوافقة تماماً سيتم اصطياد الخطأ في الـ catch
      // (بعض إصدارات المكتبة لا تحتاجها أو لا تدعمها بشكل كامل بعد)
      // لكننا سنمررها إن توفرت:
      /* 
       ملاحظة: حزمة flutter_local_notifications قد لا تدعم معامل `windows` 
       مباشرة داخل InitializationSettings في بعض الإصدارات. 
       لذلك سنتعامل معها بحذر. 
      */
      
      const WindowsInitializationSettings initializationSettingsWindows =
          WindowsInitializationSettings(
            appName: 'cow_pregnancy',
            appUserModelId: 'com.example.cow_pregnancy',
            guid: '028a3f8b-f482-41f9-9ba3-8706dce446fa',
          );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        windows: initializationSettingsWindows,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
      );
      
      if (!kIsWeb && Platform.isAndroid) {
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notification Initialization Error: $e');
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
          body: 'البقرة صار لها والدة 65 يوم ولم تُلقّح بعد، يرجى التجهيز للتلقيح.',
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
      debugPrint('Notification Scheduling Error: $e');
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) return;

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'cow_pregnancy_channel',
            'تنبيهات الحمل',
            channelDescription: 'إشعارات مواعيد الحمل للأبقار',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Notification Zoned Schedule Error: $e');
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
      debugPrint('Notification Cancel Error: $e');
    }
  }

  /// Schedules a daily morning notification at 8:00 AM summarizing active alerts.
  Future<void> scheduleDailyMorningSummary(int urgentCount, int totalCount) async {
    try {
      // Cancel previous daily notification
      await _notificationsPlugin.cancel(id: 99999);
      if (totalCount == 0) return;

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, AppSettings.notificationHour, 0, 0);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final String title = urgentCount > 0
          ? '🚨 تنبيه عاجل: $urgentCount مهام عاجلة'
          : '📋 ملخص مزرعتك الصباحي';
      final String body = urgentCount > 0
          ? 'لديك $urgentCount مهام عاجلة و$totalCount تنبيه بالمجموع. افتح التطبيق لاتخاذ الإجراءات.'
          : 'لديك $totalCount تنبيه تستحق المتابعة اليوم. تحقق من لوحة التحكم.';

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
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );
    } catch (e) {
      debugPrint('Daily Summary Notification Error: $e');
    }
  }
}
