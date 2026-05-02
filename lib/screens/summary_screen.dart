import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/providers/alerts_provider.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';
import 'package:cow_pregnancy/screens/cow_detail_screen.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';
import 'package:cow_pregnancy/widgets/cow_id_badge.dart';
import 'package:cow_pregnancy/screens/notes_screen.dart';

// Shared provider to control the main bottom navigation tab from anywhere
final mainNavIndexProvider = StateProvider<int>((ref) => 0);
// Shared provider to control which screen is shown in the "more" tab
final mainNavMoreScreenProvider = StateProvider<String>((ref) => 'reports');

// Provider to manage and persist summary sort preference
enum SummarySort { newest, oldest }
enum SummaryViewMode { herdOnly, totalHeads }

final summaryViewModeProvider = StateNotifierProvider<SummaryViewModeNotifier, SummaryViewMode>((ref) {
  return SummaryViewModeNotifier();
});

class SummaryViewModeNotifier extends StateNotifier<SummaryViewMode> {
  SummaryViewModeNotifier() : super(SummaryViewMode.herdOnly) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('settings');
    final savedMode = box.get('summary_view_mode_pref', defaultValue: 'herdOnly');
    state = savedMode == 'totalHeads' ? SummaryViewMode.totalHeads : SummaryViewMode.herdOnly;
  }

  void setMode(SummaryViewMode mode) {
    state = mode;
    final box = Hive.box('settings');
    box.put('summary_view_mode_pref', mode == SummaryViewMode.totalHeads ? 'totalHeads' : 'herdOnly');
  }
}

final summarySortProvider = StateNotifierProvider<SummarySortNotifier, SummarySort>((ref) {
  return SummarySortNotifier();
});

class SummarySortNotifier extends StateNotifier<SummarySort> {
  SummarySortNotifier() : super(SummarySort.newest) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('settings');
    final savedSort = box.get('summary_sort_pref', defaultValue: 'newest');
    state = savedSort == 'oldest' ? SummarySort.oldest : SummarySort.newest;
  }

  void setSort(SummarySort sort) {
    state = sort;
    final box = Hive.box('settings');
    box.put('summary_sort_pref', sort == SummarySort.oldest ? 'oldest' : 'newest');
  }
}

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCows = ref.watch(cowProvider);
    final smartAlerts = ref.watch(alertsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final birthStats = ref.watch(birthStatsProvider);
    final viewMode = ref.watch(summaryViewModeProvider);

    // Filter out standalone calves for cow-related stats
    final cows = allCows.where((c) => !c.isStandaloneCalf).toList();

    ref.listen(alertsProvider, (previous, next) {
      if (next.isNotEmpty) {
        final urgentCount = next.where((a) => a.severity == AlertSeverity.high).length;
        NotificationService().scheduleDailyMorningSummary(urgentCount, next.length);
      }
    });

    final int totalCows = cows.length;
    
    // Breeding Status
    int breedingReady = 0; 
    int breedingMonitoring = 0; 
    int breedingPregnant = 0; 
    int breedingOverdue = 0;
    int breedingLate = 0; 
    int breedingEmpty = 0; 

    List<Cow> listReady = [];
    List<Cow> listMonitoring = [];
    List<Cow> listPregnant = [];
    List<Cow> listOverdue = [];
    List<Cow> listLate = [];
    List<Cow> listEmpty = [];

    // Production Stages
    int prodMilking = 0; 
    int prodDrying = 0; 
    int prodHeifer = 0; 
    int prodHeiferClose = 0;

    List<Cow> listMilking = [];
    List<Cow> listDrying = [];
    List<Cow> listHeifer = [];
    List<Cow> listHeiferClose = [];
    List<Cow> listHeifersReadyForInsem = [];
    
    final int monitoringDays = AppSettings.monitoringDays;
    final int dryingDays = AppSettings.dryingDays;
    final int pregnancyDays = AppSettings.pregnancyDays;
    final int recoveryDays = AppSettings.recoveryDays;
    final int lateInsemDays = AppSettings.lateInseminationDays;
    final int heiferInsemAge = AppSettings.heiferInseminationAge;

    for (var cow in cows) {
      bool hasBirthHistory = cow.hasGivenBirth || cow.isPostBirth;
      
      // ── 1. مسار حالات التكاثر (حصرية: البقرة في مكان واحد فقط) ──────────
      if (cow.isInseminated) {
        // مسار الملقحة: (تأخر ولادة -> تحت الفحص -> حامل)
        final daysRemaining = pregnancyDays - cow.daysSinceInsemination;
        
        if (daysRemaining < 0) {
          breedingOverdue++;
          listOverdue.add(cow);
        } else if (cow.daysSinceInsemination <= monitoringDays) {
          breedingMonitoring++;
          listMonitoring.add(cow);
        } else {
          breedingPregnant++;
          listPregnant.add(cow);
        }
      } else {
        // مسار غير الملقحة: (حديثة ولادة -> جاهزة -> متأخرة)
        if (hasBirthHistory) {
          if (cow.daysSinceBirth < recoveryDays) {
            breedingEmpty++;
            listEmpty.add(cow);
          } else if (cow.daysSinceBirth > lateInsemDays) {
            breedingLate++;
            listLate.add(cow);
          } else {
            breedingReady++;
            listReady.add(cow);
          }
        } else {
          // البكيرات غير الملقحة: تدخل "جاهزة" إذا وصلت للعمر المطلوب
          final ageInDays = cow.dateOfBirth != null 
              ? DateTime.now().difference(cow.dateOfBirth!).inDays 
              : 0;
          final ageInMonths = ageInDays / 30.44;
          
          if (ageInMonths >= heiferInsemAge) {
            breedingReady++;
            listReady.add(cow);
          }
        }
      }

      // ── 2. مسار مراحل الإنتاج (حلوب -> مجففة -> بكيرة) ──────────────────
      if (cow.isHeifer) {
        // مسار البكيرة
        final daysRemaining = pregnancyDays - cow.daysSinceInsemination;
        if (cow.isInseminated && daysRemaining < 0) {
          // تتجاوز مرحلة الإنتاج وتظهر فقط في "تأخر بالولادة"
        } else if (cow.isInseminated && daysRemaining <= dryingDays) {
          prodHeiferClose++;
          listHeiferClose.add(cow);
        } else {
          prodHeifer++;
          listHeifer.add(cow);
        }
      } else {
        // مسار البقرة الكبيرة (بالغ)
        final daysRemaining = pregnancyDays - cow.daysSinceInsemination;
        if (cow.isInseminated && daysRemaining < 0) {
          // تتجاوز مرحلة الإنتاج وتظهر فقط في "تأخر بالولادة"
        } else if (cow.isInseminated && daysRemaining <= dryingDays) {
          prodDrying++;
          listDrying.add(cow);
        } else {
          prodMilking++;
          listMilking.add(cow);
        }
      }
    }

    final allCalves = ref.watch(allCalvesProvider);

    for (var calfMap in allCalves) {
      if (calfMap['isExited'] == true) continue;
      final isMale = calfMap['note']?.toString().contains('ذكر') ?? false;
      if (isMale) continue;

      final dynamic rawDate = calfMap['date'];
      final birthDate = rawDate is DateTime ? rawDate : DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      final ageInDays = DateTime.now().difference(birthDate).inDays;
      final ageInMonths = ageInDays / 30.44;

      if (ageInMonths >= heiferInsemAge) {
        final tempCow = Cow(
          id: calfMap['calfId'] ?? 'غير معروف',
          inseminationDate: DateTime.now(),
          dateOfBirth: birthDate,
          colorValue: calfMap['calfColorValue'] ?? Colors.grey.toARGB32(),
          gender: 'female',
          isInseminated: false,
          isStandaloneCalf: true,
          history: [],
        );
        listHeifersReadyForInsem.add(tempCow);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('اللوحة الذكية', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
          tooltip: 'الإعدادات',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: TextButton.icon(
              onPressed: () {
                ref.read(mainNavMoreScreenProvider.notifier).state = 'notes';
                ref.read(mainNavIndexProvider.notifier).state = 4;
              },
              icon: const Icon(Icons.note_alt_outlined, size: 21),
              label: const Text('ملاحظات', style: TextStyle(fontSize: 15)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (syncStatus != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(syncStatus, style: const TextStyle(color: Colors.red, fontSize: 12))),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.red),
                      onPressed: () => ref.read(cowProvider.notifier).syncLocalToCloud(),
                    )
                  ],
                ),
              ),
            
            // --- Mode Selector (Toggle) ---
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeToggleBtn(
                      context,
                      ref,
                      title: 'تفاصيل البقر',
                      mode: SummaryViewMode.herdOnly,
                      isActive: viewMode == SummaryViewMode.herdOnly,
                      activeColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final current = ref.read(summaryViewModeProvider);
                      final nextMode = current == SummaryViewMode.herdOnly ? SummaryViewMode.totalHeads : SummaryViewMode.herdOnly;
                      ref.read(summaryViewModeProvider.notifier).setMode(nextMode);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sync, size: 20, color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeToggleBtn(
                      context,
                      ref,
                      title: 'العدد الكلي',
                      mode: SummaryViewMode.totalHeads,
                      isActive: viewMode == SummaryViewMode.totalHeads,
                      activeColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // --- Dynamic Header Card ---
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: viewMode == SummaryViewMode.herdOnly
                  ? _buildHerdOnlyCard(totalCows, birthStats)
                  : _buildTotalHeadsCard(totalCows, birthStats['active'] ?? 0),
            ),
            
            const SizedBox(height: 30),
            const Text(
              'حالات التكاثر',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            _buildStatusGrid(context, ref, [
              _StatusItemData('جاهزة للتلقيح', breedingReady, Colors.green, '🟢', listReady, _TimeInfoType.daysSinceBirthOnly),
              _StatusItemData('تحت الفحص', breedingMonitoring, Colors.amber, '🟡', listMonitoring, _TimeInfoType.daysSinceInsemination),
              _StatusItemData('حوامل', breedingPregnant, Colors.blue, '🔵', listPregnant, _TimeInfoType.monthsDaysSinceInsemination),
              _StatusItemData('تأخر بالولادة', breedingOverdue, Colors.deepOrange, '⚠️', listOverdue, _TimeInfoType.daysRemainingUntilBirth),
              _StatusItemData('تأخر بالتلقيح', breedingLate, Colors.red, '🔴', listLate, _TimeInfoType.daysSinceBirthOnly),
              _StatusItemData('حديثة الولادة', breedingEmpty, Colors.grey, '⚪', listEmpty, _TimeInfoType.daysSinceBirthOnly),
            ]),
            
            const SizedBox(height: 30),
            const Text(
              'مراحل الإنتاج',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            _buildStatusGrid(context, ref, [
              _StatusItemData('حلوب', prodMilking, Colors.blueAccent, '🥛', listMilking, _TimeInfoType.daysSinceBirth),
              _StatusItemData('مجففة وقريبة من الولادة', prodDrying, Colors.indigo, '💤', listDrying, _TimeInfoType.daysRemainingUntilBirth),
              _StatusItemData('بكيرة', prodHeifer, Colors.orange, '🐄', listHeifer, _TimeInfoType.monthsDaysSinceInsemination),
              _StatusItemData('بكيرة قريبة من الولادة', prodHeiferClose, Colors.pinkAccent, '🤰', listHeiferClose, _TimeInfoType.daysRemainingUntilBirth),
            ]),
            
            const SizedBox(height: 30),
            const Text(
              'إدارة العجولات',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            _buildStatusGrid(context, ref, [
              _StatusItemData('عجولات جاهزة للتلقيح', listHeifersReadyForInsem.length, Colors.teal, '🐮✨', listHeifersReadyForInsem, _TimeInfoType.daysSinceBirth),
            ]),
            
            const SizedBox(height: 30),
            Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.redAccent),
                const SizedBox(width: 8),
                const Text(
                  'التنبيهات والمهام',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${smartAlerts.length} مهام', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (smartAlerts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
                    SizedBox(height: 10),
                    Text('لا توجد مهام حالياً، القطيع بخير!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              )
            else
              ...smartAlerts.map((alert) => _buildSmartAlertCard(context, alert, allCows)),
              
            const SizedBox(height: 30),
            const Text(
              'إحصائيات المواليد',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  _buildCalfStatRow('إجمالي العجول', birthStats['total'] ?? 0, Icons.auto_awesome, Colors.amber),
                  const Divider(height: 30),
                  Row(
                    children: [
                      Expanded(child: _buildGenderStat('عجول (ذكر)', birthStats['male'] ?? 0, Colors.blue.shade300, Icons.male)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildGenderStat('عجلات (أنثى)', birthStats['female'] ?? 0, Colors.pink.shade300, Icons.female)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartAlertCard(BuildContext context, SmartAlert alert, List<Cow> cows) {
    Color cardColor;
    IconData icon;
    
    switch (alert.type) {
      case AlertType.birth: cardColor = Colors.orange; icon = Icons.child_friendly; break;
      case AlertType.heat: cardColor = Colors.amber; icon = Icons.favorite_border; break;
      case AlertType.lateInsemination: cardColor = Colors.redAccent; icon = Icons.warning_amber_rounded; break;
      case AlertType.drying: cardColor = Colors.blue; icon = Icons.opacity_outlined; break;
      case AlertType.calfVaccine: cardColor = Colors.teal; icon = Icons.vaccines; break;
      case AlertType.recovery: cardColor = Colors.green; icon = Icons.health_and_safety; break;
    }

    final cowColor = Color(alert.cowColorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            try {
              final cow = cows.firstWhere((c) => c.uniqueKey == alert.relatedCowKey);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CowDetailScreen(cow: cow)));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('البقرة غير موجودة!')));
            }
          },
          child: Ink(
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardColor.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(icon, color: cardColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                alert.title.replaceAll('البقرة رقم', '').replaceAll('البقرة', '').trim(),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cardColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            CowIdBadge(id: alert.cowId, color: cowColor, fontSize: 14, boxSize: 15),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(alert.description.replaceAll('البقرة رقم', '').replaceAll('البقرة', '').trim(), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalfStatRow(String title, int count, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 15),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGenderStat(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildModeToggleBtn(BuildContext context, WidgetRef ref, {required String title, required SummaryViewMode mode, required bool isActive, required Color activeColor}) {
    return InkWell(
      onTap: () => ref.read(summaryViewModeProvider.notifier).setMode(mode),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isActive ? activeColor : Colors.grey.shade300, width: 1.5),
          boxShadow: isActive ? [BoxShadow(color: activeColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildHerdOnlyCard(int totalCows, Map<String, dynamic> birthStats) {
    return Container(
      key: const ValueKey('herd_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text('إجمالي القطيع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 5),
          Text('$totalCows بقرة', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.blue)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: Color(0x222196F3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('عجول ذكور', birthStats['male'] ?? 0, Colors.blue),
              _buildMiniStat('عجلات إناث', birthStats['female'] ?? 0, Colors.pink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalHeadsCard(int totalCows, int totalCalves) {
    final total = totalCows + totalCalves;
    return Container(
      key: const ValueKey('total_card'),
      width: double.infinity,
      // زيادة الـ padding ليتساوى الارتفاع مع الكرت الآخر
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('إجمالي رؤوس المزرعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 10),
          Text('$total رأس', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.7))),
      ],
    );
  }

  void _showCowsListDialog(BuildContext context, WidgetRef ref, String title, List<Cow> cows, Color themeColor, [_TimeInfoType timeInfoType = _TimeInfoType.none]) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final currentSort = ref.watch(summarySortProvider);
          final sortedCows = List<Cow>.from(cows);
          sortedCows.sort((a, b) {
            final valA = _getSortValue(a, timeInfoType);
            final valB = _getSortValue(b, timeInfoType);
            return currentSort == SummarySort.newest ? valB.compareTo(valA) : valA.compareTo(valB);
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: themeColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(Icons.list_alt_rounded, color: themeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 18))),
                  PopupMenuButton<SummarySort>(
                    icon: Icon(Icons.sort, color: themeColor),
                    onSelected: (sort) => ref.read(summarySortProvider.notifier).setSort(sort),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: SummarySort.newest, child: Text('الأحدث أولاً')),
                      PopupMenuItem(value: SummarySort.oldest, child: Text('الأقدم أولاً')),
                    ],
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: sortedCows.isEmpty 
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('لا يوجد أبقار في هذه القائمة', textAlign: TextAlign.center))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedCows.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cow = sortedCows[index];
                      final timeParts = _buildTimeParts(cow, timeInfoType);
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => CowDetailScreen(cow: cow)));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(timeParts.$1.isNotEmpty ? timeParts.$1 : 'لا توجد بيانات', style: TextStyle(fontSize: 13, color: themeColor, fontWeight: FontWeight.bold)),
                                    if (timeParts.$2.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(timeParts.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                    ],
                                  ],
                                ),
                              ),
                              CowIdBadge(id: cow.id, color: cow.color, fontSize: 14, boxSize: 15),
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusGrid(BuildContext context, WidgetRef ref, List<_StatusItemData> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        final isLastItem = item == items.last;
        double width = (MediaQuery.of(context).size.width - 40 - 12) / 2;
        if ((items.length % 2 != 0) && isLastItem) width = MediaQuery.of(context).size.width - 40;

        return InkWell(
          onTap: () => _showCowsListDialog(context, ref, item.title, item.cows, item.color, item.timeInfoType),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: item.color.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [BoxShadow(color: item.color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(item.count.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: item.color, height: 1)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  int _getSortValue(Cow cow, _TimeInfoType type) {
    switch (type) {
      case _TimeInfoType.daysSinceBirth: 
      case _TimeInfoType.daysSinceBirthOnly:
        if (cow.isPostBirth) return cow.daysSinceBirth;
        if (cow.isInseminated) return cow.daysSinceInsemination;
        if (cow.dateOfBirth != null) return DateTime.now().difference(cow.dateOfBirth!).inDays;
        return 0;
      case _TimeInfoType.daysSinceInsemination:
      case _TimeInfoType.monthsDaysSinceInsemination:
      case _TimeInfoType.daysRemainingUntilBirth:
        if (!cow.isInseminated && cow.dateOfBirth != null) {
          return DateTime.now().difference(cow.dateOfBirth!).inDays;
        }
        return cow.daysSinceInsemination;
      default: return 0;
    }
  }

  (String, String) _buildTimeParts(Cow cow, _TimeInfoType type) {
    // If we expect insemination data but cow isn't inseminated, fallback to Age
    bool needsInsemFallback = (type == _TimeInfoType.daysSinceInsemination || 
                               type == _TimeInfoType.monthsDaysSinceInsemination || 
                               type == _TimeInfoType.daysRemainingUntilBirth) && !cow.isInseminated;

    if (needsInsemFallback) {
      return ('العمر', cow.age);
    }

    switch (type) {
      case _TimeInfoType.daysSinceBirth: 
        // الأولوية الأولى: أيام الحليب (منذ الولادة) - كما طلبت للفئة الحلوب
        if (cow.isPostBirth) {
          final months = (cow.daysSinceBirth / 30).floor();
          final days = cow.daysSinceBirth % 30;
          final timeStr = months > 0 ? '$months شهر و $days يوم' : '$days يوم';
          return ('منذ الولادة', timeStr);
        }
        // الأولوية الثانية: إذا لم تلد بعد ولكنها ملقحة، أظهر أيام التلقيح
        if (cow.isInseminated) {
          final months = (cow.daysSinceInsemination / 30).floor();
          final days = cow.daysSinceInsemination % 30;
          final timeStr = months > 0 ? '$months شهر و $days يوم' : '$days يوم';
          return ('منذ التلقيح', timeStr);
        }
        // الأولوية الثالثة: العمر
        if (cow.dateOfBirth != null) {
          return ('العمر', cow.age);
        }
        final fallbackMonths = (cow.daysSinceInsemination / 30).floor();
        final fallbackDays = cow.daysSinceInsemination % 30;
        final fallbackStr = fallbackMonths > 0 ? '$fallbackMonths شهر و $fallbackDays يوم' : '$fallbackDays يوم';
        return ('منذ التلقيح', fallbackStr);

      case _TimeInfoType.daysSinceBirthOnly:
        if (cow.isPostBirth) {
          return ('منذ الولادة', '${cow.daysSinceBirth} يوم');
        }
        if (cow.isInseminated) {
          return ('منذ التلقيح', '${cow.daysSinceInsemination} يوم');
        }
        if (cow.dateOfBirth != null) {
          return ('العمر', cow.age);
        }
        return ('منذ التلقيح', '${cow.daysSinceInsemination} يوم');

      case _TimeInfoType.daysSinceInsemination: 
        return ('منذ التلقيح', '${cow.daysSinceInsemination} يوم');

      case _TimeInfoType.monthsDaysSinceInsemination:
        final months = (cow.daysSinceInsemination / 30).floor();
        final days = cow.daysSinceInsemination % 30;
        return ('مدة الحمل', '$months شهر و $days يوم');

      case _TimeInfoType.daysRemainingUntilBirth:
        final remaining = AppSettings.pregnancyDays - cow.daysSinceInsemination;
        return remaining < 0 ? ('متأخرة عن الولادة', '${-remaining} يوم') : ('باقي للولادة', '$remaining يوم');
        
      default: return ('', '');
    }
  }
}

class _StatusItemData {
  final String title;
  final int count;
  final Color color;
  final String emoji;
  final List<Cow> cows;
  final _TimeInfoType timeInfoType;
  _StatusItemData(this.title, this.count, this.color, this.emoji, this.cows, [this.timeInfoType = _TimeInfoType.none]);
}

enum _TimeInfoType {
  none,
  daysSinceBirth,
  daysSinceBirthOnly,
  daysSinceInsemination,
  monthsDaysSinceInsemination,
  daysRemainingUntilBirth,
}
