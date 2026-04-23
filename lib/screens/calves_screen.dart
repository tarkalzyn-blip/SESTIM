import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/screens/calf_detail_screen.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';

enum CalfSort { newest, oldest }
enum CalfFilter { active, male, female, exited }

class CalvesScreen extends ConsumerStatefulWidget {
  const CalvesScreen({super.key});

  @override
  ConsumerState<CalvesScreen> createState() => _CalvesScreenState();
}

class _CalvesScreenState extends ConsumerState<CalvesScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  CalfSort _currentSort = CalfSort.newest;
  CalfFilter _currentFilter = CalfFilter.active;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final days = difference.inDays;
    
    if (days < 30) return '$days يوم';
    final months = days ~/ 30;
    final remainingDays = days % 30;
    if (remainingDays == 0) return '$months شهر';
    return '$months شهر و $remainingDays يوم';
  }

  /// Matches a Hive history event to a calf by trying 3 strategies:
  /// 1. eventId match (new records)
  /// 2. Exact date string match
  /// 3. DateTime milliseconds match (handles format differences from Hive)
  bool _matchBirthEvent(dynamic event, String eventId, String originalEventDate) {
    final title = event['title']?.toString() ?? '';
    if (title != 'تسجيل ولادة' && title != 'تسجيل ولادة سابقة') return false;
    final storedEvId = event['eventId']?.toString();
    // Strategy 1: eventId (reliable for new records)
    if (storedEvId != null && storedEvId == eventId) return true;
    // Strategy 2: exact string
    if (event['date']?.toString() == originalEventDate) return true;
    // Strategy 3: DateTime comparison (handles timezone/format drift from Hive)
    try {
      final a = DateTime.parse(event['date'].toString());
      final b = DateTime.parse(originalEventDate);
      if (a.millisecondsSinceEpoch == b.millisecondsSinceEpoch) return true;
    } catch (_) {}
    return false;
  }

  void _editCalf(BuildContext context, WidgetRef ref, String motherUniqueKey, String eventId, String originalEventDate, String? currentCalfId, int? currentColorValue) {
    final controller = TextEditingController(text: currentCalfId ?? '');
    int selectedColorValue = currentColorValue ?? Colors.blue.toARGB32();
    final List<Color> _colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, 
      Colors.purple, Colors.teal, Colors.pink, Colors.brown
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('تعديل بيانات المولود', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'رقم المولود',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.tag),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              const Text('لون الكرت:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colors.map((color) {
                  bool isSelected = selectedColorValue == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setStateDialog(() => selectedColorValue = color.toARGB32()),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 40 : 32,
                      height: isSelected ? 40 : 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: isSelected ? [
                          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)
                        ] : [],
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final cows = ref.read(cowProvider);
                final cowIndex = cows.indexWhere((c) => c.uniqueKey == motherUniqueKey);
                if (cowIndex != -1) {
                  final cow = cows[cowIndex];
                  final newHistory = cow.history.map((event) {
                    if (_matchBirthEvent(event, eventId, originalEventDate)) {
                      final Map<String, dynamic> newEvent = Map.from(event);
                      final String newId = controller.text.trim();
                      newEvent['calfId'] = newId.isEmpty ? null : newId;
                      newEvent['calfColorValue'] = selectedColorValue;
                      
                      // Update note if gender info is there
                      String genderInfo = event['note'].toString().contains('ذكر') ? 'ذكر' : 'أنثى';
                      newEvent['note'] = 'ولادة - المولود: $genderInfo${newId.isNotEmpty ? ' - رقم: $newId' : ''}';
                      return newEvent;
                    }
                    return event;
                  }).toList();
                  
                  ref.read(cowProvider.notifier).updateCow(cow.copyWith(history: newHistory));
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

  void _deleteCalf(BuildContext context, WidgetRef ref, String motherUniqueKey, String eventId, String originalEventDate, String? calfId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف سجل العجل'),
        content: Text('هل أنت متأكد من حذف سجل العجل رقم "${calfId ?? 'بدون رقم'}"؟ لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final cows = ref.read(cowProvider);
    final cowIndex = cows.indexWhere((c) => c.uniqueKey == motherUniqueKey);
    if (cowIndex == -1) return;

    final cow = cows[cowIndex];
    final newHistory = cow.history.where((event) {
      return !_matchBirthEvent(event, eventId, originalEventDate);
    }).toList();

    ref.read(cowProvider.notifier).updateCow(cow.copyWith(history: newHistory));
  }

  @override
  Widget build(BuildContext context) {
    final cows = ref.watch(cowProvider);
    
    List<Map<String, dynamic>> calves = [];
    for (var cow in cows) {
      for (var event in cow.history) {
        final title = event['title']?.toString() ?? '';
        if (title == 'تسجيل ولادة' || title == 'تسجيل ولادة سابقة') {
          calves.add({
            'date': DateTime.parse(event['date']),
            'originalEventDate': event['date'],
            'eventId': event['eventId']?.toString() ?? event['date'].toString(), // unique key for matching
            'calfId': event['calfId'],
            'calfColorValue': event['calfColorValue'] ?? (event['note'].toString().contains('ذكر') ? Colors.blue.toARGB32() : Colors.pink.toARGB32()),
            'note': event['note'] ?? '',
            'motherId': cow.id,
            'motherUniqueKey': cow.uniqueKey,
            'motherColor': cow.color,
            'isExited': event['isExited'] ?? false,
            'exitReason': event['exitReason'],
            'exitPrice': event['exitPrice'],
            'exitDate': event['exitDate'],
            'weights': event['weights'] ?? [],
            'vaccines': event['vaccines'] ?? [],
          });
        }
      }
    }
    
    final exactMatch = AppSettings.exactSearchMatch;
    final query = _searchController.text.trim();

    final totalCount = calves.where((c) => c['isExited'] != true).length;
    final maleCount = calves.where((c) => c['isExited'] != true && c['note'].toString().contains('ذكر')).length;
    final femaleCount = calves.where((c) => c['isExited'] != true && !c['note'].toString().contains('ذكر')).length;
    final exitedCount = calves.where((c) => c['isExited'] == true).length;

    if (query.isNotEmpty) {
      calves = calves.where((calf) {
        final calfId = calf['calfId']?.toString() ?? '';
        final motherId = calf['motherId']?.toString() ?? '';
        
        if (exactMatch) {
          return calfId == query || motherId == query;
        } else {
          return calfId.contains(query) || motherId.contains(query);
        }
      }).toList();
    }

    if (_currentFilter == CalfFilter.male) {
      calves = calves.where((calf) => calf['isExited'] != true && calf['note'].toString().contains('ذكر')).toList();
    } else if (_currentFilter == CalfFilter.female) {
      calves = calves.where((calf) => calf['isExited'] != true && !calf['note'].toString().contains('ذكر')).toList();
    } else if (_currentFilter == CalfFilter.exited) {
      calves = calves.where((calf) => calf['isExited'] == true).toList();
    } else {
      // active
      calves = calves.where((calf) => calf['isExited'] != true).toList();
    }

    if (_currentSort == CalfSort.newest) {
      calves.sort((a, b) => b['date'].compareTo(a['date']));
    } else {
      calves.sort((a, b) => a['date'].compareTo(b['date']));
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ابحث برقم العجل/الأم...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {});
                },
              )
            : const Text('سجل المواليد (العجول)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: !_isSearching,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  if (_searchController.text.isEmpty) {
                    _isSearching = false;
                  } else {
                    _searchController.clear();
                  }
                });
              },
            )
          else ...[
            PopupMenuButton<CalfSort>(
              icon: const Icon(Icons.sort),
              tooltip: 'ترتيب العجول',
              onSelected: (sort) {
                setState(() {
                  _currentSort = sort;
                });
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: CalfSort.newest, child: Text('الأحدث أولاً')),
                PopupMenuItem(value: CalfSort.oldest, child: Text('الأقدم أولاً')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('الكل ($totalCount)', CalfFilter.active),
                  const SizedBox(width: 8),
                  _buildFilterChip('عجول ذكور ($maleCount)', CalfFilter.male),
                  const SizedBox(width: 8),
                  _buildFilterChip('عجلات إناث ($femaleCount)', CalfFilter.female),
                  const SizedBox(width: 8),
                  _buildFilterChip('المستبعدة ($exitedCount)', CalfFilter.exited),
                ],
              ),
            ),
          ),
          Expanded(
            child: calves.isEmpty
                ? Center(
                    child: Text(
                      _isSearching ? 'لا توجد نتائج مطابقة للبحث' : 'لا توجد سجلات مواليد حالياً',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: calves.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final calf = calves[index];
                      final isMale = calf['note'].toString().contains('ذكر');
                      final calfId = calf['calfId'];
                      final calfColor = Color(calf['calfColorValue']);
                      
                      return Column(
                        children: [
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(color: calfColor.withValues(alpha: 0.3), width: 1),
                            ),
                            elevation: calf['isExited'] == true ? 0 : 2,
                            color: calf['isExited'] == true ? Colors.grey.withValues(alpha: 0.1) : null,
                            child: InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CalfDetailScreen(calfData: calf),
                                  ),
                                );
                                // Refresh UI if state changed
                                setState(() {});
                              },
                              onLongPress: () => _editCalf(context, ref, calf['motherUniqueKey'], calf['eventId'], calf['originalEventDate'], calfId, calf['calfColorValue']),
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: calf['isExited'] == true ? Colors.grey.withValues(alpha: 0.2) : calfColor.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: calf['isExited'] == true ? Colors.grey : calfColor, width: 2),
                                          ),
                                          child: Text(
                                            calfId?.toString() ?? '?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: calf['isExited'] == true ? Colors.grey : calfColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'مولود #${calfId ?? "بدون"}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      decoration: calf['isExited'] == true ? TextDecoration.lineThrough : null,
                                                      color: calf['isExited'] == true ? Colors.grey : null,
                                                    ),
                                                  ),
                                                  if (calf['isExited'] == true) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                                      child: Text(calf['exitReason'] ?? 'مستبعد', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    )
                                                  ]
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text('العمر: ${_calculateAge(calf['date'])}', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.female, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  const Text('الأم: ', style: TextStyle(fontSize: 12)),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: calf['motherColor'].withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '#${calf['motherId']}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: calf['motherColor'],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                                          tooltip: 'تعديل',
                                          onPressed: () => _editCalf(context, ref, calf['motherUniqueKey'], calf['eventId'], calf['originalEventDate'], calfId, calf['calfColorValue']),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                          tooltip: 'حذف',
                                          onPressed: () => _deleteCalf(context, ref, calf['motherUniqueKey'], calf['eventId'], calf['originalEventDate'], calfId),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PositionedDirectional(
                                    top: 0,
                                    end: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: calf['isExited'] == true ? Colors.grey : (isMale ? Colors.blue.shade300 : Colors.pink.shade300),
                                        borderRadius: const BorderRadiusDirectional.only(
                                          bottomStart: Radius.circular(15),
                                        ),
                                      ),
                                      child: Text(
                                        isMale ? 'ذكر' : 'أنثى',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    if (index == calves.length - 1) const SizedBox(height: 100),
                  ],
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
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = filter);
        }
      },
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }
}
