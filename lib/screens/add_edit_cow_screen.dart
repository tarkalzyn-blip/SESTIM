import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/widgets/custom_date_picker.dart';
import 'package:cow_pregnancy/providers/settings_provider.dart';
import 'package:intl/intl.dart';

enum CowFormState { pregnant, heat, postBirth }

class AddEditCowScreen extends ConsumerStatefulWidget {
  final Cow? cow;
  const AddEditCowScreen({super.key, this.cow});

  @override
  ConsumerState<AddEditCowScreen> createState() => _AddEditCowScreenState();
}

class _AddEditCowScreenState extends ConsumerState<AddEditCowScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _bullIdController;
  late TextEditingController _motherIdController;

  CowFormState _currentState = CowFormState.pregnant;
  DateTime _selectedDate = DateTime.now();
  DateTime? _dateOfBirth;
  DateTime? _lastBirthDate; // تاريخ آخر ولادة (للبقرات الوالدات)
  int _selectedColorValue = 0;
  int? _selectedMotherColorValue;

  bool get _isEditing => widget.cow != null;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.cow?.id ?? '');
    _bullIdController = TextEditingController(text: widget.cow?.bullId ?? '');
    _motherIdController = TextEditingController(text: widget.cow?.motherId ?? '');
    _selectedMotherColorValue = widget.cow?.motherColorValue;

    final colors = ref.read(cowColorsProvider);
    if (widget.cow != null) {
      _selectedColorValue = widget.cow!.colorValue;
      _dateOfBirth = widget.cow!.dateOfBirth;
      if (widget.cow!.isPostBirth) {
        _currentState = CowFormState.postBirth;
        _selectedDate = widget.cow!.birthDate!;
      } else if (widget.cow!.isInseminated) {
        _currentState = CowFormState.pregnant;
        _selectedDate = widget.cow!.inseminationDate;
      } else {
        _currentState = CowFormState.heat;
        _selectedDate = widget.cow!.inseminationDate;
      }
      // استخراج تاريخ آخر ولادة من السجل
      final birthEvents = widget.cow!.history.where((e) {
        final t = e['title']?.toString() ?? '';
        return t.contains('ولادة') && !t.contains('سابقة');
      }).toList();
      if (birthEvents.isNotEmpty) {
        try {
          birthEvents.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          _lastBirthDate = DateTime.parse(birthEvents.first['date']);
        } catch (_) {}
      }
    } else {
      _selectedColorValue = colors.isNotEmpty ? colors.first : Colors.blue.toARGB32();
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _bullIdController.dispose();
    _motherIdController.dispose();
    super.dispose();
  }

  /// بناء نص السياق الذكي للتلقيح
  String _buildInseminationNote() {
    final cow = widget.cow;
    final List<String> parts = [];

    // 1. هل هي بكيرة (وصلت لصفحة الأبقار من العجول ولم تلد بعد)؟
    bool isHeifer = cow != null && !cow.hasGivenBirth && !cow.isStandaloneCalf;

    // 2. هل وُلدت مؤخراً (آخر ولادة موجودة في السجل)؟
    DateTime? lastBirth = _lastBirthDate;
    if (lastBirth == null && cow != null) {
      final births = cow.history.where((e) {
        final t = e['title']?.toString() ?? '';
        return t.contains('ولادة') && !t.contains('سابقة');
      }).toList();
      if (births.isNotEmpty) {
        try {
          births.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          lastBirth = DateTime.parse(births.first['date']);
        } catch (_) {}
      }
    }

    if (lastBirth != null) {
      final daysSinceBirth = _selectedDate.difference(lastBirth).inDays;
      parts.add('تم التلقيح بعد الولادة بـ $daysSinceBirth يوم');
    }

    // 3. إذا بكيرة - احسب عمرها عند التلقيح
    if (isHeifer && _dateOfBirth != null) {
      final ageAtInsem = _selectedDate.difference(_dateOfBirth!).inDays;
      final years = ageAtInsem ~/ 365;
      final months = (ageAtInsem % 365) ~/ 30;
      final days = ageAtInsem % 30;
      String ageStr = '';
      if (years > 0) ageStr += '$years سنة';
      if (months > 0) ageStr += ' و $months شهر';
      if (days > 0 && years == 0) ageStr += ' و $days يوم';
      parts.add('عمر البكيرة عند التلقيح: $ageStr');
    } else if (!isHeifer && _dateOfBirth != null && lastBirth == null) {
      // بقرة عادية لا نعرف تاريخ ولادتها الأخيرة
      final ageAtInsem = _selectedDate.difference(_dateOfBirth!).inDays;
      final years = ageAtInsem ~/ 365;
      final months = (ageAtInsem % 365) ~/ 30;
      String ageStr = '';
      if (years > 0) ageStr += '$years سنة';
      if (months > 0) ageStr += ' و $months شهر';
      if (ageStr.isNotEmpty) parts.add('عمر البقرة عند التلقيح: $ageStr');
    }

    // 4. تاريخ التلقيح دائماً
    parts.add('تاريخ التلقيح: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');

    if (_bullIdController.text.trim().isNotEmpty) {
      parts.add('رقم العجل: ${_bullIdController.text.trim()}');
    }

    return parts.join(' | ');
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isEditing ? 'تأكيد التعديل' : 'تأكيد الإضافة',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(_isEditing
            ? 'هل أنت متأكد من حفظ التعديلات؟'
            : 'هل أنت متأكد من إضافة هذه البقرة؟'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processSave();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _processSave() {
    bool isInseminated = _currentState == CowFormState.pregnant;
    DateTime inseminationDate = _selectedDate;
    DateTime? birthDate;

    if (_currentState == CowFormState.postBirth) {
      birthDate = _selectedDate;
      inseminationDate = _selectedDate.subtract(const Duration(days: 280));
      isInseminated = false;
    } else if (_currentState == CowFormState.heat) {
      isInseminated = false;
    }

    List<dynamic> history = widget.cow?.history.toList() ?? [];

    // تسجيل الحدث بنص سياق ذكي
    if (!_isEditing ||
        widget.cow!.inseminationDate != inseminationDate ||
        widget.cow!.birthDate != birthDate) {
      String title = '';
      String note = '';

      if (_currentState == CowFormState.pregnant) {
        title = 'تسجيل تلقيح';
        note = _buildInseminationNote();
      } else if (_currentState == CowFormState.heat) {
        title = 'تسجيل شبق';
        note = 'تاريخ آخر شبق: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}';
      } else if (_currentState == CowFormState.postBirth) {
        title = 'تسجيل ولادة';
        note = 'تاريخ الولادة: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}';
      }

      history.add({
        'title': title,
        'date': _selectedDate.toIso8601String(),
        'note': note,
      });
    }

    // أي بقرة تُضاف من صفحة الأبقار → تُعتبر بقرة (Milking) ولا تحتاج لولادة وهمية
    bool isManualCow = !_isEditing; // true if new addition from this screen

    final cow = Cow(
      id: _idController.text.trim(),
      inseminationDate: inseminationDate,
      colorValue: _selectedColorValue,
      isInseminated: isInseminated,
      birthDate: birthDate,
      bullId: _bullIdController.text.trim().isEmpty ? null : _bullIdController.text.trim(),
      motherId: _motherIdController.text.trim().isEmpty ? null : _motherIdController.text.trim(),
      motherColorValue: _selectedMotherColorValue,
      dateOfBirth: _dateOfBirth, // حفظ تاريخ الميلاد
      isStandaloneCalf: widget.cow?.isStandaloneCalf ?? false,
      history: history,
      isManualCow: isManualCow,
    );

    final cows = ref.read(cowProvider);
    if (!_isEditing) {
      if (cows.any((c) => c.uniqueKey == cow.uniqueKey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الرقم موجود مسبقاً!'), backgroundColor: Colors.red),
        );
        return;
      }
      ref.read(cowProvider.notifier).addCow(cow);
    } else {
      if (widget.cow!.uniqueKey != cow.uniqueKey &&
          cows.any((c) => c.uniqueKey == cow.uniqueKey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرقم واللون موجودان مسبقاً!'), backgroundColor: Colors.red),
        );
        return;
      }
      ref.read(cowProvider.notifier).updateCow(cow, oldKey: widget.cow!.uniqueKey);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم الحفظ بنجاح ✓'), backgroundColor: Colors.green),
    );
    Navigator.pop(context);
  }

  CowFormState _determineInitialState(Cow c) {
    if (c.isPostBirth) return CowFormState.postBirth;
    if (c.isInseminated) return CowFormState.pregnant;
    return CowFormState.heat;
  }

  bool get _hasUnsavedChanges {
    if (!_isEditing) {
      return _idController.text.isNotEmpty || 
             _bullIdController.text.isNotEmpty ||
             _motherIdController.text.isNotEmpty;
    } else {
      final c = widget.cow!;
      return _idController.text != c.id ||
             _selectedColorValue != c.colorValue ||
             _dateOfBirth != c.dateOfBirth ||
             _bullIdController.text != (c.bullId ?? '') ||
             _motherIdController.text != (c.motherId ?? '') ||
             _currentState != _determineInitialState(c);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تجاهل التغييرات؟', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text('لقد قمت بإدخال بيانات لم يتم حفظها. هل أنت متأكد أنك تريد الخروج دون حفظ؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('خروج دون حفظ'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final availableColors = ref.watch(cowColorsProvider);
    if (_selectedColorValue == 0 && availableColors.isNotEmpty) {
      _selectedColorValue = availableColors.first;
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? 'تعديل بيانات البقرة' : 'إضافة بقرة جديدة',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Form(
          key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── معلومات الهوية ─────────────────────────────────────────
            _buildSectionTitle('هوية البقرة', Icons.tag),
            const SizedBox(height: 16),

            TextFormField(
              controller: _idController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'رقم/اسم البقرة *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.tag),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
            ),

            const SizedBox(height: 20),

            // ── تاريخ ميلاد البقرة (مُنتقل إلى القسم الرئيسي للوضوح) ──────
            CustomDatePickerField(
              label: 'تاريخ ميلاد البقرة (اختياري)',
              initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 1095)), // افتراضي 3 سنوات للأبقار
              onDateSelected: (date) => setState(() => _dateOfBirth = date),
              color: Colors.purple.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'يُستخدم لحساب عمر البقرة بدقة وتتبع تاريخها الإنتاجي.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── الحالة الحالية ─────────────────────────────────────────
            _buildSectionTitle('الحالة الحالية', Icons.info_outline),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildStateCard(
                  label: 'تم التلقيح',
                  icon: '💉',
                  value: CowFormState.pregnant,
                  color: Colors.blue,
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildStateCard(
                  label: 'انتظار الشبق',
                  icon: '⏳',
                  value: CowFormState.heat,
                  color: Colors.orange,
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildStateCard(
                  label: 'بعد الولادة',
                  icon: '🍼',
                  value: CowFormState.postBirth,
                  color: Colors.teal,
                )),
              ],
            ),

            const SizedBox(height: 20),

            // التاريخ المناسب لكل حالة
            CustomDatePickerField(
              label: _currentState == CowFormState.pregnant
                  ? 'تاريخ التلقيح'
                  : _currentState == CowFormState.heat
                      ? 'تاريخ آخر شبق'
                      : 'تاريخ الولادة',
              initialDate: _selectedDate,
              onDateSelected: (date) => setState(() => _selectedDate = date),
            ),

            if (_currentState == CowFormState.pregnant) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _bullIdController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'رقم/اسم العجل (أو اتركه فارغاً)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.tag_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              // معاينة نص التسجيل الذكي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('سيُسجَّل في السجل:', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            _buildInseminationNote(),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── الأنساب ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white.withOpacity(0.05) 
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: _buildSectionTitle('معلومات الأنساب (اختياري)', Icons.family_restroom),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextFormField(
                      controller: _motherIdController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'رقم/اسم الأم (إن وجدت)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.tag_outlined),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      onChanged: (v) => setState(() {}),
                    ),
                    if (_motherIdController.text.isNotEmpty || _selectedMotherColorValue != null) ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('لون كرت الأم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: availableColors.map((colorVal) {
                            final color = Color(colorVal);
                            final isSelected = _selectedMotherColorValue == colorVal;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedMotherColorValue = colorVal),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 40 : 32,
                                height: isSelected ? 40 : 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                                  boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)] : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // ── لون الكرت ──────────────────────────────────────────────
            _buildSectionTitle('لون الكرت المميز', Icons.palette_outlined),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableColors.map((colorVal) {
                final color = Color(colorVal);
                final isSelected = _selectedColorValue == colorVal;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorValue = colorVal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // ── زر الحفظ ──────────────────────────────────────────────
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _isEditing ? 'حفظ التعديلات' : 'إضافة البقرة',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStateCard({
    required String label,
    required String icon,
    required CowFormState value,
    required Color color,
  }) {
    final isSelected = _currentState == value;
    return GestureDetector(
      onTap: () => setState(() => _currentState = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }
}
