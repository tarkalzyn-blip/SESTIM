import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

enum AlertSeverity { high, medium, low }
enum AlertType { birth, heat, drying, calfVaccine, recovery, lateInsemination }

class SmartAlert {
  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final AlertType type;
  final String relatedCowKey;
  final String cowId;

  SmartAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.type,
    required this.relatedCowKey,
    required this.cowId,
  });
}

final alertsProvider = Provider<List<SmartAlert>>((ref) {
  final cows = ref.watch(cowProvider);
  final pregnancyDays = AppSettings.pregnancyDays;
  final recoveryDays = AppSettings.recoveryDays;
  
  List<SmartAlert> alerts = [];

  for (var cow in cows) {
    // 1. Inseminated Cows (Waiting for birth, or monitoring heat)
    if (cow.isInseminated && !cow.isPostBirth) {
      final daysSinceInsemination = cow.daysSinceInsemination;
      final daysRemaining = pregnancyDays - daysSinceInsemination;
      
      // Heat Monitoring (Day 19 to 25 after insemination)
      if (daysSinceInsemination >= 19 && daysSinceInsemination <= 25) {
        alerts.add(SmartAlert(
          id: 'heat_${cow.uniqueKey}',
          title: 'مراقبة الشبق',
          description: 'البقرة #${cow.id} مر $daysSinceInsemination يوم على التلقيح. يرجى مراقبتها للتأكد من عدم عودتها للشبق.',
          severity: AlertSeverity.high,
          type: AlertType.heat,
          relatedCowKey: cow.uniqueKey,
          cowId: cow.id,
        ));
      }

      // Upcoming Birth (<= 20 days)
      if (daysRemaining <= 20 && daysRemaining >= 0) {
        alerts.add(SmartAlert(
          id: 'birth_${cow.uniqueKey}',
          title: 'ولادة وشيكة جداً',
          description: 'البقرة #${cow.id} متبقي على ولادتها $daysRemaining يوم فقط.',
          severity: AlertSeverity.high,
          type: AlertType.birth,
          relatedCowKey: cow.uniqueKey,
          cowId: cow.id,
        ));
      }
      
      // Drying Off (between 45 and 65 days remaining)
      if (daysRemaining <= 65 && daysRemaining >= 45) {
        alerts.add(SmartAlert(
          id: 'drying_${cow.uniqueKey}',
          title: 'موعد تجفيف البقرة',
          description: 'البقرة #${cow.id} متبقي على ولادتها $daysRemaining يوم، يجب البدء بتجفيفها وإيقاف الحلب.',
          severity: AlertSeverity.medium,
          type: AlertType.drying,
          relatedCowKey: cow.uniqueKey,
          cowId: cow.id,
        ));
      }
    }

    // 2. Post Birth (Waiting for insemination)
    if (cow.isPostBirth) {
      final daysSinceBirth = cow.daysSinceBirth;
      
      if (daysSinceBirth > 65) {
        // Late for insemination
        alerts.add(SmartAlert(
          id: 'lateInsem_${cow.uniqueKey}',
          title: 'تأخر في التلقيح',
          description: 'البقرة #${cow.id} مر $daysSinceBirth يوم على ولادتها ولم يتم تلقيحها بعد!',
          severity: AlertSeverity.high,
          type: AlertType.lateInsemination,
          relatedCowKey: cow.uniqueKey,
          cowId: cow.id,
        ));
      } else if (daysSinceBirth >= recoveryDays && daysSinceBirth <= 65) {
        // Ready for insemination
        alerts.add(SmartAlert(
          id: 'recovery_${cow.uniqueKey}',
          title: 'انتهاء فترة التعافي',
          description: 'البقرة #${cow.id} أتمت $daysSinceBirth يوم بعد الولادة، وأصبحت جاهزة للتلقيح.',
          severity: AlertSeverity.low,
          type: AlertType.recovery,
          relatedCowKey: cow.uniqueKey,
          cowId: cow.id,
        ));
      }
    }
  }

  // Sort alerts: High -> Medium -> Low
  alerts.sort((a, b) {
    if (a.severity == b.severity) {
      return 0;
    }
    return a.severity.index.compareTo(b.severity.index);
  });

  return alerts;
});
