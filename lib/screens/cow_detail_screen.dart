import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AddEditCowScreen(cow: cow),
                  ));
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
                      content: Text('هل أنت متأكد من حذف البقرة رقم ${cow.id}؟ لا يمكن التراجع عن هذا.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref.read(cowProvider.notifier).deleteCow(cow.uniqueKey);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text('بقرة #${cow.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Hero(
                tag: 'cow_card_${cow.uniqueKey}',
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cow.color, cow.color.withValues(alpha: 0.6)],
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
                  if (cow.isPostBirth) ...[
                    _buildDetailRow('تاريخ الولادة', DateFormat('yyyy-MM-dd').format(cow.birthDate!), Icons.child_care, subTextColor: subTextColor, textColor: textColor),
                    const SizedBox(height: 20),
                    _buildDetailRow('أيام منذ الولادة', '${cow.daysSinceBirth} يوم', Icons.timer, subTextColor: subTextColor, textColor: textColor),
                  ] else ...[
                    _buildDetailRow(cow.isInseminated ? 'تاريخ التلقيح' : 'تاريخ آخر شبق', DateFormat('yyyy-MM-dd').format(cow.inseminationDate), Icons.calendar_today, subTextColor: subTextColor, textColor: textColor),
                    const SizedBox(height: 20),
                    _buildDetailRow('الأيام المنقضية', '${cow.daysSinceInsemination} يوم', Icons.timer, subTextColor: subTextColor, textColor: textColor),
                  ],
                  if (cow.bullId != null && cow.bullId!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailRow('معلومات الطلوقة', cow.bullId!, Icons.pets, color: Colors.blueGrey, subTextColor: subTextColor),
                  ],
                  if (cow.motherId != null && cow.motherId!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.family_restroom, color: Colors.blueGrey, size: 28),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رقم الأم', style: TextStyle(fontSize: 14, color: subTextColor)),
                            Row(
                              children: [
                                Text(cow.motherId!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                if (cow.motherColorValue != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 16, height: 16,
                                    decoration: BoxDecoration(color: Color(cow.motherColorValue!), shape: BoxShape.circle),
                                  )
                                ]
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildDetailRow('الحالة الحالية', cow.status, Icons.info_outline, color: cow.color, subTextColor: subTextColor),
                  const SizedBox(height: 40),
                  const Text('نسبة تقدم الحمل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: cow.pregnancyPercentage),
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
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                              color: cow.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cow.color)),
                        ],
                      );
                    },
                  ),
                  if (cow.isInseminated && !cow.isPostBirth) ...[
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          // منع تسجيل الولادة المبكرة (أكثر من 20 يوم متبقي)
                          final daysRemaining = AppSettings.pregnancyDays - cow.daysSinceInsemination;
                          if (daysRemaining > 20) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('تسجيل ولادة مبكرة', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                content: Text(
                                  'هذه البقرة تحتاج $daysRemaining يوماً حتى موعد الولادة المتوقع.\n\n'
                                  'لا يمكن تسجيل ولادة إلا خلال آخر 20 يوم من الحمل.\n\n'
                                  'إذا ولدت فعلاً، استخدم زر التعديل ✏️ لتصحيح تاريخ التلقيح.',
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
                          final List<Color> _colors = [
                            Colors.blue, Colors.red, Colors.green, Colors.orange, 
                            Colors.purple, Colors.teal, Colors.pink, Colors.brown
                          ];

                          showDialog(
                            context: context,
                            builder: (ctx) {
                              return StatefulBuilder(
                                builder: (context, setStateDialog) {
                                  return AlertDialog(
                                    title: const Text('تسجيل ولادة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('رقم المولود (اختياري):', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: calfIdController,
                                            decoration: InputDecoration(
                                              hintText: 'أدخل رقم المولود الجديد',
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              prefixIcon: const Icon(Icons.tag),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text('تاريخ الولادة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          ListTile(
                                            shape: RoundedRectangleBorder(
                                              side: BorderSide(color: Colors.grey.shade400),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            leading: const Icon(Icons.calendar_today, color: Colors.teal),
                                            title: Text(DateFormat('yyyy-MM-dd').format(selectedBirthDate)),
                                            onTap: () async {
                                              final date = await showDatePicker(
                                                context: context,
                                                initialDate: selectedBirthDate,
                                                firstDate: cow.inseminationDate,
                                                lastDate: DateTime.now(),
                                              );
                                              if (date != null) {
                                                setStateDialog(() => selectedBirthDate = date);
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 20),
                                          const Text('جنس المولود:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ChoiceChip(
                                                  label: const Center(child: Text('أنثى 🐄', style: TextStyle(fontSize: 16))),
                                                  selected: selectedGender == 'أنثى',
                                                  selectedColor: Colors.pink.shade100,
                                                  onSelected: (val) => setStateDialog(() => selectedGender = 'أنثى'),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ChoiceChip(
                                                  label: const Center(child: Text('ذكر 🐂', style: TextStyle(fontSize: 16))),
                                                  selected: selectedGender == 'ذكر',
                                                  selectedColor: Colors.blue.shade100,
                                                  onSelected: (val) => setStateDialog(() => selectedGender = 'ذكر'),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          const Text('اللون المميز للعجل/العجولة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: _colors.map((color) {
                                              bool isSelected = selectedCalfColorValue == color.toARGB32();
                                              return GestureDetector(
                                                onTap: () => setStateDialog(() => selectedCalfColorValue = color.toARGB32()),
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
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                                      FilledButton(
                                        onPressed: () {
                                          List<dynamic> newHistory = cow.history.toList();
                                          String calfId = calfIdController.text.trim();
                                          newHistory.add({
                                            'title': 'تسجيل ولادة',
                                            'date': selectedBirthDate.toIso8601String(),
                                            'calfId': calfId.isEmpty ? null : calfId,
                                            'calfColorValue': selectedCalfColorValue,
                                            'note': 'ولادة بعد ${selectedBirthDate.difference(cow.inseminationDate).inDays} يوم - المولود: $selectedGender${calfId.isNotEmpty ? ' - رقم: $calfId' : ''}',
                                          });
                                          ref.read(cowProvider.notifier).updateCow(
                                            cow.copyWith(birthDate: selectedBirthDate, history: newHistory)
                                          );
                                          Navigator.pop(ctx);
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('تم تسجيل ولادة ${calfId.isNotEmpty ? "المولود رقم $calfId" : "المولود"} بنجاح.'),
                                              backgroundColor: Colors.green,
                                            )
                                          );
                                        },
                                        child: const Text('تأكيد وتسجيل', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  );
                                }
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.child_friendly),
                        label: const Text('تسجيل ولادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  const Text('السجل التاريخي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (cow.history.isEmpty)
                    const Text('لا يوجد سجلات سابقة', style: TextStyle(color: Colors.grey))
                  else
                    ...cow.history.reversed.map((event) => _buildHistoryItem(event, subTextColor)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryItem(dynamic event, Color subTextColor) {
    DateTime date = DateTime.parse(event['date']);
    String title = event['title'] ?? 'حدث';
    String note = event['note'] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle)),
              Container(width: 2, height: 40, color: Colors.teal.withValues(alpha: 0.3)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(DateFormat('yyyy-MM-dd').format(date), style: TextStyle(color: subTextColor, fontSize: 13)),
                if (note.isNotEmpty)
                  Text(note, style: TextStyle(color: subTextColor)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon, {Color? color, Color? subTextColor, Color? textColor}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey.shade700, size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, color: subTextColor ?? Colors.grey.shade600)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? textColor)),
          ],
        )
      ],
    );
  }
}
