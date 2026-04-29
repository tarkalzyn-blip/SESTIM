import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cow_pregnancy/utils/date_picker_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _reportType = 0; // 0: Actual, 1: Expected
  final ScreenshotController _screenshotController = ScreenshotController();
  
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;
  
  late int _yearStart;
  late int _yearRange;


  // Audio for wheels
  static const int _poolSize = 6;
  late List<AudioPlayer> _pool;
  int _poolIdx = 0;
  bool _audioReady = false;

  static const List<String> _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    
    final today = DateTime.now();
    _yearRange = 100;
    _yearStart = today.year - 50;

    _monthController = FixedExtentScrollController(
      initialItem: 37200 + (_selectedMonth - 1),
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _yearStart,
    );
    
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final soundFile = AppSettings.datePickerSound;
      _pool = List.generate(_poolSize, (_) => AudioPlayer());
      for (final p in _pool) {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(1.0);
        await p.setSource(AssetSource('sounds/$soundFile'));
      }
      _audioReady = true;
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    if (_audioReady) {
      for (final p in _pool) p.dispose();
    }
    super.dispose();
  }

  void _triggerFeedback() {
    HapticFeedback.selectionClick();
    if (_audioReady) {
      final player = _pool[_poolIdx];
      _poolIdx = (_poolIdx + 1) % _poolSize;
      player.stop().then((_) {
        player.play(AssetSource('sounds/${AppSettings.datePickerSound}'), mode: PlayerMode.lowLatency).catchError((_) {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cows = ref.watch(cowProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── Stats Calculation ──────────────────────────────────────────
    final totalCows = cows.length;
    final pregnantConfirmed = cows.where((c) => c.isInseminated && !c.isPostBirth && c.daysSinceInsemination > 25).length;
    final postBirth = cows.where((c) => c.isPostBirth).length;
    final notInseminated = cows.where((c) => !c.isInseminated && !c.isPostBirth).length;
    final inseminatedNotBirth = cows.where((c) => c.isInseminated && !c.isPostBirth).length;

    int totalCalves = 0, maleCalves = 0, femaleCalves = 0;
    int exitedSold = 0, exitedDead = 0, exitedTransfer = 0, exitedDeleted = 0;
    int birthsInMonth = 0, birthsInYear = 0;
    final Map<int, int> monthlyBirths = {for (var i = 1; i <= 12; i++) i: 0};
    final List<Map<String, dynamic>> monthBirthDetails = [];

    // Use optimized providers
    final stats = ref.watch(birthStatsProvider);
    final allCalves = ref.watch(allCalvesProvider);

    totalCalves = stats['total'];
    maleCalves = stats['male'];
    femaleCalves = stats['female'];
    exitedSold = stats['sold'];
    exitedDead = stats['dead'];
    exitedTransfer = stats['transfer'];
    exitedDeleted = stats['deleted'];

    // Specific filtering for the selected month/year (much faster now)
    for (var calf in allCalves) {
      DateTime? birthDate = _flexibleDateParse(calf['date']);
      if (birthDate == null) continue;

      if (birthDate.year == _selectedYear) {
        monthlyBirths[birthDate.month] = (monthlyBirths[birthDate.month] ?? 0) + 1;
      }
    }

    if (_reportType == 0) {
      // Actual Births
      for (var calf in allCalves) {
        DateTime? birthDate = _flexibleDateParse(calf['date']);
        if (birthDate == null) continue;

        if (birthDate.year == _selectedYear) {
          birthsInYear++;
          if (birthDate.month == _selectedMonth) {
            birthsInMonth++;
            monthBirthDetails.add({
              'cowId': calf['motherId'],
              'date': birthDate,
              'calfId': (calf['calfId'] ?? '').toString(),
              'isMale': calf['note'].toString().contains('ذكر') || (calf['calfColorValue'] == 0xFF2196F3),
            });
          }
        }
      }
    } else {
      // Expected Births
      for (var cow in cows) {
        if (cow.isInseminated && !cow.isPostBirth) {
          final expectedDate = cow.inseminationDate.add(const Duration(days: 280));
          if (expectedDate.year == _selectedYear) {
            birthsInYear++;
            if (expectedDate.month == _selectedMonth) {
              birthsInMonth++;
              monthBirthDetails.add({
                'cowId': cow.id,
                'date': expectedDate,
                'isExpected': true,
                'uniqueKey': cow.uniqueKey,
                'color': cow.color,
              });
            }
          }
        }
      }
    }

    final activeCalves = totalCalves - (exitedSold + exitedDead + exitedTransfer + exitedDeleted);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 التقارير والإحصائيات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _captureAndShareReport),
        ],
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── فلتر التاريخ (مباشر) ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text('تصفية التقارير',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(child: Center(child: Text('اختر الشهر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)))),
                            Expanded(child: Center(child: Text('اختر السنة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140, // Reduced height for inline display
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Highlight band
                            Container(
                              height: 45,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            // Fade effect
                            ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black,
                                    Colors.black,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.35, 0.65, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    // Month Wheel
                                    Expanded(
                                      child: ListWheelScrollView.useDelegate(
                                        controller: _monthController,
                                        itemExtent: 45,
                                        physics: const MediumSpeedScrollPhysics(),
                                        diameterRatio: 1.5,
                                        squeeze: 1.25,
                                        useMagnifier: false,
                                        clipBehavior: Clip.none,
                                        onSelectedItemChanged: (idx) {
                                          setState(() => _selectedMonth = (idx % 12) + 1);
                                          _triggerFeedback();
                                        },
                                        childDelegate: ListWheelChildBuilderDelegate(
                                          builder: (context, i) {
                                            final month = (i % 12) + 1;
                                            final isSelected = month == _selectedMonth;
                                            final color = isDark ? (isSelected ? const Color(0xFF0A84FF) : Colors.white60) 
                                                                 : (isSelected ? const Color(0xFF007AFF) : Colors.black54);
                                            return Center(
                                              child: Text(
                                                month.toString().padLeft(2, '0'),
                                                style: TextStyle(
                                                  fontSize: isSelected ? 22 : 18,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  color: color,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    // Year Wheel
                                    Expanded(
                                      child: ListWheelScrollView.useDelegate(
                                        controller: _yearController,
                                        itemExtent: 45,
                                        physics: const MediumSpeedScrollPhysics(),
                                        diameterRatio: 1.5,
                                        squeeze: 1.25,
                                        useMagnifier: false,
                                        clipBehavior: Clip.none,
                                        onSelectedItemChanged: (idx) {
                                          setState(() => _selectedYear = _yearStart + idx);
                                          _triggerFeedback();
                                        },
                                        childDelegate: ListWheelChildBuilderDelegate(
                                          childCount: _yearRange + 1,
                                          builder: (context, i) {
                                            final year = _yearStart + i;
                                            final isSelected = year == _selectedYear;
                                            final color = isDark ? (isSelected ? const Color(0xFF0A84FF) : Colors.white60) 
                                                                 : (isSelected ? const Color(0xFF007AFF) : Colors.black54);
                                            return Center(
                                              child: Text(
                                                year.toString(),
                                                style: TextStyle(
                                                  fontSize: isSelected ? 22 : 18,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  color: color,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── نوع العرض (فعلية / متوقعة) ───────────────────────────
                Center(
                  child: Column(
                    children: [
                      Text('نوع العرض', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildToggleBtn(0, 'الولادات الفعلية', Icons.bar_chart, Colors.blue),
                            const SizedBox(width: 4),
                            _buildToggleBtn(1, 'الولادات المتوقعة', Icons.trending_up, Colors.teal),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Calves Report (Requested first) ────────────────────
                _sectionTitle('🐮 تقرير العجول'),
                const SizedBox(height: 12),
                _calvesSummaryCard(
                  total: totalCalves,
                  active: activeCalves,
                  male: maleCalves,
                  female: femaleCalves,
                  birthsMonth: birthsInMonth,
                  birthsYear: birthsInYear,
                  isDark: isDark,
                  selectedMonth: _selectedMonth,
                  selectedYear: _selectedYear,
                ),

                const SizedBox(height: 24),

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

                if (totalCalves > 0 && (exitedSold + exitedDead + exitedTransfer + exitedDeleted) > 0) ...[
                  _sectionTitle('📤 مصير العجول المستبعدة'),
                  const SizedBox(height: 12),
                  _exitBreakdownCard(sold: exitedSold, dead: exitedDead, transferred: exitedTransfer, deleted: exitedDeleted, isDark: isDark),
                  const SizedBox(height: 24),
                ],

                _sectionTitle('💉 معدل الحمل'),
                const SizedBox(height: 12),
                _pregnancyRateCard(inseminated: inseminatedNotBirth, confirmed: pregnantConfirmed, total: totalCows, isDark: isDark),

                const SizedBox(height: 32),

                if (_reportType == 0) ...[
                  _sectionTitle('📈 الرسوم البيانية المتقدمة'),
                  const SizedBox(height: 16),
                  _buildBirthsChart(monthlyBirths, isDark, _selectedYear),
                  const SizedBox(height: 24),
                  _buildGenderDistributionChart(maleCalves, femaleCalves, isDark),
                  const SizedBox(height: 32),
                ],

                _sectionTitle(_reportType == 0 ? '📋 تفاصيل ولادات شهر $_selectedMonth / $_selectedYear' : '📋 توقعات ولادات شهر $_selectedMonth / $_selectedYear'),
                const SizedBox(height: 12),
                if (monthBirthDetails.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(_reportType == 0 ? 'لا توجد ولادات مسجلة في هذا الشهر.' : 'لا توجد ولادات متوقعة في هذا الشهر.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: monthBirthDetails.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final b = monthBirthDetails[i];
                      final bDate = b['date'] as DateTime;
                      
                      if (_reportType == 0) {
                        final isMale = b['isMale'] as bool;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: (isMale ? Colors.blue : Colors.pink).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 45, height: 45,
                                decoration: BoxDecoration(color: (isMale ? Colors.blue : Colors.pink).withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(isMale ? Icons.male : Icons.female, color: isMale ? Colors.blue : Colors.pink),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('رقم الأم: ${b['cowId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('التاريخ: ${bDate.day}/${bDate.month}/${bDate.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              if (b['calfId'].toString().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text('عجل: ${b['calfId']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                            ],
                          ),
                        );
                      } else {
                        final color = b['color'] as Color;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 45, height: 45,
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                                child: Icon(Icons.auto_awesome, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('رقم البقرة: ${b['cowId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('الموعد المتوقع: ${bDate.day}/${bDate.month}/${bDate.year}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Text('متوقع', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndShareReport() async {
    try {
      final image = await _screenshotController.capture(delay: const Duration(milliseconds: 500));
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.png').create();
        await imagePath.writeAsBytes(image);
        await Share.shareXFiles([XFile(imagePath.path)], text: 'تقرير إحصائيات القطيع لعام $_selectedYear');
      }
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  Widget _buildBirthsChart(Map<int, int> monthlyBirths, bool isDark, int selectedYear) {
    final maxBirths = monthlyBirths.values.isEmpty ? 0 : monthlyBirths.values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxBirths + 1).toDouble();

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('توزع الولادات في عام $selectedYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (v) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey))))),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: monthlyBirths.entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.toDouble(), color: Colors.blue, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))] )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderDistributionChart(int male, int female, bool isDark) {
    final total = male + female;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4, centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(color: Colors.blue, value: male.toDouble(), title: '${((male / total) * 100).toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: Colors.pink, value: female.toDouble(), title: '${((female / total) * 100).toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('توزيع الجنس', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _legendItem('ذكور', male, Colors.blue),
                const SizedBox(height: 8),
                _legendItem('إناث', female, Colors.pink),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, int count, Color color) => Row(
    children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text('$count عجل', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
    ],
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );

  Widget _statTile(String label, int value, IconData icon, Color color, bool isDark) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ],
          ),
        )
      ],
    ),
  );

  Widget _calvesSummaryCard({required int total, required int active, required int male, required int female, required int birthsMonth, required int birthsYear, required bool isDark, required int selectedMonth, required int selectedYear}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
    child: Column(
      children: [
        Row(children: [_calveStatCol('الإجمالي', total, Colors.amber), _calveStatCol('نشط', active, Colors.green), _calveStatCol('ذكور', male, Colors.blue), _calveStatCol('إناث', female, Colors.pink)]),
        const Divider(height: 30),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: (_reportType == 0 ? Colors.blue : Colors.teal).withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.circular(15), 
                  border: Border.all(color: (_reportType == 0 ? Colors.blue : Colors.teal).withValues(alpha: 0.2))
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: _reportType == 0 ? Colors.blue : Colors.teal), 
                        const SizedBox(width: 4), 
                        Text(_reportType == 0 ? 'ولادات شهر $selectedMonth' : 'توقعات شهر $selectedMonth', style: const TextStyle(fontSize: 12, color: Colors.blueGrey))
                      ]
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
                      decoration: BoxDecoration(color: _reportType == 0 ? Colors.blue : Colors.teal, borderRadius: BorderRadius.circular(10)), 
                      child: Text('$birthsMonth', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white))
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: (_reportType == 0 ? Colors.deepPurple : Colors.indigo).withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.circular(15), 
                  border: Border.all(color: (_reportType == 0 ? Colors.deepPurple : Colors.indigo).withValues(alpha: 0.2))
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(Icons.calendar_month, size: 14, color: _reportType == 0 ? Colors.deepPurple : Colors.indigo), 
                        const SizedBox(width: 4), 
                        Text(_reportType == 0 ? 'ولادات عام $selectedYear' : 'توقعات عام $selectedYear', style: const TextStyle(fontSize: 12, color: Colors.blueGrey))
                      ]
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
                      decoration: BoxDecoration(color: _reportType == 0 ? Colors.deepPurple : Colors.indigo, borderRadius: BorderRadius.circular(10)), 
                      child: Text('$birthsYear', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white))
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      ],
    ),
  );

  Widget _buildToggleBtn(int type, String label, IconData icon, Color color) {
    final isSelected = _reportType == type;
    return GestureDetector(
      onTap: () => setState(() => _reportType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calveStatCol(String label, int val, Color color) => Expanded(child: Column(children: [Text('$val', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey))]));

  Widget _exitBreakdownCard({required int sold, required int dead, required int transferred, required int deleted, required bool isDark}) {
    final total = sold + dead + transferred + deleted;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
      child: Column(
        children: [
          _exitRow('💰 مباعة', sold, total, Colors.green), const SizedBox(height: 10),
          _exitRow('☠️ وفاة', dead, total, Colors.red), const SizedBox(height: 10),
          _exitRow('🔄 منقولة', transferred, total, Colors.blue),
          if (deleted > 0) ...[const SizedBox(height: 10), _exitRow('🗑️ محذوفة', deleted, total, Colors.grey)],
        ],
      ),
    );
  }

  Widget _exitRow(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), Text('$count (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: pct, backgroundColor: color.withValues(alpha: 0.1), color: color, minHeight: 6)),
      ],
    );
  }

  Widget _pregnancyRateCard({required int inseminated, required int confirmed, required int total, required bool isDark}) {
    final rate = total == 0 ? 0.0 : confirmed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي نسبة الحمل في القطيع', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${(rate * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: rate, backgroundColor: Colors.green.withValues(alpha: 0.15), color: Colors.green, minHeight: 12)),
          const SizedBox(height: 12),
          Row(children: [_infoChip('ملقحة', inseminated, Colors.teal), const SizedBox(width: 10), _infoChip('حمل مؤكد', confirmed, Colors.green)]),
        ],
      ),
    );
  }

  Widget _infoChip(String label, int val, Color color) => Chip(label: Text('$label: $val', style: TextStyle(color: color, fontWeight: FontWeight.bold)), backgroundColor: color.withValues(alpha: 0.1), side: BorderSide(color: color.withValues(alpha: 0.3)));

  DateTime? _flexibleDateParse(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is DateTime) return rawDate;
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is Map) {
      if (rawDate.containsKey('_seconds')) return DateTime.fromMillisecondsSinceEpoch(rawDate['_seconds'] * 1000);
      if (rawDate.containsKey('seconds')) return DateTime.fromMillisecondsSinceEpoch(rawDate['seconds'] * 1000);
    }
    if (rawDate is String && rawDate.isNotEmpty) {
      DateTime? parsed = DateTime.tryParse(rawDate);
      if (parsed != null) return parsed;
      try {
        final parts = rawDate.split(RegExp(r'[/ \-]'));
        if (parts.length >= 3) {
          int? d, m, y;
          if (parts[0].length == 4) { y = int.tryParse(parts[0]); m = int.tryParse(parts[1]); d = int.tryParse(parts[2]); }
          else { d = int.tryParse(parts[0]); m = int.tryParse(parts[1]); y = int.tryParse(parts[2]); }
          if (y != null && m != null && d != null) return DateTime(y, m, d);
        }
      } catch (_) {}
    }
    return null;
  }
}
