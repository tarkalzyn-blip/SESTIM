import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/providers/alerts_provider.dart';
import 'package:cow_pregnancy/widgets/stat_card.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';
import 'package:cow_pregnancy/screens/cow_detail_screen.dart';
import 'package:cow_pregnancy/services/notification_service.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cows = ref.watch(cowProvider);
    final smartAlerts = ref.watch(alertsProvider);

    // Schedule daily morning notification whenever alerts change
    final urgentCount = smartAlerts.where((a) => a.severity == AlertSeverity.high).length;
    NotificationService().scheduleDailyMorningSummary(urgentCount, smartAlerts.length);
    final int totalCows = cows.length;
    final int pregnantCount = cows.where((c) => c.isInseminated && !c.isPostBirth && c.daysSinceInsemination > 60).length;
    final int postBirthCount = cows.where((c) => c.isPostBirth).length;
    
    // Calf counting logic
    int totalCalves = 0;
    int maleCalves = 0;
    int femaleCalves = 0;
    
    for (var cow in cows) {
      for (var event in cow.history) {
        final title = event['title']?.toString() ?? '';
        if (title == 'تسجيل ولادة' || title == 'تسجيل ولادة سابقة') {
          totalCalves++;
          String note = event['note'] ?? '';
          if (note.contains('ذكر')) {
            maleCalves++;
          } else if (note.contains('أنثى')) {
            femaleCalves++;
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('اللوحة الذكية', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظرة عامة',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(title: 'إجمالي القطيع', count: totalCows, color: Colors.blue, delayMs: 0),
                StatCard(title: 'حوامل', count: pregnantCount, color: Colors.green, delayMs: 100),
                StatCard(title: 'بعد الولادة', count: postBirthCount, color: Colors.teal, delayMs: 200),
              ],
            ),
            
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
              ...smartAlerts.map((alert) => _buildSmartAlertCard(context, alert, cows)),
              
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
                  _buildCalfStatRow('إجمالي العجول', totalCalves, Icons.auto_awesome, Colors.amber),
                  const Divider(height: 30),
                  Row(
                    children: [
                      Expanded(child: _buildGenderStat('عجول (ذكر)', maleCalves, Colors.blue.shade300, Icons.male)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildGenderStat('عجلات (أنثى)', femaleCalves, Colors.pink.shade300, Icons.female)),
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
        cardColor = Colors.pink;
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

    if (alert.severity == AlertSeverity.high) cardColor = Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Find cow and navigate
            try {
              final cow = cows.firstWhere((c) => c.uniqueKey == alert.relatedCowKey);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CowDetailScreen(cow: cow),
              ));
            } catch (e) {
              // Cow not found, maybe deleted
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('البقرة غير موجودة!')),
              );
            }
          },
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
                              alert.title,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cardColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (alert.severity == AlertSeverity.high)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                              child: const Text('عاجل', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.description,
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
}
