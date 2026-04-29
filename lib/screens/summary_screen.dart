import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/providers/alerts_provider.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';
import 'package:cow_pregnancy/screens/cow_detail_screen.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';
import 'package:cow_pregnancy/widgets/cow_id_badge.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCows = ref.watch(cowProvider);
    final smartAlerts = ref.watch(alertsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final birthStats = ref.watch(birthStatsProvider);

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
    int breedingLate = 0; 
    int breedingEmpty = 0; 

    List<Cow> listReady = [];
    List<Cow> listMonitoring = [];
    List<Cow> listPregnant = [];
    List<Cow> listLate = [];
    List<Cow> listEmpty = [];

    // Production Stages
    int prodMilking = 0; 
    int prodDrying = 0; 
    int prodHeifer = 0; 

    List<Cow> listMilking = [];
    List<Cow> listDrying = [];
    List<Cow> listHeifer = [];
    
    final int pregnancyDays = AppSettings.pregnancyDays;
    final int recoveryDays = AppSettings.recoveryDays;
    final int lateInsemDays = AppSettings.lateInseminationDays;
    final int dryingDays = AppSettings.dryingDays;

    for (var cow in cows) {
      // Use model's built-in logic
      bool hasBirthHistory = cow.hasGivenBirth || cow.isPostBirth;
      
      final int monitoringDays = AppSettings.monitoringDays;

      // --- حالات التكاثر ---
      if (cow.isInseminated && !cow.isPostBirth) {
        if (cow.daysSinceInsemination <= monitoringDays) {
          breedingMonitoring++;
          listMonitoring.add(cow);
        } else {
          breedingPregnant++;
          listPregnant.add(cow);
        }
      } else if (cow.isPostBirth) {
        if (cow.daysSinceBirth > lateInsemDays) {
          breedingLate++;
          listLate.add(cow);
        } else if (cow.daysSinceBirth >= recoveryDays) {
          breedingReady++;
          listReady.add(cow);
        } else {
          breedingEmpty++;
          listEmpty.add(cow);
        }
      } else {
        if (!hasBirthHistory) {
          breedingReady++;
          listReady.add(cow);
        } else {
          breedingEmpty++;
          listEmpty.add(cow);
        }
      }

      // --- مراحل الإنتاج ---
      if (cow.isHeifer) {
        prodHeifer++;
        listHeifer.add(cow);
      } else if (cow.isInseminated && (pregnancyDays - cow.daysSinceInsemination) <= dryingDays) {
        prodDrying++;
        listDrying.add(cow);
      } else {
        prodMilking++;
        listMilking.add(cow);
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                 color: Colors.blue.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                 children: [
                   const Text('إجمالي القطيع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                   const SizedBox(height: 5),
                   Text('$totalCows بقرة', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.blue)),
                   
                   const Padding(
                     padding: EdgeInsets.symmetric(vertical: 12),
                     child: Divider(height: 1, thickness: 1, color: Color(0x332196F3)),
                   ),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceAround,
                     children: [
                       _buildMiniStat('عجول ذكور', birthStats['male'] ?? 0, Colors.blue),
                       _buildMiniStat('عجلات إناث', birthStats['female'] ?? 0, Colors.pink),
                     ],
                   ),
                 ]
              )
            ),
            const SizedBox(height: 30),
            
            const Text(
              'حالات التكاثر',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            _buildStatusGrid(context, [
              _StatusItemData('جاهزة للتلقيح', breedingReady, Colors.green, '🟢', listReady, _TimeInfoType.daysSinceBirth),
              _StatusItemData('تحت الفحص', breedingMonitoring, Colors.amber, '🟡', listMonitoring, _TimeInfoType.daysSinceInsemination),
              _StatusItemData('حوامل', breedingPregnant, Colors.blue, '🔵', listPregnant, _TimeInfoType.monthsDaysSinceInsemination),
              _StatusItemData('تأخر بالتلقيح', breedingLate, Colors.red, '🔴', listLate, _TimeInfoType.daysSinceBirth),
              _StatusItemData('حديثة الولادة', breedingEmpty, Colors.grey, '⚪', listEmpty, _TimeInfoType.daysSinceBirth),
            ]),
            
            const SizedBox(height: 30),
            
            const Text(
              'مراحل الإنتاج',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            _buildStatusGrid(context, [
              _StatusItemData('حلوب', prodMilking, Colors.blueAccent, '🥛', listMilking, _TimeInfoType.daysSinceBirth),
              _StatusItemData('فترة التجفيف', prodDrying, Colors.indigo, '💤', listDrying, _TimeInfoType.daysRemainingUntilBirth),
              _StatusItemData('بكيرة', prodHeifer, Colors.orange, '🐄', listHeifer, _TimeInfoType.none),
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
            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildSmartAlertCard(BuildContext context, SmartAlert alert, List<Cow> cows) {
    Color cardColor;
    IconData icon;
    
    switch (alert.type) {
      case AlertType.birth:
        cardColor = Colors.orange;
        icon = Icons.child_friendly;
        break;
      case AlertType.heat:
        cardColor = Colors.amber;
        icon = Icons.favorite_border;
        break;
      case AlertType.lateInsemination:
        cardColor = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertType.drying:
        cardColor = Colors.blue;
        icon = Icons.opacity_outlined;
        break;
      case AlertType.calfVaccine:
        cardColor = Colors.teal;
        icon = Icons.vaccines;
        break;
      case AlertType.recovery:
        cardColor = Colors.green;
        icon = Icons.health_and_safety;
        break;
    }

    final cowColor = Color(alert.cowColorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: cardColor.withValues(alpha: 0.25),
          highlightColor: cardColor.withValues(alpha: 0.15),
          onTap: () {
            try {
              final cow = cows.firstWhere((c) => c.uniqueKey == alert.relatedCowKey);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CowDetailScreen(cow: cow),
              ));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('البقرة غير موجودة!')),
              );
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CowIdBadge(
                            id: alert.cowId,
                            color: cowColor,
                            fontSize: 14,
                            boxSize: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.description.replaceAll('البقرة رقم', '').replaceAll('البقرة', '').replaceAll('#${alert.cowId}', '').trim(),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.arrow_forward_ios, size: 12, color: cardColor),
                          const SizedBox(width: 4),
                          Text('اضغط لاتخاذ إجراء', style: TextStyle(fontSize: 12, color: cardColor, fontWeight: FontWeight.bold)),
                        ],
                      )
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

  Widget _buildMiniStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  void _showCowsListDialog(BuildContext context, String title, List<Cow> cows, Color themeColor, [_TimeInfoType timeInfoType = _TimeInfoType.none]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: cows.isEmpty 
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('لا يوجد أبقار في هذه القائمة', textAlign: TextAlign.center),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: cows.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cow = cows[index];
                  final timeParts = _buildTimeParts(cow, timeInfoType);
                  final String timeTitle = timeParts.$1;
                  final String timeValue = timeParts.$2;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CowDetailScreen(cow: cow),
                      ));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          // الجانب الأيسر: العنوان والقيمة
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timeTitle.isNotEmpty ? timeTitle : 'لا توجد بيانات',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: themeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (timeValue.isNotEmpty) ...[  
                                  const SizedBox(height: 3),
                                  Text(
                                    timeValue,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // الجانب الأيمن: شارة الرقم واللون + سهم
                          CowIdBadge(
                            id: cow.id,
                            color: cow.color,
                            fontSize: 14,
                            boxSize: 15,
                          ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // إرجاع (التسمية، القيمة) كزوج منفصل
  (String, String) _buildTimeParts(Cow cow, _TimeInfoType type) {
    switch (type) {
      case _TimeInfoType.daysSinceBirth:
        int days = 0;
        if (cow.birthDate != null) {
          days = DateTime.now().difference(cow.birthDate!).inDays;
        } else if (cow.isPostBirth) {
          days = cow.daysSinceBirth;
        } else {
          return ('', '');
        }
        return ('منذ الولادة', '$days يوم');

      case _TimeInfoType.daysSinceInsemination:
        if (!cow.isInseminated) return ('', '');
        final days = cow.daysSinceInsemination;
        return ('منذ التلقيح', '$days يوم');

      case _TimeInfoType.monthsDaysSinceInsemination:
        if (!cow.isInseminated) return ('', '');
        final days = cow.daysSinceInsemination;
        final months = days ~/ 30;
        final remaining = days % 30;
        if (months > 0) {
          return ('منذ التلقيح', '$months شهر و$remaining يوم');
        }
        return ('منذ التلقيح', '$days يوم');

      case _TimeInfoType.daysRemainingUntilBirth:
        if (!cow.isInseminated) return ('', '');
        final daysSinceInsemination = cow.daysSinceInsemination;
        final daysRemaining = 280 - daysSinceInsemination;
        if (daysRemaining < 0) {
          return ('متأخرة عن الولادة', '${-daysRemaining} يوم');
        }
        return ('باقي للولادة', '$daysRemaining يوم');

      case _TimeInfoType.none:
        return ('', '');
    }
  }

  Widget _buildStatusGrid(BuildContext context, List<_StatusItemData> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) {
        final isFiveItems = items.length == 5;
        final isThreeItems = items.length == 3;
        final isLastItem = item == items.last;
        double width = (MediaQuery.of(context).size.width - 40 - 12) / 2;
        if ((isFiveItems || isThreeItems) && isLastItem) {
          width = MediaQuery.of(context).size.width - 40;
        }

        return InkWell(
          onTap: () => _showCowsListDialog(context, item.title, item.cows, item.color, item.timeInfoType),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: item.color.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: item.color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text(
                    item.count.toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: item.color,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }).toList(),
  );
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
  daysSinceInsemination,
  monthsDaysSinceInsemination,
  daysRemainingUntilBirth,
}
