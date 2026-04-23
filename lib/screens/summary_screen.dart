import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/widgets/stat_card.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cows = ref.watch(cowProvider);
    
    final int totalCows = cows.length;
    final int pregnantCount = cows.where((c) => c.isInseminated && !c.isPostBirth && c.daysSinceInsemination > 60).length;
    final int postBirthCount = cows.where((c) => c.isPostBirth).length;
    final int lateForInseminationCount = cows.where((c) => c.isPostBirth && c.daysSinceBirth >= AppSettings.recoveryDays).length;
    
    // Calf counting logic
    int totalCalves = 0;
    int maleCalves = 0;
    int femaleCalves = 0;
    
    for (var cow in cows) {
      for (var event in cow.history) {
        if (event['title'] == 'تسجيل ولادة') {
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

    // Alerts logic
    final List<Map<String, dynamic>> alerts = [];
    for (var cow in cows) {
      if (cow.isPostBirth) {
        if (cow.daysSinceBirth >= 60) {
          alerts.add({
            'type': 'late_insemination',
            'cow': cow,
            'message': 'البقرة #${cow.id} تمت الولادة قبل ${cow.daysSinceBirth} يوم ولم تُلقح بعد.',
            'color': Colors.red,
            'icon': Icons.warning_amber_rounded,
          });
        }
      } else if (cow.isInseminated) {
        int daysRemaining = AppSettings.pregnancyDays - cow.daysSinceInsemination;
        if (daysRemaining <= 10 && daysRemaining >= -5) {
          alerts.add({
            'type': 'near_birth',
            'cow': cow,
            'message': 'البقرة #${cow.id} قريبة من الولادة (بقي أقل من $daysRemaining أيام).',
            'color': Colors.orange,
            'icon': Icons.child_friendly,
          });
        } else if (cow.daysSinceInsemination >= 215 && cow.daysSinceInsemination <= 225) {
          alerts.add({
            'type': 'drying',
            'cow': cow,
            'message': 'البقرة #${cow.id} حان موعد التنشيف (اليوم ${cow.daysSinceInsemination}).',
            'color': Colors.blue,
            'icon': Icons.opacity_outlined,
          });
        }
      } else {
        // Not inseminated, check for heat
        if (cow.daysSinceInsemination >= AppSettings.heatCycleDays - 2) {
          alerts.add({
            'type': 'heat',
            'cow': cow,
            'message': 'البقرة #${cow.id} موعد شبق متوقع (اليوم ${cow.daysSinceInsemination}).',
            'color': Colors.pink,
            'icon': Icons.favorite_border,
          });
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold)),
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
              'نظرة عامة على المزرعة',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(title: 'إجمالي الأبقار', count: totalCows, color: Colors.blue, delayMs: 0),
                StatCard(title: 'حوامل', count: pregnantCount, color: Colors.green, delayMs: 100),
                StatCard(title: 'بعد الولادة', count: postBirthCount, color: Colors.teal, delayMs: 200),
                StatCard(title: 'تأخرت عن التلقيح', count: lateForInseminationCount, color: Colors.red, delayMs: 300),
              ],
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 30),
              const Text(
                'تنبيهات هامة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ...alerts.map((alert) => _buildAlertItem(context, alert)),
            ],
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
                      Expanded(child: _buildGenderStat('عجولات (أنثى)', femaleCalves, Colors.pink.shade300, Icons.female)),
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

  Widget _buildAlertItem(BuildContext context, Map<String, dynamic> alert) {
    final Cow cow = alert['cow'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alert['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: alert['color'].withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(alert['icon'], color: alert['color'], size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: cow.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert['message'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
