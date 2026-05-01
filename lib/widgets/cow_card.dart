import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/widgets/cow_id_badge.dart';
import 'package:cow_pregnancy/screens/cow_detail_screen.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class CowCard extends ConsumerStatefulWidget {
  final Cow cow;
  final int index;
  const CowCard({super.key, required this.cow, this.index = 0});

  @override
  ConsumerState<CowCard> createState() => _CowCardState();
}

class _CowCardState extends ConsumerState<CowCard> {

  @override
  Widget build(BuildContext context) {
    final cow = widget.cow;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Hero(
        tag: 'cow_card_${cow.uniqueKey}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CowDetailScreen(cow: cow),
            )),
            onLongPress: () => _showDeleteDialog(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark
                    ? cow.color.withOpacity(0.12)
                    : cow.color.withOpacity(0.07),
                border: Border.all(
                  color: cow.color.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cow.color.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    // ── الشريط العلوي الملوّن ──────────────────────────
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cow.color, cow.color.withOpacity(0.4)],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        children: [
                          // ── الصف الأول: الحالة يمين | الرقم يسار ────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // يسار: شعار الرقم واللون
                              CowIdBadge(
                                id: cow.id,
                                color: cow.color,
                                showCloud: cow.userId != null,
                              ),

                              // يمين: الحالة
                              _buildStatusChip(cow),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── الصف الثاني: المعلومات ──────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // يسار: تاريخ التلقيح
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined,
                                      size: 15, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    cow.isPostBirth 
                                      ? (cow.effectiveBirthDate != null ? DateFormat('dd/MM/yyyy').format(cow.effectiveBirthDate!) : 'غير محدد')
                                      : DateFormat('dd/MM/yyyy').format(cow.inseminationDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),

                              // يمين: عمر الحمل
                              Text(
                                'عمر الحمل: ${_formatDuration(cow.pregnancyDuration)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── الصف الثالث: الأرقام الكبيرة ────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // يسار: منذ التلقيح / منذ الولادة
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cow.isPostBirth ? 'منذ الولادة' : 'منذ التلقيح',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade500),
                                  ),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '${cow.isPostBirth ? cow.daysSinceBirth : cow.daysSinceInsemination}',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Theme.of(context).colorScheme.onSurface,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'يوم',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                ],
                              ),

                              const Spacer(),

                              // وسط: أيقونة
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cow.color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.grass_rounded,
                                    size: 22, color: cow.color.withOpacity(0.6)),
                              ),

                              const Spacer(),

                              // يمين: متبقي للولادة (البطاقة البيضاء)
                              _buildRemainingBox(context, cow),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── شريط التقدم ──────────────────────────────────
                          _buildProgressBar(context, cow),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف البقرة'),
        content: Text('هل أنت متأكد من حذف البقرة رقم ${widget.cow.id}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              ref.read(cowProvider.notifier).deleteCow(widget.cow.uniqueKey);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Cow cow) {
    Color chipColor = cow.color;
    IconData chipIcon = Icons.check_circle_rounded;

    final status = cow.status;
    if (status.contains('⚠') || status.contains('تجاوز')) {
      chipColor = Colors.red;
      chipIcon = Icons.warning_rounded;
    } else if (status.contains('قريب') || status.contains('شبق متوقع')) {
      chipColor = Colors.orange;
      chipIcon = Icons.notifications_active_rounded;
    } else if (status.contains('بكيرة')) {
      chipColor = Colors.purple;
      chipIcon = Icons.star_rounded;
    } else if (status.contains('حامل') || status.contains('مراقبة')) {
      chipColor = Colors.blue;
      chipIcon = Icons.monitor_heart_rounded;
    } else if (status.contains('ولادة')) {
      chipColor = Colors.teal;
      chipIcon = Icons.child_friendly_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, size: 15, color: chipColor),
          const SizedBox(width: 6),
          Text(
            status.replaceAll('⚠ ', '').split('(').first.trim(),
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingBox(BuildContext context, Cow cow) {
    final int pregnancyDays = AppSettings.pregnancyDays;
    final daysRemaining = pregnancyDays - cow.daysSinceInsemination;
    final isBirth = cow.isPostBirth;
    final isOverdue = !isBirth && daysRemaining < 0;

    String label = isBirth
        ? 'منذ الولادة'
        : (isOverdue ? 'تجاوزت الموعد' : 'متبقي للولادة');
    String value = isBirth
        ? '${cow.daysSinceBirth}'
        : (isOverdue ? '${daysRemaining.abs()}' : '$daysRemaining');

    final boxColor = isOverdue ? Colors.red : cow.color;

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.07)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: boxColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: boxColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: isOverdue ? Colors.red : boxColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'يوم',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400),
                ),
              ),
              const Spacer(),
              Icon(Icons.calendar_today_rounded,
                  color: boxColor.withOpacity(0.7), size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, Cow cow) {
    final value = cow.pregnancyPercentage;
    return Row(
      children: [
        Icon(Icons.power_settings_new_rounded,
            size: 22, color: cow.color.withOpacity(0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: cow.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cow.color.withOpacity(0.5), cow.color],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(value * 100).toInt()}%',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: cow.color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int totalDays) {
    if (totalDays < 30) return '$totalDays يوم';
    final int m = totalDays ~/ 30;
    final int d = totalDays % 30;
    
    if (d == 0) return '$m شهر';
    return '$m شهر و $d يوم';
  }
}
