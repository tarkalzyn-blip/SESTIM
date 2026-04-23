import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:intl/intl.dart';

enum CalfSort { newest, oldest }
enum CalfFilter { all, male, female }

class CalvesScreen extends ConsumerStatefulWidget {
  const CalvesScreen({super.key});

  @override
  ConsumerState<CalvesScreen> createState() => _CalvesScreenState();
}

class _CalvesScreenState extends ConsumerState<CalvesScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  CalfSort _currentSort = CalfSort.newest;
  CalfFilter _currentFilter = CalfFilter.all;

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

  void _editCalf(BuildContext context, WidgetRef ref, String motherUniqueKey, DateTime birthDate, String? currentCalfId, int? currentColorValue) {
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
                    if (event['title'] == 'تسجيل ولادة' && event['date'] == birthDate.toIso8601String()) {
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

  @override
  Widget build(BuildContext context) {
    final cows = ref.watch(cowProvider);
    
    List<Map<String, dynamic>> calves = [];
    for (var cow in cows) {
      for (var event in cow.history) {
        if (event['title'] == 'تسجيل ولادة') {
          calves.add({
            'date': DateTime.parse(event['date']),
            'calfId': event['calfId'],
            'calfColorValue': event['calfColorValue'] ?? (event['note'].toString().contains('ذكر') ? Colors.blue.toARGB32() : Colors.pink.toARGB32()),
            'note': event['note'] ?? '',
            'motherId': cow.id,
            'motherUniqueKey': cow.uniqueKey,
            'motherColor': cow.color,
          });
        }
      }
    }
    
    final exactMatch = AppSettings.exactSearchMatch;
    final query = _searchController.text.trim();

    final totalCount = calves.length;
    final maleCount = calves.where((calf) => calf['note'].toString().contains('ذكر')).length;
    final femaleCount = calves.where((calf) => !calf['note'].toString().contains('ذكر')).length;

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
      calves = calves.where((calf) => calf['note'].toString().contains('ذكر')).toList();
    } else if (_currentFilter == CalfFilter.female) {
      calves = calves.where((calf) => !calf['note'].toString().contains('ذكر')).toList();
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
                  _buildFilterChip('الكل ($totalCount)', CalfFilter.all),
                  const SizedBox(width: 8),
                  _buildFilterChip('عجول ذكور ($maleCount)', CalfFilter.male),
                  const SizedBox(width: 8),
                  _buildFilterChip('عجلات إناث ($femaleCount)', CalfFilter.female),
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
                            elevation: 2,
                            child: InkWell(
                              onLongPress: () => _editCalf(context, ref, calf['motherUniqueKey'], calf['date'], calfId, calf['calfColorValue']),
                              borderRadius: BorderRadius.circular(15),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: calfColor.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: calfColor, width: 2),
                                      ),
                                      child: Icon(
                                        isMale ? Icons.male : Icons.female,
                                        color: calfColor,
                                        size: 28,
                                      ),
                                    ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          calfId != null ? 'مولود #$calfId' : (isMale ? 'عجل (ذكر)' : 'عجولة (أنثى)'),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                        if (calfId != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            isMale ? '(ذكر)' : '(أنثى)',
                                            style: TextStyle(color: isMale ? Colors.blue : Colors.pink, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
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
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editCalf(context, ref, calf['motherUniqueKey'], calf['date'], calfId, calf['calfColorValue']),
                              ),
                            ],
                          ),
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
