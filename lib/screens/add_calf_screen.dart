import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/providers/settings_provider.dart';
import 'package:cow_pregnancy/widgets/custom_date_picker.dart';

class AddCalfScreen extends ConsumerStatefulWidget {
  const AddCalfScreen({super.key});

  @override
  ConsumerState<AddCalfScreen> createState() => _AddCalfScreenState();
}

class _AddCalfScreenState extends ConsumerState<AddCalfScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _motherIdController = TextEditingController();
  final _noteController = TextEditingController();

  String _gender = 'female';
  DateTime _birthDate = DateTime.now();
  int? _selectedColorValue;
  int? _selectedMotherColorValue;

  @override
  void dispose() {
    _idController.dispose();
    _motherIdController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final availableColors = ref.read(cowColorsProvider);
    final colorValue = _selectedColorValue ?? (availableColors.isNotEmpty ? availableColors.first : Colors.blue.toARGB32());

    final newCalf = Cow(
      id: _idController.text.trim(),
      inseminationDate: _birthDate,
      dateOfBirth: _birthDate,
      colorValue: colorValue,
      gender: _gender,
      isStandaloneCalf: true,
      isInseminated: false,
      motherId: _motherIdController.text.trim().isEmpty ? null : _motherIdController.text.trim(),
      motherColorValue: _selectedMotherColorValue,
      history: [
        {
          'title': 'شراء عجل',
          'date': DateTime.now().toIso8601String(),
          'note': _noteController.text.trim().isEmpty
              ? (_gender == 'female' ? 'تم شراء عجولة وإضافتها للقطيع' : 'تم شراء عجل وإضافته للقطيع')
              : _noteController.text.trim(),
        }
      ],
    );

    ref.read(cowProvider.notifier).addCow(newCalf);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_gender == 'female' ? 'تم إضافة العجولة بنجاح ✓' : 'تم إضافة العجل بنجاح ✓'),
        backgroundColor: Colors.teal,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final availableColors = ref.watch(cowColorsProvider);
    if (_selectedColorValue == null && availableColors.isNotEmpty) {
      _selectedColorValue = availableColors.first;
    }

    final isFemale = _gender == 'female';
    final accentColor = isFemale ? Colors.pinkAccent : Colors.blueAccent;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFemale ? 'إضافة عجولة (أنثى)' : 'إضافة عجل (ذكر)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Gender Selection ──────────────────────────────────────
            _buildSectionTitle('الجنس', Icons.wc),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildGenderCard(
                    label: 'أنثى (عجولة)',
                    icon: '🐄',
                    value: 'female',
                    color: Colors.pinkAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderCard(
                    label: 'ذكر (عجل)',
                    icon: '🐂',
                    value: 'male',
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // ── Basic Info ────────────────────────────────────────────
            _buildSectionTitle('المعلومات الأساسية', Icons.info_outline),
            const SizedBox(height: 16),

            TextFormField(
              controller: _idController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: isFemale ? 'رقم/اسم العجولة *' : 'رقم/اسم العجل *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.tag),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
            ),

            const SizedBox(height: 16),

            CustomDatePickerField(
              label: 'تاريخ الميلاد (تقريبي إن لم يكن معروفاً)',
              initialDate: _birthDate,
              onDateSelected: (date) => setState(() => _birthDate = date),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              maxLines: 2,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                hintText: 'مثال: تم شراؤه من مزرعة XYZ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.note_outlined),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // ── Mother Info ───────────────────────────────────────────
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
                  title: _buildSectionTitle('معلومات الأم (اختياري)', Icons.family_restroom),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextFormField(
                      controller: _motherIdController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'رقم/اسم الأم (إن كانت في المزرعة)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.tag_outlined),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    if (availableColors.isNotEmpty) ...[
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
            const SizedBox(height: 12),

            // ── Card Color ────────────────────────────────────────────
            _buildSectionTitle('لون كرت العجل/العجولة', Icons.palette_outlined),
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
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // ── Save Button ───────────────────────────────────────────
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  isFemale ? 'إضافة العجولة' : 'إضافة العجل',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderCard({
    required String label,
    required String icon,
    required String value,
    required Color color,
  }) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
                fontSize: 14,
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
