import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final int cowColorValue; // لون كرت البقرة

  SmartAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.type,
    required this.relatedCowKey,
    required this.cowId,
    required this.cowColorValue,
  });
}

final alertsProvider = Provider<List<SmartAlert>>((ref) {
  final cows = ref.watch(cowProvider);
  final pregnancyDays = AppSettings.pregnancyDays;
  final recoveryDays = AppSettings.recoveryDays;
  final lateInseminationDays = AppSettings.lateInseminationDays;
  final dryingDays = AppSettings.dryingDays;
  final heatCycleDays = AppSettings.heatCycleDays;

  List<SmartAlert> alerts = [];

  for (var cow in cows) {
    // 1. Inseminated Cows (Waiting for birth, or monitoring heat)
    if (cow.isInseminated && !cow.isPostBirth) {
      final daysSinceInsemination = cow.daysSinceInsemination;
      final daysRemaining = pregnancyDays - daysSinceInsemination;

      // Heat Monitoring (Using heatCycleDays setting, window: -2 to +4 days)
      if (daysSinceInsemination >= (heatCycleDays - 2) && daysSinceInsemination <= (heatCycleDays + 4)) {
        alerts.add(
          SmartAlert(
            id: 'heat_${cow.uniqueKey}',
            title: 'مراقبة الشبق',
            description:
                'مر عليها $daysSinceInsemination يوم من التلقيح، يرجى مراقبتها.',
            severity: AlertSeverity.medium,
            type: AlertType.heat,
            relatedCowKey: cow.uniqueKey,
            cowId: cow.id,
            cowColorValue: cow.colorValue,
          ),
        );
      }

      // Upcoming Birth (<= 20 days)
      if (daysRemaining <= 20 && daysRemaining >= 0) {
        alerts.add(
          SmartAlert(
            id: 'birth_${cow.uniqueKey}',
            title: 'ولادة وشيكة',
            description:
                'متبقي على ولادتها $daysRemaining يوم فقط.',
            severity: AlertSeverity.high,
            type: AlertType.birth,
            relatedCowKey: cow.uniqueKey,
            cowId: cow.id,
            cowColorValue: cow.colorValue,
          ),
        );
      }

      // Overdue Birth (daysRemaining < 0)
      if (daysRemaining < 0) {
        alerts.add(
          SmartAlert(
            id: 'overdue_${cow.uniqueKey}',
            title: 'تأخر في الولادة!',
            description:
                'تجاوزت موعد ولادتها بـ ${daysRemaining.abs()} يوم، سجل الولادة الآن.',
            severity: AlertSeverity.high,
            type: AlertType.birth,
            relatedCowKey: cow.uniqueKey,
            cowId: cow.id,
            cowColorValue: cow.colorValue,
          ),
        );
      }

      // Drying Off (between 20 and dryingDays remaining)
      if (daysRemaining <= dryingDays && daysRemaining > 20) {
        alerts.add(
          SmartAlert(
            id: 'drying_${cow.uniqueKey}',
            title: 'موعد تجفيف',
            description:
                'متبقي على ولادتها $daysRemaining يوم، ابدأ بالتجفيف الآن.',
            severity: AlertSeverity.medium,
            type: AlertType.drying,
            relatedCowKey: cow.uniqueKey,
            cowId: cow.id,
            cowColorValue: cow.colorValue,
          ),
        );
      }
    }

    // 2. Post Birth (Waiting for insemination)
    if (cow.isPostBirth) {
      final daysSinceBirth = cow.daysSinceBirth;

      if (daysSinceBirth > lateInseminationDays) {
        // Late for insemination
        alerts.add(
          SmartAlert(
            id: 'lateInsem_${cow.uniqueKey}',
            title: 'تأخر في التلقيح',
            description:
                'مضى عليها $daysSinceBirth يوم من الولادة ولم تلقح بعد!',
            severity: AlertSeverity.high,
            type: AlertType.lateInsemination,
            relatedCowKey: cow.uniqueKey,
            cowId: cow.id,
            cowColorValue: cow.colorValue,
          ),
        );
      } else if (daysSinceBirth >= recoveryDays && daysSinceBirth <= lateInseminationDays) {
        // Ready for insemination
        alerts.add(
          SmartAlert(
            id: 'recovery_${cow.uniqueKey}',
            title: 'جاهزة للتلقيح',
            description:
                'أتمت $daysSinceBirth يوم بعد الولادة، وهي جاهزة للتلقيح.',
            severity: AlertSeverity.low,
            type: AlertType.recovery,
            relatedCowKey: cow.uniqueKey,
            cowId: cow.id,
            cowColorValue: cow.colorValue,
          ),
        );
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
