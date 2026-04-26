import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:intl/intl.dart';
import 'package:cow_pregnancy/widgets/custom_date_picker.dart';

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
  int _selectedColorValue = Colors.blue.toARGB32();
  int? _selectedMotherColorValue;

  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.cow?.id ?? '');
    _bullIdController = TextEditingController(text: widget.cow?.bullId ?? '');
    _motherIdController = TextEditingController(
      text: widget.cow?.motherId ?? '',
    );
    _selectedMotherColorValue = widget.cow?.motherColorValue;

    if (widget.cow != null) {
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
      _selectedColorValue = widget.cow!.colorValue;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _bullIdController.dispose();
    _motherIdController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (widget.cow != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد التعديل', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('هل أنت متأكد من حفظ التعديلات على هذه البقرة؟'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _processSave();
                },
                child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        _processSave();
      }
    }
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
      if (widget.cow == null ||
          widget.cow!.inseminationDate != inseminationDate ||
          widget.cow!.birthDate != birthDate) {
        String title = '';
        if (_currentState == CowFormState.pregnant) title = 'تسجيل تلقيح';
        if (_currentState == CowFormState.heat) title = 'تسجيل شبق';
        if (_currentState == CowFormState.postBirth) title = 'تسجيل ولادة';

        history.add({
          'title': title,
          'date': _selectedDate.toIso8601String(),
          'note':
              _currentState == CowFormState.pregnant &&
                  _bullIdController.text.isNotEmpty
              ? 'طلوقة/عجل: ${_bullIdController.text}'
              : '',
        });
      }

      final cow = Cow(
        id: _idController.text,
        inseminationDate: inseminationDate,
        colorValue: _selectedColorValue,
        isInseminated: isInseminated,
        birthDate: birthDate,
        bullId: _bullIdController.text.isEmpty ? null : _bullIdController.text,
        motherId: _motherIdController.text.isEmpty
            ? null
            : _motherIdController.text,
        motherColorValue: _selectedMotherColorValue,
        history: history,
      );

      final cows = ref.read(cowProvider);

      if (widget.cow == null) {
        // Checking for duplicate uniqueKey (ID + Color)
        final alreadyExists = cows.any((c) => c.uniqueKey == cow.uniqueKey);
        if (alreadyExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'هذا الرقم موجود مسبقاً بنفس لون الكرت!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        ref.read(cowProvider.notifier).addCow(cow);
      } else {
        // Checking for duplicate uniqueKey if ID or Color changed
        if (widget.cow!.uniqueKey != cow.uniqueKey) {
          final alreadyExists = cows.any((c) => c.uniqueKey == cow.uniqueKey);
          if (alreadyExists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'الرقم واللون الجديد موجودين مسبقاً لبقرة أخرى!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
        ref
            .read(cowProvider.notifier)
            .updateCow(cow, oldKey: widget.cow!.uniqueKey);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم الحفظ بنجاح',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.green,
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context);
  }

  Widget _buildAnimatedItem(Widget child, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  String _getDateLabel() {
    switch (_currentState) {
      case CowFormState.pregnant:
        return 'تاريخ التلقيح';
      case CowFormState.heat:
        return 'تاريخ آخر شبق';
      case CowFormState.postBirth:
        return 'تاريخ الولادة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cow == null ? 'إضافة بقرة جديدة' : 'تعديل بقرة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnimatedItem(
                TextFormField(
                  controller: _idController,
                  decoration: InputDecoration(
                    labelText: 'رقم/اسم البقرة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'مطلوب' : null,
                ),
                0,
              ),
              const SizedBox(height: 20),
              _buildAnimatedItem(
                DropdownButtonFormField<CowFormState>(
                  initialValue: _currentState,
                  decoration: InputDecoration(
                    labelText: 'حالة البقرة الحالية',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.info_outline),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: CowFormState.pregnant,
                      child: Text('حامل (تم التلقيح)'),
                    ),
                    DropdownMenuItem(
                      value: CowFormState.heat,
                      child: Text('انتظار الشبق (غير ملقحة)'),
                    ),
                    DropdownMenuItem(
                      value: CowFormState.postBirth,
                      child: Text('حديثة الولادة (التعافي)'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _currentState = val!),
                ),
                50,
              ),
              const SizedBox(height: 20),
              _buildAnimatedItem(
                CustomDatePickerField(
                  label: _getDateLabel(),
                  initialDate: _selectedDate,
                  onDateSelected: (date) =>
                      setState(() => _selectedDate = date),
                ),
                100,
              ),
              if (_currentState == CowFormState.pregnant) ...[
                const SizedBox(height: 20),
                _buildAnimatedItem(
                  TextFormField(
                    controller: _bullIdController,
                    decoration: InputDecoration(
                      labelText: 'رقم/اسم الطلوقة (اختياري)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.pets),
                    ),
                  ),
                  150,
                ),
              ],
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),
              _buildAnimatedItem(
                const Text(
                  'معلومات الأنساب (اختياري)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blueGrey,
                  ),
                ),
                170,
              ),
              const SizedBox(height: 16),
              _buildAnimatedItem(
                TextFormField(
                  controller: _motherIdController,
                  decoration: InputDecoration(
                    labelText: 'رقم الأم (إذا كانت في المزرعة)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.family_restroom),
                  ),
                ),
                180,
              ),
              const SizedBox(height: 16),
              if (_motherIdController.text.isNotEmpty ||
                  _selectedMotherColorValue != null) ...[
                _buildAnimatedItem(
                  const Text(
                    'لون كرت الأم:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  190,
                ),
                const SizedBox(height: 8),
                _buildAnimatedItem(
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _colors.map((color) {
                      bool isSelected =
                          _selectedMotherColorValue == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedMotherColorValue = color.toARGB32(),
                        ),
                        child: Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 2)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  200,
                ),
                const SizedBox(height: 30),
              ],
              const Divider(),
              const SizedBox(height: 20),
              _buildAnimatedItem(
                const Text(
                  'اللون المميز للبقرة:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                250,
              ),
              const SizedBox(height: 12),
              _buildAnimatedItem(
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((color) {
                    bool isSelected = _selectedColorValue == color.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(
                        () => _selectedColorValue = color.toARGB32(),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 48 : 40,
                        height: isSelected ? 48 : 40,
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
                300,
              ),
              const SizedBox(height: 40),
              _buildAnimatedItem(
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _save,
                    child: const Text(
                      'حفظ البيانات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
