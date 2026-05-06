import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
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
  int _selectedTab = 0; // 0: Births, 1: Milk, 2: Stats
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _reportType = 0; // 0: Actual, 1: Expected
  int _categoryFilter = 0; // 0: All, 1: Mature Cows, 2: Heifers
  int _selectedWeek = 0; // 0: All, 1, 2, 3, 4
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
    // ── تصفية المجموعات ──────────────────────────────────────────
    final allCows = ref.watch(cowProvider);
    final cows = allCows.where((c) {
      if (_categoryFilter == 0) return true;
      if (_categoryFilter == 1) return c.isManualCow == true; // أبقار بالغة
      if (_categoryFilter == 2) return c.isManualCow == false; // بكاكير
      return true;
    }).toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── تاريخ الحساب المستهدف (نهاية الشهر المختار والشهر السابق) ──────────
    // ── تاريخ الحساب المستهدف (نهاية الفترة المختارة والفترة السابقة) ──────────
    // ── تحديد نطاق الفترة المختارة ──────────────────────────────────────
    DateTime periodStart;
    DateTime periodEnd;
    if (_selectedWeek == 0) {
      periodStart = DateTime(_selectedYear, _selectedMonth, 1);
      periodEnd = DateTime(_selectedYear, _selectedMonth + 1, 0);
    } else {
      final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
      int startDay = (_selectedWeek - 1) * 7 + 1;
      int endDay = _selectedWeek * 7;
      if (endDay > lastDayOfMonth) endDay = lastDayOfMonth;
      periodStart = DateTime(_selectedYear, _selectedMonth, startDay);
      periodEnd = DateTime(_selectedYear, _selectedMonth, endDay);
    }

    int totalMilkingDays = 0;
    int totalMilkingDaysPrev = 0;
    
    // تاريخ مرجعي للمقارنة (نهاية الفترة)
    final targetDate = periodEnd;
    final prevPeriodStart = periodStart.subtract(const Duration(days: 30));
    final prevPeriodEnd = periodEnd.subtract(const Duration(days: 30));
    final prevTargetDate = prevPeriodEnd;

    // ── حساب إحصائيات الحليب في التاريخ المختار ────────────────────────
    int milkingCows = 0;
    int excellentMilkingCows = 0;
    int dryingOffCows = 0;
    int dryCows = 0;
    
    // إحصائيات الشهر السابق للمقارنة
    int milkingCowsPrev = 0;
    
    for (var cow in cows) {
      // 1. تحديد أيام الحليب في الفترة الحالية
      totalMilkingDays += _calculateMilkingDaysInPeriod(cow, periodStart, periodEnd);
      
      // 2. تحديد أيام الحليب في نفس الفترة من الشهر السابق
      totalMilkingDaysPrev += _calculateMilkingDaysInPeriod(cow, prevPeriodStart, prevPeriodEnd);

      // 3. تحديث العدادات للكرت (الحالة في نهاية الفترة - لقطة ثابتة)
      final daysSinceInsemAtDate = targetDate.difference(cow.inseminationDate).inDays;
      final daysRemaining = AppSettings.pregnancyDays - daysSinceInsemAtDate;
      
      bool isHeiferAtDate = cow.isHeifer;
      final effectiveBirth = cow.effectiveBirthDate;
      if (effectiveBirth != null && effectiveBirth.isBefore(targetDate)) {
        isHeiferAtDate = false;
      }
      
      // منطق الولادة الافتراضية للبكاكير: إذا تجاوزت موعد الولادة في تاريخ التقرير تُحسب كـ "حلوب"
      if (isHeiferAtDate && cow.isInseminated && daysRemaining <= 0) {
        isHeiferAtDate = false;
      }

      if (isHeiferAtDate) {
        if (cow.isInseminated && daysRemaining <= 70 && daysRemaining > 0) {
          dryingOffCows++; // بكيرة قريبة
        } else {
          excellentMilkingCows++; // بكيرة
        }
      } else {
        if (cow.isInseminated && daysRemaining <= 70 && daysRemaining > 0) {
          dryCows++;
        } else {
          milkingCows++;
        }
      }

      // الحساب للشهر السابق (تبسيط للمقارنة)
      bool isHeiferPrev = cow.isHeifer;
      if (effectiveBirth != null && effectiveBirth.isBefore(prevTargetDate)) {
        isHeiferPrev = false;
      }

      if (!isHeiferPrev) {
        final daysSinceInsemPrev = prevTargetDate.difference(cow.inseminationDate).inDays;
        final daysRemPrev = AppSettings.pregnancyDays - daysSinceInsemPrev;
        if (!(cow.isInseminated && daysRemPrev <= 70 && daysRemPrev > 0)) {
          milkingCowsPrev++;
        }
      }
    }

    // ── إحصائيات القطيع العامة في التاريخ المختار ──────────────────────
    final totalCows = cows.length;
    final pregnantConfirmed = cows.where((c) {
      if (!c.isInseminated) return false;
      final expectedBirth = c.inseminationDate.add(Duration(days: AppSettings.pregnancyDays));
      return c.inseminationDate.isBefore(targetDate) && expectedBirth.isAfter(targetDate) && targetDate.difference(c.inseminationDate).inDays > 25;
    }).length;
    
    final postBirth = cows.where((c) => c.effectiveBirthDate != null && c.effectiveBirthDate!.isBefore(targetDate)).length;
    final inseminatedNotBirth = cows.where((c) => c.isInseminated && c.inseminationDate.isBefore(targetDate) && (c.effectiveBirthDate == null || c.effectiveBirthDate!.isAfter(targetDate))).length;
    final notInseminated = totalCows - inseminatedNotBirth - postBirth;

    // المقارنة للشهر السابق
    final pregnantConfirmedPrev = cows.where((c) {
      if (!c.isInseminated) return false;
      final expectedBirth = c.inseminationDate.add(Duration(days: AppSettings.pregnancyDays));
      return c.inseminationDate.isBefore(prevTargetDate) && expectedBirth.isAfter(prevTargetDate) && prevTargetDate.difference(c.inseminationDate).inDays > 25;
    }).length;

    int totalCalves = 0, maleCalves = 0, femaleCalves = 0;
    int exitedSold = 0, exitedDead = 0, exitedTransfer = 0, exitedDeleted = 0;
    int birthsInMonth = 0, birthsInYear = 0;
    int birthsInMonthPrev = 0;
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

    // Specific filtering for the selected month/year
    for (var calf in allCalves) {
      DateTime? birthDate = _flexibleDateParse(calf['date']);
      if (birthDate == null) continue;

      if (birthDate.year == _selectedYear) {
        monthlyBirths[birthDate.month] = (monthlyBirths[birthDate.month] ?? 0) + 1;
      }
      if (birthDate.year == _selectedYear && birthDate.month == _selectedMonth - 1) {
        birthsInMonthPrev++;
      }
      if (_selectedMonth == 1 && birthDate.year == _selectedYear - 1 && birthDate.month == 12) {
        birthsInMonthPrev++;
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
            final mother = cows.firstWhere((c) => c.id == calf['motherId'], orElse: () => Cow(id: '', inseminationDate: DateTime.now(), colorValue: 0));
            monthBirthDetails.add({
              'cowId': calf['motherId'],
              'date': birthDate,
              'calfId': (calf['calfId'] ?? '').toString(),
              'isMale': calf['note'].toString().contains('ذكر') || (calf['calfColorValue'] == 0xFF2196F3),
              'color': mother.color,
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

    // ── حساب الكفاءة التناسلية (Reproductive Efficiency) ──────────────────
    double totalDaysOpen = 0;
    int cowsWithDaysOpen = 0;
    double totalInseminations = 0;
    int cowsWithInseminations = 0;
    
    for (var cow in cows) {
      // الأيام المفتوحة: من آخر ولادة حتى التلقيح الحالي الناجح
      if (cow.isInseminated && cow.effectiveBirthDate != null && cow.inseminationDate.isAfter(cow.effectiveBirthDate!)) {
        totalDaysOpen += cow.inseminationDate.difference(cow.effectiveBirthDate!).inDays;
        cowsWithDaysOpen++;
      }
      
      // معدل التلقيحات: عدد المحاولات في السجل قبل التلقيح الحالي
      int insemCount = cow.history.where((e) => e['title']?.toString().contains('تلقيح') ?? false).length + 1;
      totalInseminations += insemCount;
      cowsWithInseminations++;
    }
    
    final avgDaysOpen = cowsWithDaysOpen > 0 ? totalDaysOpen / cowsWithDaysOpen : 0.0;
    final avgInseminations = cowsWithInseminations > 0 ? totalInseminations / cowsWithInseminations : 0.0;
    
    // حساب الإنتاج المتوقع بناءً على أيام الحليب الفعلية
    final double avgLitersPerDay = 25.0; 
    int expectedProductionLiters = (totalMilkingDays * avgLitersPerDay).round();
    int expectedProductionLitersPrev = (totalMilkingDaysPrev * avgLitersPerDay).round();

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
                // ── شريط التبويب (الخيارات) ──────────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildTabBtn(0, 'الولادات', Icons.child_care, Colors.blue),
                      _buildTabBtn(1, 'الحليب', Icons.opacity, Colors.orange),
                      _buildTabBtn(2, 'الإحصائيات', Icons.analytics, Colors.teal),
                    ],
                  ),
                ),

                // شريط اختيار الفئة
                _buildCategoryFilter(isDark),

                // ── فلتر التاريخ العالمي (عجلة الشهر والسنة) ──────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1), width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text('تقرير شهر $_selectedMonth / $_selectedYear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100, 
                        child: Row(
                          children: [
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _monthController,
                                itemExtent: 40,
                                physics: const MediumSpeedScrollPhysics(),
                                onSelectedItemChanged: (idx) {
                                  setState(() => _selectedMonth = (idx % 12) + 1);
                                  _triggerFeedback();
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  builder: (context, i) {
                                    final month = (i % 12) + 1;
                                    final isSelected = month == _selectedMonth;
                                    return Center(child: Text(month.toString().padLeft(2, '0'), style: TextStyle(fontSize: isSelected ? 20 : 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDark ? (isSelected ? Colors.blue : Colors.white60) : (isSelected ? Colors.blue : Colors.black54))));
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _yearController,
                                itemExtent: 40,
                                physics: const MediumSpeedScrollPhysics(),
                                onSelectedItemChanged: (idx) {
                                  setState(() => _selectedYear = _yearStart + idx);
                                  _triggerFeedback();
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: _yearRange + 1,
                                  builder: (context, i) {
                                    final year = _yearStart + i;
                                    final isSelected = year == _selectedYear;
                                    return Center(child: Text(year.toString(), style: TextStyle(fontSize: isSelected ? 20 : 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDark ? (isSelected ? Colors.blue : Colors.white60) : (isSelected ? Colors.blue : Colors.black54))));
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_selectedTab == 0) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Column(
                      children: [
                        Text('نوع العرض', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
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
                  _sectionTitle('🐮 تقرير العجول'),
                  const SizedBox(height: 12),
                  _calvesSummaryCard(
                    total: totalCalves, active: activeCalves, male: maleCalves, female: femaleCalves,
                    birthsMonth: birthsInMonth, birthsYear: birthsInYear, isDark: isDark,
                    selectedMonth: _selectedMonth, selectedYear: _selectedYear,
                    birthsMonthPrev: birthsInMonthPrev,
                  ),
                  const SizedBox(height: 32),
                  _sectionTitle(_reportType == 0 ? '📋 تفاصيل ولادات شهر $_selectedMonth / $_selectedYear' : '📋 توقعات ولادات شهر $_selectedMonth / $_selectedYear'),
                  const SizedBox(height: 12),
                  if (monthBirthDetails.isEmpty)
                    Container(padding: const EdgeInsets.all(20), width: double.infinity, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(15)), child: Text(_reportType == 0 ? 'لا توجد ولادات مسجلة في هذا الشهر.' : 'لا توجد ولادات متوقعة في هذا الشهر.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)))
                  else
                    ListView.separated(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: monthBirthDetails.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final b = monthBirthDetails[i];
                        final bDate = b['date'] as DateTime;
                        if (_reportType == 0) {
                          final isMale = b['isMale'] as bool;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: (isMale ? Colors.blue : Colors.pink).withOpacity(0.2))),
                            child: Row(children: [
                              Container(width: 45, height: 45, decoration: BoxDecoration(color: (isMale ? Colors.blue : Colors.pink).withOpacity(0.1), shape: BoxShape.circle), child: Icon(isMale ? Icons.male : Icons.female, color: isMale ? Colors.blue : Colors.pink)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('الأم: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: (b['color'] as Color? ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${b['cowId']}', style: TextStyle(fontWeight: FontWeight.bold, color: b['color'] as Color? ?? Colors.grey)),
                                        ),
                                      ],
                                    ),
                                    Text('التاريخ: ${bDate.day}/${bDate.month}/${bDate.year}', style: const TextStyle(fontSize: 12, color: Colors.grey))
                                  ],
                                ),
                              ),
                              if (b['calfId'].toString().isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('عجل: ${b['calfId']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12))),
                            ]),
                          );
                        } else {
                          final color = b['color'] as Color;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
                            child: Row(children: [
                              Container(width: 45, height: 45, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.auto_awesome, color: color)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('البقرة: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: (b['color'] as Color? ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                          child: Text('${b['cowId']}', style: TextStyle(fontWeight: FontWeight.bold, color: b['color'] as Color? ?? Colors.grey)),
                                        ),
                                      ],
                                    ),
                                    Text('الموعد المتوقع: ${bDate.day}/${bDate.month}/${bDate.year}', style: const TextStyle(fontSize: 12, color: Colors.grey))
                                  ],
                                ),
                              ),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Text('متوقع', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12))),
                            ]),
                          );
                        }
                      },
                    ),
                ],
                if (_selectedTab == 1) ...[
                  _sectionTitle('🥛 تقرير إنتاج الحليب'),
                  _buildWeekFilter(isDark),
                  const SizedBox(height: 12),
                  _milkSummaryCard(
                    milking: milkingCows,
                    heifer: excellentMilkingCows,
                    heiferClose: dryingOffCows,
                    dry: dryCows,
                    total: totalCows,
                    isDark: isDark,
                    milkingPrev: milkingCowsPrev,
                  ),
                  const SizedBox(height: 16),
                  
                  // بطاقة تقدير الإنتاج (جديد)
                  _buildEstimatedProductionCard(milkingCows, isDark),
                  
                  const SizedBox(height: 24),
                  _buildMilkRatioChart(milkingCows, dryCows, isDark),
                  const SizedBox(height: 32),
                  _sectionTitle('📊 توزيع حالة الحليب'),
                  const SizedBox(height: 12),
                  _buildMilkStatusDetails(cows, isDark, targetDate),
                ],

                if (_selectedTab == 2) ...[
                  _sectionTitle('🐄 نظرة عامة على القطيع'),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
                    children: [
                      _statTile('إجمالي البقر', totalCows, Icons.group, Colors.blue, isDark),
                      _statTile('حوامل مؤكد', pregnantConfirmed, Icons.pregnant_woman, Colors.green, isDark),
                      _statTile('بعد الولادة', postBirth, Icons.child_friendly, Colors.teal, isDark),
                      _statTile('غير ملقحة', notInseminated, Icons.block, Colors.orange, isDark),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _sectionTitle('🧬 الكفاءة التناسلية (متوسط القطيع)'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _efficiencyCard('الأيام المفتوحة', '${avgDaysOpen.toStringAsFixed(1)} يوم', Icons.calendar_today, Colors.blue, isDark)),
                      const SizedBox(width: 12),
                      Expanded(child: _efficiencyCard('معدل التلقيحات', '${avgInseminations.toStringAsFixed(2)}', Icons.science, Colors.purple, isDark)),
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
                  const SizedBox(height: 24),
                  _buildHerdCompositionChart(cows, isDark),
                  const SizedBox(height: 32),
                  _sectionTitle('📈 توقعات 12 شهر القادمة'),
                  const SizedBox(height: 16),
                  _buildPredictionCharts(cows, isDark),
                ],
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
      decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withOpacity(0.1) : Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
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
      decoration: BoxDecoration(color: isDark ? Colors.grey.withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
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
                _legendItem('ذكور', male, Colors.blue, unit: 'عجل'),
                const SizedBox(height: 8),
                _legendItem('إناث', female, Colors.pink, unit: 'عجل'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, int count, Color color, {String unit = 'بقرة'}) => Row(
    children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const Spacer(),
      Text('$count $unit', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
    ],
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );

  Widget _statTile(String label, int value, IconData icon, Color color, bool isDark) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
    child: Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
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

  Widget _calvesSummaryCard({required int total, required int active, required int male, required int female, required int birthsMonth, required int birthsYear, required bool isDark, required int selectedMonth, required int selectedYear, int birthsMonthPrev = 0}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: isDark ? Colors.teal.withOpacity(0.1) : Colors.teal.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.teal.withOpacity(0.1))),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$birthsMonth', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal)), Text(_reportType == 0 ? 'ولادات شهر $selectedMonth' : 'توقعات شهر $selectedMonth', style: const TextStyle(fontSize: 12, color: Colors.grey))]),
            _buildComparisonBadge(birthsMonth, birthsMonthPrev),
            Icon(_reportType == 0 ? Icons.auto_awesome : Icons.trending_up, color: Colors.teal.withOpacity(0.5), size: 40),
          ],
        ),
        const Divider(height: 30),
        Row(children: [_calveStatCol('الإجمالي', total, Colors.blue), _calveStatCol('نشط', active, Colors.green), _calveStatCol('ذكور', male, Colors.blueAccent), _calveStatCol('إناث', female, Colors.pinkAccent)]),
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
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
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
      decoration: BoxDecoration(color: isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.3))),
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
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: pct, backgroundColor: color.withOpacity(0.1), color: color, minHeight: 6)),
      ],
    );
  }

  Widget _pregnancyRateCard({required int inseminated, required int confirmed, required int total, required bool isDark}) {
    final rate = total == 0 ? 0.0 : confirmed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.1) : Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withOpacity(0.3))),
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
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: rate, backgroundColor: Colors.green.withOpacity(0.15), color: Colors.green, minHeight: 12)),
          const SizedBox(height: 12),
          Row(children: [_infoChip('ملقحة', inseminated, Colors.teal), const SizedBox(width: 10), _infoChip('حمل مؤكد', confirmed, Colors.green)]),
        ],
      ),
    );
  }

  Widget _milkSummaryCard({required int milking, required int heifer, required int heiferClose, required int dry, required int total, required bool isDark, int milkingPrev = 0}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$milking', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const Text('أبقار حلوب حالياً', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              _buildComparisonBadge(milking, milkingPrev),
              const Icon(Icons.opacity, color: Colors.orange, size: 40),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              _calveStatCol('بكيرة', heifer, Colors.orange),
              _calveStatCol('بكيرة قريبة', heiferClose, Colors.pinkAccent),
              _calveStatCol('مجففة', dry, Colors.indigo),
              _calveStatCol('الإجمالي', total, Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilkRatioChart(int milking, int dry, bool isDark) {
    final total = milking + dry;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(color: Colors.orange, value: milking.toDouble(), title: '${((milking / total) * 100).toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: Colors.blueGrey, value: dry.toDouble(), title: '${((dry / total) * 100).toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نسبة الحليب vs التجفيف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                _legendItem('حلوب', milking, Colors.orange, unit: 'بقرة'),
                const SizedBox(height: 8),
                _legendItem('مجففة', dry, Colors.blueGrey, unit: 'بقرة'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilkStatusDetails(List<Cow> cows, bool isDark, DateTime targetDate) {
    if (cows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
        child: const Text('لا توجد بيانات متاحة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final cow = cows[i];
        final effectiveBirth = cow.effectiveBirthDate;
        
        String statusLabel = 'غير منتجة';
        Color statusColor = Colors.grey;
        IconData icon = Icons.info_outline;
        int? daysInfo;
        bool isFuture = false;

        // منطق اللوحة الذكية (Smart Dashboard Logic)
        bool isHeiferAtDate = true;
        bool hasBirthAtDate = effectiveBirth != null && effectiveBirth.isBefore(targetDate);
        
        if (hasBirthAtDate || cow.isManualCow == true) {
          isHeiferAtDate = false;
        }

        final daysSinceInsemAtDate = targetDate.difference(cow.inseminationDate).inDays;
        final daysRemaining = AppSettings.pregnancyDays - daysSinceInsemAtDate;

        if (isHeiferAtDate) {
           if (cow.isInseminated && daysRemaining <= 70 && daysRemaining > 0) {
              statusLabel = 'بكيرة قريبة';
              statusColor = Colors.pinkAccent;
              icon = Icons.pregnant_woman;
              daysInfo = daysRemaining;
              isFuture = true;
           } else {
              statusLabel = 'بكيرة';
              statusColor = Colors.orange;
              icon = Icons.agriculture;
              if (cow.isInseminated) {
                 daysInfo = daysSinceInsemAtDate;
              }
           }
        } else {
           if (cow.isInseminated && daysRemaining <= 70 && daysRemaining > 0) {
              statusLabel = 'مجففة';
              statusColor = Colors.indigo;
              icon = Icons.bedtime_outlined;
              daysInfo = daysRemaining;
              isFuture = true;
           } else {
              statusLabel = 'حلوب';
              statusColor = Colors.blueAccent;
              icon = Icons.opacity;
              if (hasBirthAtDate) {
                 daysInfo = targetDate.difference(effectiveBirth!).inDays;
              }
           }
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 45, height: 45,
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('البقرة: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: cow.color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text('${cow.id}', style: TextStyle(fontWeight: FontWeight.bold, color: cow.color)),
                        ),
                      ],
                    ),
                    Text(daysInfo != null 
                        ? (isFuture ? 'باقي للولادة: $daysInfo يوم' : 'أيام: $daysInfo')
                        : 'لا توجد بيانات زمنية', 
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPredictionCharts(List<Cow> cows, bool isDark) {
    final Map<int, int> monthlyExpectedBirths = {};
    final Map<int, int> monthlyExpectedDrying = {};
    
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final targetDate = DateTime(now.year, now.month + i, 1);
      monthlyExpectedBirths[i] = 0;
      monthlyExpectedDrying[i] = 0;
      
      for (var cow in cows) {
        if (cow.isInseminated && !cow.isPostBirth) {
          final expectedBirth = cow.inseminationDate.add(Duration(days: AppSettings.pregnancyDays));
          final expectedDrying = expectedBirth.subtract(Duration(days: AppSettings.dryingDays));
          
          if (expectedBirth.year == targetDate.year && expectedBirth.month == targetDate.month) {
            monthlyExpectedBirths[i] = (monthlyExpectedBirths[i] ?? 0) + 1;
          }
          if (expectedDrying.year == targetDate.year && expectedDrying.month == targetDate.month) {
            monthlyExpectedDrying[i] = (monthlyExpectedDrying[i] ?? 0) + 1;
          }
        }
      }
    }

    return Column(
      children: [
        _buildTrendChart('توقعات الولادات (12 شهر)', monthlyExpectedBirths, Colors.teal, isDark),
        const SizedBox(height: 24),
        _buildTrendChart('توقعات التجفيف (12 شهر)', monthlyExpectedDrying, Colors.blueGrey, isDark),
      ],
    );
  }

  Widget _buildTrendChart(String title, Map<int, int> data, Color color, bool isDark) {
    final maxVal = data.values.isEmpty ? 0 : data.values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal + 1).toDouble();
    final now = DateTime.now();

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (v) => FlLine(color: isDark ? Colors.white10 : Colors.black12, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: 1, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) {
                    final month = (now.month + v.toInt() - 1) % 12 + 1;
                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(month.toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)));
                  })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.toDouble(), color: color, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))] )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHerdCompositionChart(List<Cow> cows, bool isDark) {
    final heifers = cows.where((c) => c.isHeifer).length;
    final mature = cows.where((c) => !c.isHeifer).length;
    final total = cows.length;
    
    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? Colors.grey.withOpacity(0.1) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4, centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(color: Colors.blue, value: mature.toDouble(), title: '${((mature / total) * 100).toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(color: Colors.teal, value: heifers.toDouble(), title: '${((heifers / total) * 100).toStringAsFixed(0)}%', radius: 45, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
                const Text('تكوين القطيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                _legendItem('أبقار بالغة', mature, Colors.blue, unit: 'بقرة'),
                const SizedBox(height: 8),
                _legendItem('بكاكير', heifers, Colors.teal, unit: 'بقرة'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, int val, Color color) => Chip(label: Text('$label: $val', style: TextStyle(color: color, fontWeight: FontWeight.bold)), backgroundColor: color.withOpacity(0.1), side: BorderSide(color: color.withOpacity(0.3)));

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

  Widget _buildCategoryFilter(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _filterBtn('الكل', 0, isDark),
          _filterBtn('أبقار', 1, isDark),
          _filterBtn('بكاكير', 2, isDark),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, int index, bool isDark) {
    bool isSelected = _categoryFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _categoryFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.teal : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? (isDark ? Colors.white : Colors.teal) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonBadge(int current, int previous) {
    if (previous == 0) return const SizedBox.shrink();
    final diff = current - previous;
    if (diff == 0) return const SizedBox.shrink();
    
    final isIncrease = diff > 0;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isIncrease ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: isIncrease ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 2),
          Text(
            '${((diff.abs() / previous) * 100).toInt()}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isIncrease ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(int index, String label, IconData icon, Color color) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstimatedProductionCard(int milkingCows, bool isDark) {
    final yieldPerCow = AppSettings.averageDailyMilkPerCow;
    int days = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    String periodLabel = 'لشهر $_selectedMonth';

    if (_selectedWeek > 0) {
      if (_selectedWeek == 4) {
        days = DateTime(_selectedYear, _selectedMonth + 1, 0).day - 21;
      } else {
        days = 7;
      }
      periodLabel = 'للأسبوع $_selectedWeek';
    }

    final totalEstimated = milkingCows * yieldPerCow * days;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [Colors.blue.withOpacity(0.2), Colors.blue.withOpacity(0.05)] : [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.show_chart, color: Colors.blue, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الإنتاج المتوقع $periodLabel', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${totalEstimated.toStringAsFixed(0)} لتر', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('بناءً على $milkingCows بقرة بمتوسط $yieldPerCow لتر/يوم', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _efficiencyCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildWeekFilter(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _weekChip('الكل', 0, isDark),
            const SizedBox(width: 8),
            _weekChip('الأسبوع 1', 1, isDark),
            const SizedBox(width: 8),
            _weekChip('الأسبوع 2', 2, isDark),
            const SizedBox(width: 8),
            _weekChip('الأسبوع 3', 3, isDark),
            const SizedBox(width: 8),
            _weekChip('الأسبوع 4', 4, isDark),
          ],
        ),
      ),
    );
  }

  Widget _weekChip(String label, int value, bool isDark) {
    final isSelected = _selectedWeek == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87), fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedWeek = value);
      },
      selectedColor: Colors.blue,
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  /// حساب عدد أيام الحليب لبقرة معينة خلال فترة زمنية محددة
  int _calculateMilkingDaysInPeriod(Cow cow, DateTime start, DateTime end) {
    // 1. تحديد متى يبدأ الحليب
    DateTime milkingStart;
    if (cow.effectiveBirthDate != null) {
      milkingStart = cow.effectiveBirthDate!;
    } else if (cow.isManualCow == true) {
      // بقرة يدوية بدون تاريخ ولادة مسجل → نفترض أنها تحلب دائماً
      milkingStart = DateTime(2000, 1, 1);
    } else if (cow.isInseminated) {
      // بكيرة حامل → يبدأ حليبها افتراضياً بعد 280 يوماً من التلقيح
      milkingStart = cow.inseminationDate.add(Duration(days: AppSettings.pregnancyDays));
    } else {
      // بكيرة غير حامل أو عجل → لا يوجد حليب
      return 0;
    }
    
    // 2. تحديد متى يتوقف الحليب (تاريخ الجفاف المتوقع: التلقيح + (فترة الحمل - 70 يوماً))
    DateTime milkingEnd = DateTime(2100, 1, 1);
    if (cow.isInseminated) {
      milkingEnd = cow.inseminationDate.add(Duration(days: AppSettings.pregnancyDays - 70));
      
      // تصحيح: إذا كان تاريخ الجفاف قبل تاريخ الولادة (في حالة البكاكير الحوامل لأول مرة)
      // فإن الجفاف لا ينطبق عليها في حملها الأول إلا في نهايته
      if (cow.effectiveBirthDate == null && cow.isManualCow != true) {
         // للبكاكير: لا تجف أبداً قبل ولادتها الأولى
         milkingEnd = DateTime(2100, 1, 1);
      }
    }

    // 3. هل هي بكيرة خلال هذه الفترة؟ (إذا لم تلد بعد وليست يدوية)
    // نعتبرها بكيرة إذا كان تاريخ بداية الحليب (الولادة) بعد نهاية الفترة المختارة
    if (cow.isHeifer && milkingStart.isAfter(end)) {
      return 0;
    }

    // 4. حساب التقاطع (Overlap) بين فترة الحليب والفترة المطلوبة
    DateTime overlapStart = milkingStart.isAfter(start) ? milkingStart : start;
    DateTime overlapEnd = milkingEnd.isBefore(end) ? milkingEnd : end;

    if (overlapStart.isAfter(overlapEnd)) {
      return 0;
    }

    // إضافة 1 ليكون الحساب شاملاً لليومين
    return overlapEnd.difference(overlapStart).inDays + 1;
  }
}
