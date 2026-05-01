import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/screens/calf_detail_screen.dart';
import 'package:cow_pregnancy/widgets/custom_date_picker.dart';
import 'package:cow_pregnancy/widgets/cow_id_badge.dart';
import 'package:cow_pregnancy/widgets/calf_search_delegate.dart';
import 'package:cow_pregnancy/providers/settings_provider.dart';
import 'package:cow_pregnancy/screens/add_calf_screen.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';

enum CalfSort { newest, oldest }

enum CalfFilter { active, male, female, exited }

class CalvesScreen extends ConsumerStatefulWidget {
  const CalvesScreen({super.key});

  @override
  ConsumerState<CalvesScreen> createState() => _CalvesScreenState();
}

class _CalvesScreenState extends ConsumerState<CalvesScreen> {
  CalfSort _currentSort = CalfSort.newest;
  CalfFilter _currentFilter = CalfFilter.active;

  @override
  void dispose() {
    super.dispose();
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    final days = today.difference(birth).inDays;

    if (days < 30) return '$days يوم';
    if (days < 365) {
      final months = days ~/ 30;
      final remainingDays = days % 30;
      if (remainingDays == 0) return '$months شهر';
      return '$months شهر و $remainingDays يوم';
    }
    final years = days ~/ 365;
    final remainingMonths = (days % 365) ~/ 30;
    if (remainingMonths == 0) return '$years سنة';
    return '$years سنة و $remainingMonths شهر';
  }

  int _calculateAgeInDays(DateTime birthDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    return today.difference(birth).inDays;
  }

  bool _matchBirthEvent(
    dynamic event,
    String eventId,
    String originalEventDate,
  ) {
    final title = event['title']?.toString() ?? '';
    if (title != 'تسجيل ولادة' && title != 'تسجيل ولادة سابقة') return false;
    final storedEvId = event['eventId']?.toString();
    if (storedEvId != null && storedEvId == eventId) return true;
    if (event['date']?.toString() == originalEventDate) return true;
    try {
      final a = DateTime.parse(event['date'].toString());
      final b = DateTime.parse(originalEventDate);
      if (a.millisecondsSinceEpoch == b.millisecondsSinceEpoch) return true;
    } catch (_) {}
    return false;
  }

  void _editCalf(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> calf,
  ) {
    final controller = TextEditingController(text: calf['calfId'] ?? '');
    final List<int> availableColors = ref.read(cowColorsProvider);
    int selectedColorValue =
        calf['calfColorValue'] ??
        (availableColors.isNotEmpty
            ? availableColors.first
            : Colors.blue.toARGB32());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(
            'تعديل بيانات المولود',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'رقم المولود',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'لون الكرت:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: availableColors.map((colorVal) {
                  final color = Color(colorVal);
                  bool isSelected = selectedColorValue == colorVal;
                  return GestureDetector(
                    onTap: () =>
                        setStateDialog(() => selectedColorValue = colorVal),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 40 : 32,
                      height: isSelected ? 40 : 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final String newId = controller.text.trim();
                if (calf['isStandalone'] == true) {
                  final cows = ref.read(cowProvider);
                  final cow = cows.firstWhere(
                    (c) => c.uniqueKey == calf['uniqueKey'],
                  );
                  ref
                      .read(cowProvider.notifier)
                      .updateCow(
                        cow.copyWith(id: newId, colorValue: selectedColorValue),
                        oldKey: cow.uniqueKey,
                      );
                } else {
                  final cows = ref.read(cowProvider);
                  final cowIndex = cows.indexWhere(
                    (c) => c.uniqueKey == calf['motherUniqueKey'],
                  );
                  if (cowIndex != -1) {
                    final cow = cows[cowIndex];
                    final newHistory = cow.history.map((event) {
                      if (_matchBirthEvent(
                        event,
                        calf['eventId'],
                        calf['originalEventDate'],
                      )) {
                        final Map<String, dynamic> newEvent = Map.from(event);
                        newEvent['calfId'] = newId.isEmpty ? null : newId;
                        newEvent['calfColorValue'] = selectedColorValue;
                        String genderInfo =
                            event['note'].toString().contains('ذكر')
                            ? 'ذكر'
                            : 'أنثى';
                        newEvent['note'] =
                            'ولادة - المولود: $genderInfo${newId.isNotEmpty ? ' - رقم: $newId' : ''}';
                        return newEvent;
                      }
                      return event;
                    }).toList();
                    ref
                        .read(cowProvider.notifier)
                        .updateCow(cow.copyWith(history: newHistory));
                  }
                }
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCalf(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> calf,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف سجل العجل'),
        content: Text(
          'هل أنت متأكد من حذف سجل العجل رقم "${calf['calfId'] ?? 'بدون رقم'}"؟',
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
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (calf['isStandalone'] == true) {
      ref.read(cowProvider.notifier).deleteCow(calf['uniqueKey']);
    } else {
      final cows = ref.read(cowProvider);
      final cowIndex = cows.indexWhere(
        (c) => c.uniqueKey == calf['motherUniqueKey'],
      );
      if (cowIndex != -1) {
        final cow = cows[cowIndex];
        final newHistory = cow.history.where((event) {
          return !_matchBirthEvent(
            event,
            calf['eventId'],
            calf['originalEventDate'],
          );
        }).toList();
        ref
            .read(cowProvider.notifier)
            .updateCow(cow.copyWith(history: newHistory));
      }
    }
  }

  void _showCalfOptions(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> calf,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            'خيارات المولود #${calf['calfId'] ?? "بدون رقم"}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.blue),
            title: const Text(
              'تعديل البيانات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _editCalf(context, ref, calf);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'حذف السجل',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _deleteCalf(context, ref, calf);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _moveToHerd(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> calf,
  ) async {
    DateTime selectedInsemDate = DateTime.now();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(
            'تلقيح ونقل للقطيع',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'سيتم نقل العجولة رقم ${calf['calfId']} إلى قائمة الأبقار بعد تسجيل أول تلقيح لها.',
              ),
              const SizedBox(height: 20),
              CustomDatePickerField(
                label: 'تاريخ التلقيح',
                initialDate: selectedInsemDate,
                firstDate: calf['date'],
                onDateSelected: (date) => selectedInsemDate = date,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('تأكيد التلقيح والنقل'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    if (calf['isStandalone'] == true) {
      final cows = ref.read(cowProvider);
      final cow = cows.firstWhere((c) => c.uniqueKey == calf['uniqueKey']);
      ref
          .read(cowProvider.notifier)
          .updateCow(
            cow.copyWith(
              isStandaloneCalf: false,
              isManualCow: false, // تضاف كبكيرة
              isInseminated: true,
              inseminationDate: selectedInsemDate,
              history: [
                ...cow.history,
                {
                  'title': 'تلقيح أول (انتقال للقطيع)',
                  'date': selectedInsemDate.toIso8601String(),
                  'note': 'تم التلقيح الأول ونقلها لقطيع الأبقار.',
                },
              ],
            ),
          );
    } else {
      final cows = ref.read(cowProvider);
      final motherIndex = cows.indexWhere(
        (c) => c.uniqueKey == calf['motherUniqueKey'],
      );
      if (motherIndex != -1) {
        final mother = cows[motherIndex];
        final newMotherHistory = mother.history.map((event) {
          if (_matchBirthEvent(
            event,
            calf['eventId'],
            calf['originalEventDate'],
          )) {
            final newEvent = Map<String, dynamic>.from(event);
            newEvent['isExited'] = true;
            newEvent['exitReason'] = 'انتقال للقطيع (تلقيح)';
            newEvent['exitDate'] = DateTime.now().toIso8601String();
            return newEvent;
          }
          return event;
        }).toList();
        await ref
            .read(cowProvider.notifier)
            .updateCow(mother.copyWith(history: newMotherHistory));

        final newCow = Cow(
          id: calf['calfId'] ?? 'عجولة جديدة',
          inseminationDate: selectedInsemDate,
          dateOfBirth: calf['date'],
          colorValue: calf['calfColorValue'],
          motherId: mother.id,
          motherColorValue: mother.colorValue,
          isInseminated: true,
          isStandaloneCalf: false,
          isManualCow: false, // تضاف كبكيرة
          history: [
            {
              'title': 'تلقيح أول (انتقال من العجولات)',
              'date': selectedInsemDate.toIso8601String(),
              'note': 'تم النقل من سجل المواليد بعد التلقيح الأول.',
            },
          ],
        );
        await ref.read(cowProvider.notifier).addCow(newCow);
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم نقل العجولة رقم ${calf['calfId']} إلى قطيع الأبقار بنجاح.',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawCalves = ref.watch(allCalvesProvider);

    List<Map<String, dynamic>> calves = rawCalves
        .map(
          (c) => {
            ...c,
            'date': DateTime.parse(c['date'].toString()),
            'eventId': c['eventId']?.toString() ?? c['date'].toString(),
            'calfColorValue':
                c['calfColorValue'] ??
                (c['note'].toString().contains('ذكر')
                    ? Colors.blue.toARGB32()
                    : Colors.pink.toARGB32()),
          },
        )
        .toList();

    final totalCount = calves.where((c) => c['isExited'] != true).length;
    final maleCount = calves
        .where(
          (c) => c['isExited'] != true && c['note'].toString().contains('ذكر'),
        )
        .length;
    final femaleCount = calves
        .where(
          (c) => c['isExited'] != true && !c['note'].toString().contains('ذكر'),
        )
        .length;
    final exitedCount = calves.where((c) => c['isExited'] == true).length;

    if (_currentFilter == CalfFilter.male) {
      calves = calves
          .where(
            (c) =>
                c['isExited'] != true && c['note'].toString().contains('ذكر'),
          )
          .toList();
    } else if (_currentFilter == CalfFilter.female) {
      calves = calves
          .where(
            (c) =>
                c['isExited'] != true && !c['note'].toString().contains('ذكر'),
          )
          .toList();
    } else if (_currentFilter == CalfFilter.exited) {
      calves = calves.where((c) => c['isExited'] == true).toList();
    } else {
      calves = calves.where((c) => c['isExited'] != true).toList();
    }

    if (_currentSort == CalfSort.newest) {
      calves.sort((a, b) => b['date'].compareTo(a['date']));
    } else {
      calves.sort((a, b) => a['date'].compareTo(b['date']));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة العجول والمواليد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsScreen()),
          ),
        ),
        actions: [
          PopupMenuButton<CalfSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) => setState(() => _currentSort = sort),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: CalfSort.newest,
                child: Text('الأحدث أولاً'),
              ),
              PopupMenuItem(
                value: CalfSort.oldest,
                child: Text('الأقدم أولاً'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                showSearch(context: context, delegate: CalfSearchDelegate(ref)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, size: 28, color: Colors.blueAccent),
            tooltip: 'إضافة عجل/عجولة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddCalfScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('الكل ($totalCount)', CalfFilter.active),
                  const SizedBox(width: 8),
                  _buildFilterChip('عجول ذكور ($maleCount)', CalfFilter.male),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'عجلات إناث ($femaleCount)',
                    CalfFilter.female,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'المستبعدة ($exitedCount)',
                    CalfFilter.exited,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: calves.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد سجلات مواليد حالياً',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: calves.length,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemBuilder: (context, index) {
                      final calf = calves[index];
                      final isMale = calf['note'].toString().contains('ذكر');
                      final calfId = calf['calfId'];
                      final calfColor = Color(calf['calfColorValue']);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: calfColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CalfDetailScreen(calfData: calf),
                            ),
                          ),
                          onLongPress: () =>
                              _showCalfOptions(context, ref, calf),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CowIdBadge(
                                  id: calfId?.toString() ?? '?',
                                  color: calfColor,
                                  boxSize: 18,
                                  padding: const EdgeInsets.all(8),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${calf['isStandalone'] == true ? "شراء" : "مولود"} #${calfId ?? "بدون"}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'العمر: ${_calculateAge(calf['date'])}',
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (calf['motherId'] != null)
                                        Row(
                                          children: [
                                            const Text(
                                              'الأم: ',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            CowIdBadge(
                                              id: calf['motherId'].toString(),
                                              color: calf['motherColor'],
                                              fontSize: 12,
                                              boxSize: 12,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                if (!isMale &&
                                    calf['isExited'] != true &&
                                    _calculateAgeInDays(calf['date']) >= 365)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.upgrade,
                                      color: Colors.teal,
                                    ),
                                    onPressed: () =>
                                        _moveToHerd(context, ref, calf),
                                    tooltip: 'تلقيح ونقل للقطيع',
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMale
                                        ? Colors.blue.shade300
                                        : Colors.pink.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isMale ? 'ذكر' : 'أنثى',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, CalfFilter filter) {
    final isSelected = _currentFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _currentFilter = filter),
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      checkmarkColor: Colors.blue,
    );
  }
}
