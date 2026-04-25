import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cow_pregnancy/widgets/custom_date_picker.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/add_edit_cow_screen.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class CowDetailScreen extends ConsumerWidget {
  final Cow cow;

  const CowDetailScreen({super.key, required this.cow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cows = ref.watch(cowProvider);
    // الحصول على أحدث بيانات لهذه البقرة من المزود لضمان التحديث التلقائي
    final currentCow = cows.firstWhere(
      (c) => c.uniqueKey == cow.uniqueKey,
      orElse: () => cow,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: 'تعديل بيانات البقرة',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditCowScreen(cow: currentCow),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                tooltip: 'حذف البقرة',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف البقرة'),
                      content: Text(
                        'هل أنت متأكد من حذف البقرة رقم ${currentCow.id}؟ لا يمكن التراجع عن هذا.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
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
                  if (confirm == true) {
                    ref
                        .read(cowProvider.notifier)
                        .deleteCow(currentCow.uniqueKey);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'بقرة #${currentCow.id}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Hero(
                tag: 'cow_card_${currentCow.uniqueKey}',
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        currentCow.color,
                        currentCow.color.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentCow.isPostBirth) ...[
                    _buildDetailRow(
                      'تاريخ الولادة',
                      DateFormat('yyyy-MM-dd').format(currentCow.birthDate!),
                      Icons.child_care,
                      subTextColor: subTextColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      'أيام منذ الولادة',
                      '${currentCow.daysSinceBirth} يوم',
                      Icons.timer,
                      subTextColor: subTextColor,
                      textColor: textColor,
                    ),
                  ] else ...[
                    _buildDetailRow(
                      currentCow.isInseminated
                          ? 'تاريخ التلقيح'
                          : 'تاريخ آخر شبق',
                      DateFormat(
                        'yyyy-MM-dd',
                      ).format(currentCow.inseminationDate),
                      Icons.calendar_today,
                      subTextColor: subTextColor,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      'الأيام المنقضية',
                      '${currentCow.daysSinceInsemination} يوم',
                      Icons.timer,
                      subTextColor: subTextColor,
                      textColor: textColor,
                    ),
                  ],
                  if (currentCow.bullId != null &&
                      currentCow.bullId!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      'معلومات الطلوقة',
                      currentCow.bullId!,
                      Icons.pets,
                      color: Colors.blueGrey,
                      subTextColor: subTextColor,
                    ),
                  ],
                  if (currentCow.motherId != null &&
                      currentCow.motherId!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.family_restroom,
                          color: Colors.blueGrey,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رقم الأم',
                              style: TextStyle(
                                fontSize: 14,
                                color: subTextColor,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  currentCow.motherId!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                if (currentCow.motherColorValue != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        currentCow.motherColorValue!,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildDetailRow(
                    'الحالة الحالية',
                    currentCow.status,
                    Icons.info_outline,
                    color: currentCow.color,
                    subTextColor: subTextColor,
                  ),
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
                          child: _buildActionCard(
                            context,
                            icon: Icons.child_friendly,
                            label: 'تسجيل ولادة',
                            color: Colors.teal,
                            onTap: () =>
                                _showBirthDialog(context, ref, currentCow),
                          ),
                        ),
                      if (currentCow.isInseminated && !currentCow.isPostBirth)
                        const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          context,
                          icon: Icons.science_outlined,
                          label: 'تسجيل تلقيح',
                          color: Colors.blueAccent,
                          onTap: () => _showAddInseminationDialog(
                            context,
                            ref,
                            currentCow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentCow.isInseminated && !currentCow.isPostBirth)
                    ...[],

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
                      (event) => _buildHistoryItem(event, subTextColor, context, ref, currentCow),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(dynamic event, Color subTextColor, BuildContext context, WidgetRef ref, Cow currentCow) {
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  title: const Text('تعديل السجل', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('تعديل الملاحظة أو التاريخ'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditHistoryDialog(context, ref, currentCow, event);
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('حذف السجل', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  subtitle: const Text('إزالة هذا الحدث من السجل التاريخي'),
                  onTap: () {
                    Navigator.pop(ctx);
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
                            child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
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
                ],
              ),
            ),
            const Icon(Icons.more_vert, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  void _showEditHistoryDialog(BuildContext context, WidgetRef ref, Cow currentCow, dynamic event) {
    final noteController = TextEditingController(text: event['note'] ?? '');
    DateTime selectedDate = DateTime.parse(event['date']);
    String eventId = event['eventId'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تعديل السجل', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setStateDialog(() => selectedDate = picked);
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
                  labelText: 'الملاحظة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
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
                ref.read(cowProvider.notifier).updateCow(
                  currentCow.copyWith(history: newHistory),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تعديل السجل بنجاح'), backgroundColor: Colors.teal),
                );
              },
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
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
    // التحقق من مدة الحمل الحالية (أكثر من 5 أشهر يمنع تسجيل تلقيح جديد كحماية)
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
                  labelText: 'اسم/رقم الطلوقة',
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
                  'note': 'تلقيح جديد من الطلوقة: ${bullController.text}',
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
}
