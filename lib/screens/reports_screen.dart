import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/providers/alerts_provider.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cows = ref.watch(cowProvider);
    final alerts = ref.watch(alertsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── Stats Calculation ──────────────────────────────────────────
    final totalCows = cows.length;
    final inseminatedNotBirth = cows.where((c) => c.isInseminated && !c.isPostBirth).length;
    final pregnantConfirmed = cows.where((c) => c.isInseminated && !c.isPostBirth && c.daysSinceInsemination > 60).length;
    final postBirth = cows.where((c) => c.isPostBirth).length;
    final notInseminated = cows.where((c) => !c.isInseminated && !c.isPostBirth).length;

    int totalCalves = 0, maleCalves = 0, femaleCalves = 0;
    int exitedSold = 0, exitedDead = 0, exitedTransfer = 0, exitedDeleted = 0;
    int birthsThisMonth = 0, birthsThisYear = 0;
    final now = DateTime.now();

    for (var cow in cows) {
      for (var event in cow.history) {
        final title = event['title']?.toString() ?? '';
        if (title == 'تسجيل ولادة' || title == 'تسجيل ولادة سابقة') {
          totalCalves++;
          final note = event['note']?.toString() ?? '';
          if (note.contains('ذكر')) {
            maleCalves++;
          } else if (note.contains('أنثى')) {
            femaleCalves++;
          }

          try {
            final d = DateTime.parse(event['date'].toString());
            if (d.year == now.year && d.month == now.month) birthsThisMonth++;
            if (d.year == now.year) birthsThisYear++;
          } catch (_) {}

          if (event['isExited'] == true) {
            final reason = event['exitReason']?.toString() ?? '';
            if (reason == 'بيع') {
              exitedSold++;
            } else if (reason == 'وفاة') {
              exitedDead++;
            } else if (reason == 'نقل') {
              exitedTransfer++;
            } else {
              exitedDeleted++;
            }
          }
        }
      }
    }
    final activeCalves = totalCalves - (exitedSold + exitedDead + exitedTransfer + exitedDeleted);
    final highAlerts = alerts.where((a) => a.severity == AlertSeverity.high).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 التقارير والإحصائيات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Herd Overview ──────────────────────────────────────
            _sectionTitle('🐄 نظرة عامة على القطيع'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _statTile('إجمالي البقر', totalCows, Icons.group, Colors.blue, isDark),
                _statTile('حوامل مؤكد', pregnantConfirmed, Icons.pregnant_woman, Colors.green, isDark),
                _statTile('بعد الولادة', postBirth, Icons.child_friendly, Colors.teal, isDark),
                _statTile('غير ملقحة', notInseminated, Icons.block, Colors.orange, isDark),
              ],
            ),

            const SizedBox(height: 24),

            // ── Alert Summary ──────────────────────────────────────
            _sectionTitle('🔔 ملخص التنبيهات'),
            const SizedBox(height: 12),
            _alertSummaryCard(alerts.length, highAlerts, isDark),

            const SizedBox(height: 24),

            // ── Calves Report ──────────────────────────────────────
            _sectionTitle('🐮 تقرير العجول'),
            const SizedBox(height: 12),
            _calvesSummaryCard(
              total: totalCalves,
              active: activeCalves,
              male: maleCalves,
              female: femaleCalves,
              birthsMonth: birthsThisMonth,
              birthsYear: birthsThisYear,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // ── Exits Breakdown ────────────────────────────────────
            if (totalCalves > 0 && (exitedSold + exitedDead + exitedTransfer + exitedDeleted) > 0) ...[
              _sectionTitle('📤 مصير العجول المستبعدة'),
              const SizedBox(height: 12),
              _exitBreakdownCard(
                sold: exitedSold,
                dead: exitedDead,
                transferred: exitedTransfer,
                deleted: exitedDeleted,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
            ],

            // ── Pregnancy Success ──────────────────────────────────
            _sectionTitle('💉 معدل الحمل'),
            const SizedBox(height: 12),
            _pregnancyRateCard(
              inseminated: inseminatedNotBirth,
              confirmed: pregnantConfirmed,
              total: totalCows,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );

  Widget _statTile(String label, int value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _alertSummaryCard(int total, int high, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: total == 0
          ? const Row(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 36),
              SizedBox(width: 12),
              Text('لا توجد تنبيهات نشطة 🎉', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
            ])
          : Row(
              children: [
                _alertBadge('إجمالي التنبيهات', total, Colors.orange),
                const SizedBox(width: 20),
                _alertBadge('عاجلة', high, Colors.red),
              ],
            ),
    );
  }

  Widget _alertBadge(String label, int count, Color color) => Expanded(
    child: Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _calvesSummaryCard({
    required int total, required int active, required int male, required int female,
    required int birthsMonth, required int birthsYear, required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _calveStatCol('الإجمالي', total, Colors.amber),
              _calveStatCol('نشط', active, Colors.green),
              _calveStatCol('ذكور', male, Colors.blue),
              _calveStatCol('إناث', female, Colors.pink),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text('ولادات هذا الشهر: ', style: const TextStyle(color: Colors.blueGrey)),
              Text('$birthsMonth', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 20),
              const Icon(Icons.calendar_month, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text('ولادات هذا العام: ', style: const TextStyle(color: Colors.blueGrey)),
              Text('$birthsYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          )
        ],
      ),
    );
  }

  Widget _calveStatCol(String label, int val, Color color) => Expanded(
    child: Column(
      children: [
        Text('$val', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ],
    ),
  );

  Widget _exitBreakdownCard({required int sold, required int dead, required int transferred, required int deleted, required bool isDark}) {
    final total = sold + dead + transferred + deleted;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _exitRow('💰 مباعة', sold, total, Colors.green),
          const SizedBox(height: 10),
          _exitRow('☠️ وفاة', dead, total, Colors.red),
          const SizedBox(height: 10),
          _exitRow('🔄 منقولة', transferred, total, Colors.blue),
          if (deleted > 0) ...[
            const SizedBox(height: 10),
            _exitRow('🗑️ محذوفة', deleted, total, Colors.grey),
          ],
        ],
      ),
    );
  }

  Widget _exitRow(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$count (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _pregnancyRateCard({required int inseminated, required int confirmed, required int total, required bool isDark}) {
    final rate = total == 0 ? 0.0 : confirmed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('حوامل مؤكد من إجمالي القطيع', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${(rate * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: Colors.green.withValues(alpha: 0.15),
              color: Colors.green,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip('ملقحة', inseminated, Colors.teal),
              const SizedBox(width: 10),
              _infoChip('حمل مؤكد', confirmed, Colors.green),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoChip(String label, int val, Color color) => Chip(
    label: Text('$label: $val', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    backgroundColor: color.withValues(alpha: 0.1),
    side: BorderSide(color: color.withValues(alpha: 0.3)),
  );
}
