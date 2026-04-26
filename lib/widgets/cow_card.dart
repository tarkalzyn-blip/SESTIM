import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/widgets/cow_id_badge.dart';
import 'package:cow_pregnancy/screens/cow_detail_screen.dart';

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
        tag: 'cow_card_${widget.cow.uniqueKey}',
          child: Card(
            elevation: 4,
            shadowColor: widget.cow.color.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: widget.cow.color.withOpacity(0.3), width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                splashColor: widget.cow.color.withValues(alpha: 0.25),
                highlightColor: widget.cow.color.withValues(alpha: 0.15),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CowDetailScreen(cow: widget.cow)
                  ));
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف البقرة'),
                      content: Text('هل أنت متأكد من حذف البقرة رقم ${widget.cow.id}؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
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
                },
                child: Ink(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: widget.cow.color.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: widget.cow.color.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Top Row: Status Chip and Name ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // الطرف الأيمن (الأول في RTL): شعار الرقم واللون
                          CowIdBadge(
                            id: widget.cow.id,
                            color: widget.cow.color,
                            showCloud: widget.cow.userId != null,
                          ),

                          // الطرف الأيسر (الثاني في RTL): الحالة
                          _buildStatusChip(widget.cow),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // --- Middle Section: Data Row ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Side: Insemination Info (Date and Since)
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 0.0), // Restored to align with "عمر الحمل"
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                    icon: Icons.calendar_today_outlined,
                                    label: widget.cow.isPostBirth ? 'ولادة:' : 'تلقيح:',
                                    value: DateFormat('yyyy-MM-dd').format(
                                      widget.cow.isPostBirth ? widget.cow.birthDate! : widget.cow.inseminationDate
                                    ),
                                    isHeader: true,
                                  ),
                                  const SizedBox(height: 28), // Increased to push the next row down only
                                  _buildBigInfoRow(
                                    icon: Icons.vaccines_outlined,
                                    label: widget.cow.isPostBirth ? 'منذ الولادة' : 'منذ التلقيح',
                                    value: '${widget.cow.isPostBirth ? widget.cow.daysSinceBirth : widget.cow.daysSinceInsemination}',
                                    unit: 'يوم',
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Right Side: Remaining Days Box
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'عمر الحمل: ${_formatDaysToMonths(
                                    widget.cow.isPostBirth 
                                        ? widget.cow.birthDate!.difference(widget.cow.inseminationDate).inDays 
                                        : widget.cow.daysSinceInsemination
                                  )}',
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                                const SizedBox(height: 8),
                                _buildRemainingBox(context, widget.cow),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      
                      // --- Bottom Section: Progress Bar ---
                      _buildProgressBar(context, widget.cow),
                    ],
                  ),
                ),         // Ink
              ),           // InkWell
            ),             // Material
          ),               // Card
        ),                 // Hero
    );                     // TweenAnimationBuilder
  }

  Widget _buildStatusChip(Cow cow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cow.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        cow.status.split('(').first.trim(), // Shorten status for chip
        style: TextStyle(
          color: cow.color, 
          fontWeight: FontWeight.w800, 
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value, bool isHeader = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: isHeader ? 11 : 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(text: '$label '),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBigInfoRow({required IconData icon, required String label, required String value, required String unit, required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color.withOpacity(0.8)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value, 
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.w900, 
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1,
                  )
                ),
                const SizedBox(width: 4),
                Text(unit, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3))),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemainingBox(BuildContext context, Cow cow) {
    final daysRemaining = 280 - cow.daysSinceInsemination;
    final isBirth = cow.isPostBirth;
    
    final isOverdue = !isBirth && daysRemaining < 0;
    
    String label = isBirth ? 'منذ الولادة' : (isOverdue ? 'تجاوزت الموعد' : 'متبقي للولادة');
    String value = isBirth 
        ? '${cow.daysSinceBirth}' 
        : (isOverdue ? '${daysRemaining.abs()}' : '${daysRemaining}');
    
    Color boxColor = isOverdue ? Colors.red : cow.color;
    
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: boxColor.withOpacity(0.12), width: 1.2),
        gradient: LinearGradient(
          colors: [
            boxColor.withOpacity(0.05),
            Colors.transparent,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.w900, 
                        color: isOverdue ? Colors.red : Theme.of(context).colorScheme.onSurface,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('يوم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: (isOverdue ? Colors.red : Theme.of(context).colorScheme.onSurface).withOpacity(0.3))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.calendar_month, color: boxColor.withOpacity(0.3), size: 26),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, Cow cow) {
    final targetValue = cow.pregnancyPercentage;
    return Column(
      children: [
        Row(
          children: [
            Text(
              '${(targetValue * 100).toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(targetValue),
                tween: Tween<double>(begin: 0, end: targetValue),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutQuart,
                builder: (context, animValue, child) {
                  return Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 8,
                          width: double.infinity,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade200,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerRight, // RTL support
                            widthFactor: animValue,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cow.color,
                                boxShadow: [
                                  BoxShadow(
                                    color: cow.color.withOpacity(0.4),
                                    blurRadius: 4,
                                  )
                                ]
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.track_changes, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
          ],
        ),
      ],
    );
  }

  String _formatDaysToMonths(int days) {
    if (days <= 0) return '0 يوم';
    int months = days ~/ 30;
    int remainingDays = days % 30;
    
    if (months == 0) return '$remainingDays يوم';
    if (remainingDays == 0) {
      if (months == 1) return 'شهر واحد';
      if (months == 2) return 'شهرين';
      return '$months أشهر';
    }
    
    String monthsStr = months == 1 ? 'شهر' : (months == 2 ? 'شهرين' : '$months أشهر');
    return '$monthsStr و $remainingDays يوم';
  }
}
