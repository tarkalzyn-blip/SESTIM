import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cow_pregnancy/utils/date_picker_utils.dart';
import 'package:cow_pregnancy/widgets/custom_date_picker.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/add_edit_cow_screen.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/widgets/cow_id_badge.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';
import 'package:cow_pregnancy/widgets/animated_action_card.dart';
import 'package:cow_pregnancy/providers/edit_access_provider.dart';
import 'package:collection/collection.dart';

class CowDetailScreen extends ConsumerWidget {
  final Cow cow;

  const CowDetailScreen({super.key, required this.cow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cows = ref.watch(cowProvider);
    // الحصول على أحدث بيانات لهذه البقرة من المزود لضمان التحديث التلقائي
    final currentCow = cows.firstWhereOrNull(
      (c) => c.uniqueKey == cow.uniqueKey,
    ) ?? cow;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leadingWidth: 100,
            backgroundColor: currentCow.color,
            leading: Row(
              children: [
                const BackButton(color: Colors.white),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'تعديل',
                onPressed: () {
                  ref.read(editAccessProvider.notifier).runWithAccess(context, () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AddEditCowScreen(cow: currentCow),
                    ));
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'حذف',
                onPressed: () {
                  ref.read(editAccessProvider.notifier).runWithAccess(context, () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('حذف البقرة'),
                        content: Text('هل أنت متأكد من حذف البقرة رقم ${currentCow.id}؟ لا يمكن التراجع.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(cowProvider.notifier).deleteCow(currentCow.uniqueKey);
                      if (context.mounted) Navigator.pop(context);
                    }
                  });
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Hero(
                tag: 'cow_card_${currentCow.uniqueKey}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // خلفية بتدرج غني
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            currentCow.color,
                            currentCow.color.withOpacity(0.5),
                            currentCow.color.withOpacity(0.8),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    // دوائر زخرفية
                    Positioned(
                      top: -40, left: -40,
                      child: Container(
                        width: 180, height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20, right: -30,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    // المحتوى
                    Positioned(
                      bottom: 20, left: 20, right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CowIdBadge(
                            id: currentCow.id,
                            color: Colors.white,
                            fontSize: 22,
                            boxSize: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _headerChip(Icons.circle, currentCow.status.split('(').first.trim(), Colors.white),
                              const SizedBox(width: 8),
                              if (currentCow.age != 'غير محدد')
                                _headerChip(Icons.cake_outlined, currentCow.age, Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── البطاقة الرئيسية (متبقي/منذ الولادة) ────────────────
                  _buildMainRemainingBox(context, currentCow),
                  const SizedBox(height: 20),

                  // ── بطاقة المعلومات ───────────────────────────────────────
                  _buildInfoCard(context, currentCow, isDark, subTextColor, textColor),
                  const SizedBox(height: 20),

                  // ── تنبيه تجاوز موعد الولادة ─────────────────────────────
                  if (!currentCow.isPostBirth &&
                      currentCow.isInseminated &&
                      currentCow.daysSinceInsemination > 280) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تنبيه: تجاوز موعد الولادة',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  'تجاوزت موعد الولادة بـ ${currentCow.daysSinceInsemination - 280} يوم',
                                  style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const SizedBox(height: 40),
                  const Text(
                    'نسبة تقدم الحمل',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: currentCow.pregnancyPercentage,
                    ),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: value,
                              minHeight: 20,
                              backgroundColor: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                              color: currentCow.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(value * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: currentCow.color,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      if (currentCow.isInseminated && !currentCow.isPostBirth)
                        Expanded(
                          child: AnimatedActionCard(
                            icon: Icons.child_friendly,
                            label: 'تسجيل ولادة',
                            color: Colors.teal,
                            onTap: () => ref.read(editAccessProvider.notifier).runWithAccess(
                                  context,
                                  () => _showBirthDialog(context, ref, currentCow),
                                ),
                          ),
                        ),
                      if (currentCow.isInseminated && !currentCow.isPostBirth)
                        const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedActionCard(
                          icon: Icons.science_outlined,
                          label: 'تسجيل تلقيح',
                          color: Colors.blueAccent,
                          onTap: () => ref.read(editAccessProvider.notifier).runWithAccess(
                            context,
                            () => _showAddInseminationDialog(
                              context,
                              ref,
                              currentCow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedActionCard(
                      icon: Icons.note_add_outlined,
                      label: 'إضافة ملاحظة',
                      color: Colors.orange,
                      onTap: () => ref.read(editAccessProvider.notifier).runWithAccess(
                        context,
                        () => _showAddNoteDialog(context, ref, currentCow),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  const Text(
                    'السجل التاريخي',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (currentCow.history.isEmpty)
                    const Text(
                      'لا يوجد سجلات سابقة',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...currentCow.history.reversed.map(
                      (event) => _buildHistoryItem(
                        event,
                        subTextColor,
                        context,
                        ref,
                        currentCow,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    dynamic event,
    Color subTextColor,
    BuildContext context,
    WidgetRef ref,
    Cow currentCow,
  ) {
    DateTime date = DateTime.parse(event['date']);
    String title = event['title'] ?? 'حدث';
    String note = event['note'] ?? '';
    String eventId = event['eventId'] ?? '';

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.edit_outlined, color: Colors.blue),
                  ),
                  title: const Text(
                    'تعديل السجل',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('تعديل الملاحظة أو التاريخ'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(editAccessProvider.notifier).runWithAccess(
                      context,
                      () => _showEditHistoryDialog(context, ref, currentCow, event),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text(
                    'حذف السجل',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('إزالة هذا الحدث من السجل التاريخي'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(editAccessProvider.notifier).runWithAccess(context, () {
                      showDialog(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('حذف السجل'),
                          content: Text('هل أنت متأكد من حذف "$title"؟'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dctx),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dctx);
                                final newHistory = currentCow.history
                                    .where((e) => e['eventId'] != eventId)
                                    .toList();
                                ref.read(cowProvider.notifier).updateCow(
                                      currentCow.copyWith(history: newHistory),
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حذف السجل'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                              child: const Text(
                                'حذف',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    });
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF5F5F5),
                    child: Icon(Icons.close, color: Colors.grey),
                  ),
                  title: const Text('إلغاء'),
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.teal.withValues(alpha: 0.3),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd').format(date),
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                  if (note.isNotEmpty)
                    Text(note, style: TextStyle(color: subTextColor)),
                  
                  // Summary chips for vaccines and weights
                  if (event['vaccines'] != null || event['weights'] != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (event['vaccines'] != null && (event['vaccines'] as List).isNotEmpty)
                          _buildSummaryChip(
                            Icons.vaccines,
                            '${(event['vaccines'] as List).length} لقاح',
                            Colors.teal,
                          ),
                        if (event['weights'] != null && (event['weights'] as List).isNotEmpty)
                          _buildSummaryChip(
                            Icons.monitor_weight,
                            '${(event['weights'] as List).length} وزن',
                            Colors.blue,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.more_vert, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditHistoryDialog(
    BuildContext context,
    WidgetRef ref,
    Cow currentCow,
    dynamic event,
  ) {
    final noteController = TextEditingController(text: event['note'] ?? '');
    DateTime selectedDate = DateTime.parse(event['date']);
    String eventId = event['eventId'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(
            'تعديل السجل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showCustomDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    title: 'تعديل التاريخ',
                  );
                  if (picked != null)
                    setStateDialog(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 8),
                      Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'الملاحظة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final newHistory = currentCow.history.map((e) {
                  if (e['eventId'] == eventId) {
                    return {
                      ...e,
                      'date': selectedDate.toIso8601String(),
                      'note': noteController.text,
                    };
                  }
                  return e;
                }).toList();
                ref
                    .read(cowProvider.notifier)
                    .updateCow(currentCow.copyWith(history: newHistory));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تعديل السجل بنجاح'),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Cow cow, bool isDark, Color subColor, Color textColor) {
    final items = <_InfoItem>[];

    items.add(_InfoItem(Icons.timer_outlined, 'العمر الحالي', cow.age, null));

    if (cow.isPostBirth) {
      items.add(_InfoItem(Icons.child_care, 'تاريخ الولادة',
          DateFormat('yyyy/MM/dd').format(cow.birthDate!), Colors.teal));
      items.add(_InfoItem(Icons.hourglass_bottom, 'منذ الولادة',
          '${cow.daysSinceBirth} يوم', Colors.teal));
    } else {
      items.add(_InfoItem(Icons.calendar_today,
          cow.isInseminated ? 'تاريخ التلقيح' : 'تاريخ آخر شبق',
          DateFormat('yyyy/MM/dd').format(cow.inseminationDate), Colors.blue));
      items.add(_InfoItem(Icons.timer, 'الأيام المنقضية',
          '${cow.daysSinceInsemination} يوم', Colors.blue));
    }

    if (cow.bullId != null && cow.bullId!.isNotEmpty)
      items.add(_InfoItem(Icons.pets, 'رقم الثور', cow.bullId!, Colors.blueGrey));

    if (cow.motherId != null && cow.motherId!.isNotEmpty)
      items.add(_InfoItem(Icons.family_restroom, 'رقم الأم', cow.motherId!, Colors.blueGrey));

    items.add(_InfoItem(Icons.info_outline, 'الحالة', cow.status, cow.color));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cow.color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: cow.color.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: (item.color ?? Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color ?? Colors.grey.shade600, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label, style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(item.value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: item.color ?? textColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                Divider(height: 1, indent: 56, color: Colors.grey.withOpacity(0.12)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailRow(
    String title,
    String value,
    IconData icon, {
    Color? color,
    Color? subTextColor,
    Color? textColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey.shade700, size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: subTextColor ?? Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color ?? textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainRemainingBox(BuildContext context, Cow cow) {
    final daysSinceInsemination = cow.daysSinceInsemination;
    final daysRemaining = 280 - daysSinceInsemination;
    final isBirth = cow.isPostBirth;
    final isOverdue = !isBirth && daysRemaining < 0;

    String label = isBirth
        ? 'منذ الولادة'
        : (isOverdue ? 'تجاوزت موعد الولادة' : 'متبقي للولادة');
    String value = isBirth
        ? '${cow.daysSinceBirth}'
        : (isOverdue ? '${daysRemaining.abs()}' : '${daysRemaining}');

    Color boxColor = isOverdue ? Colors.red : cow.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: boxColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: boxColor.withValues(alpha: 0.15), width: 1.5),
        gradient: LinearGradient(
          colors: [boxColor.withValues(alpha: 0.08), Colors.transparent],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: boxColor.withValues(alpha: 0.7),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: isOverdue
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'يوم',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: boxColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBirth ? Icons.child_care : Icons.calendar_month,
              color: boxColor,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddInseminationDialog(
    BuildContext context,
    WidgetRef ref,
    Cow currentCow,
  ) {
    // ── التحقق 1: حديثة الولادة ولم تمر المدة الدنيا المطلوبة ────────────
    if (currentCow.isPostBirth) {
      final minDays = AppSettings.minInseminationDaysAfterBirth;
      final daysSinceBirth = currentCow.daysSinceBirth;
      if (daysSinceBirth < minDays) {
        final remaining = minDays - daysSinceBirth;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                SizedBox(width: 8),
                Text('التلقيح مبكر جداً', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'مرّ على الولادة $daysSinceBirth يوم فقط.\n\n'
              'الحد الأدنى المسموح به هو $minDays يوم.\n\n'
              'يمكن تسجيل التلقيح بعد $remaining يوم أخرى.\n\n'
              'يمكنك تغيير هذه المدة من: الإعدادات ← إعدادات المزرعة',
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        return;
      }
    }

    // ── التحقق 2: حمل متقدم (أكثر من 5 أشهر) ───────────────────────────
    if (currentCow.isInseminated &&
        !currentCow.isPostBirth &&
        currentCow.daysSinceInsemination > 150) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'تنبيه: حمل متقدم',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'البقرة ملقحة منذ أكثر من 5 أشهر (${currentCow.daysSinceInsemination} يوم).\n\n'
            'لا يمكن تسجيل تلقيح جديد في هذه المرحلة. إذا كان هناك خطأ في التاريخ السابق، يرجى تعديله من زر التعديل العلوي ✏️.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('فهمت'),
            ),
          ],
        ),
      );
      return;
    }

    final bullController = TextEditingController(text: currentCow.bullId);
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(
            'تسجيل تلقيح جديد',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم تحديث تاريخ التلقيح الحالي للبقرة لبدء دورة حمل جديدة.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bullController,
                decoration: InputDecoration(
                  labelText: 'رقم العجل',
                  prefixIcon: const Icon(Icons.pets),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomDatePickerField(
                label: 'تاريخ التلقيح',
                initialDate: selectedDate,
                onDateSelected: (date) => selectedDate = date,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                List<dynamic> newHistory = currentCow.history.toList();

                // إذا كانت البقرة ملقحة سابقاً ولم تلد، نعتبر التلقيح السابق فاشلاً
                if (currentCow.isInseminated && !currentCow.isPostBirth) {
                  newHistory.add({
                    'title': 'فشل تلقيح سابق ❌',
                    'date': DateTime.now().toIso8601String(),
                    'eventId': DateTime.now().millisecondsSinceEpoch.toString(),
                    'note':
                        'تم تسجيل تلقيح جديد بسبب عدم ثبوت الحمل السابق بعد ${currentCow.daysSinceInsemination} يوم.',
                  });
                }

                newHistory.add({
                  'title': 'تلقيح جديد',
                  'date': selectedDate.toIso8601String(),
                  'eventId': (DateTime.now().millisecondsSinceEpoch + 1)
                      .toString(),
                  'note': 'رقم العجل: ${bullController.text}',
                });

                // Update the cow's main insemination date and status
                ref
                    .read(cowProvider.notifier)
                    .updateCow(
                      currentCow.copyWith(
                        inseminationDate: selectedDate,
                        bullId: bullController.text,
                        birthDate:
                            null, // Reset birth date as it's a new pregnancy cycle
                        isInseminated: true,
                        history: newHistory,
                      ),
                    );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تسجيل التلقيح الجديد وبدء دورة الحمل'),
                    backgroundColor: Colors.blueAccent,
                  ),
                );
              },
              child: const Text('تأكيد التلقيح'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBirthDialog(BuildContext context, WidgetRef ref, Cow currentCow) {
    // التحقق من مدة الحمل (أقل من 260 يوم يمنع تسجيل الولادة)
    final daysSinceInsemination = currentCow.daysSinceInsemination;
    if (daysSinceInsemination < 260) {
      final daysRemainingToThreshold = 260 - daysSinceInsemination;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'تنبيه: حمل مبكر جداً',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'هذه البقرة ملقحة منذ $daysSinceInsemination يوماً فقط.\n\n'
            'يتبقى $daysRemainingToThreshold يوماً للوصول إلى الحد الأدنى للولادة (260 يوم).\n\n'
            'إذا ولدت البقرة فعلاً، يرجى تعديل "تاريخ التلقيح" أولاً من زر التعديل ✏️ في الأعلى.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('فهمت'),
            ),
          ],
        ),
      );
      return;
    }

    DateTime selectedBirthDate = DateTime.now();
    String selectedGender = 'أنثى';
    final calfIdController = TextEditingController();
    int selectedCalfColorValue = Colors.blue.toARGB32();
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.brown,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(
            'تسجيل ولادة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رقم المولود (اختياري):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: calfIdController,
                  decoration: InputDecoration(
                    hintText: 'أدخل رقم المولود الجديد',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'تاريخ الولادة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                CustomDatePickerField(
                  label: 'تاريخ الولادة',
                  initialDate: selectedBirthDate,
                  firstDate: currentCow.inseminationDate,
                  onDateSelected: (date) => selectedBirthDate = date,
                ),
                const SizedBox(height: 20),
                const Text(
                  'جنس المولود:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(
                          child: Text(
                            'أنثى 🐄',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        selected: selectedGender == 'أنثى',
                        selectedColor: Colors.pink.shade100,
                        onSelected: (val) =>
                            setStateDialog(() => selectedGender = 'أنثى'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(
                          child: Text('ذكر 🐂', style: TextStyle(fontSize: 16)),
                        ),
                        selected: selectedGender == 'ذكر',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) =>
                            setStateDialog(() => selectedGender = 'ذكر'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'اللون المميز للعجل/العجولة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: colors.map((color) {
                    bool isSelected =
                        selectedCalfColorValue == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setStateDialog(
                        () => selectedCalfColorValue = color.toARGB32(),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 40 : 32,
                        height: isSelected ? 40 : 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                List<dynamic> newHistory = currentCow.history.toList();
                String calfId = calfIdController.text.trim();
                newHistory.add({
                  'title': 'تسجيل ولادة',
                  'date': selectedBirthDate.toIso8601String(),
                  'eventId': DateTime.now().millisecondsSinceEpoch.toString(),
                  'calfId': calfId.isEmpty ? null : calfId,
                  'calfColorValue': selectedCalfColorValue,
                  'note':
                      'ولادة بعد ${selectedBirthDate.difference(currentCow.inseminationDate).inDays} يوم - المولود: $selectedGender${calfId.isNotEmpty ? ' - رقم: $calfId' : ''}',
                });
                ref
                    .read(cowProvider.notifier)
                    .updateCow(
                      currentCow.copyWith(
                        birthDate: selectedBirthDate,
                        history: newHistory,
                      ),
                    );
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم تسجيل ولادة ${calfId.isNotEmpty ? "المولود رقم $calfId" : "المولود"} بنجاح.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text(
                'تأكيد وتسجيل',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref, Cow currentCow) {
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(
            'إضافة ملاحظة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showCustomDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      title: 'تاريخ الملاحظة',
                    );
                    if (picked != null) {
                      setStateDialog(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'نص الملاحظة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (noteController.text.trim().isEmpty) return;
                
                List<dynamic> newHistory = currentCow.history.toList();
                newHistory.add({
                  'title': 'ملاحظة',
                  'date': selectedDate.toIso8601String(),
                  'eventId': DateTime.now().millisecondsSinceEpoch.toString(),
                  'note': noteController.text.trim(),
                });

                ref.read(cowProvider.notifier).updateCow(
                  currentCow.copyWith(history: newHistory),
                );

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت إضافة الملاحظة بنجاح'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// كلاس مساعد لبناء بنود بطاقة المعلومات
class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _InfoItem(this.icon, this.label, this.value, this.color);
}
