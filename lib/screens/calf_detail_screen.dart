import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:intl/intl.dart';

class CalfDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> calfData;

  const CalfDetailScreen({super.key, required this.calfData});

  @override
  ConsumerState<CalfDetailScreen> createState() => _CalfDetailScreenState();
}

class _CalfDetailScreenState extends ConsumerState<CalfDetailScreen> {
  late Map<String, dynamic> _currentCalfData;

  @override
  void initState() {
    super.initState();
    _currentCalfData = Map.from(widget.calfData);
  }

  void _showExitDialog() {
    String selectedReason = 'بيع';
    final priceController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('استبعاد العجل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سبب الاستبعاد:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'بيع', child: Text('💰 بيع')),
                    DropdownMenuItem(value: 'وفاة', child: Text('☠️ وفاة')),
                    DropdownMenuItem(value: 'نقل', child: Text('🔄 نقل لمزرعة أخرى')),
                  ],
                  onChanged: (val) {
                    setStateDialog(() => selectedReason = val!);
                  },
                ),
                if (selectedReason == 'بيع') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'سعر البيع',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات إضافية (اختياري)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                _processExit(selectedReason, priceController.text, noteController.text);
                Navigator.pop(ctx);
              },
              child: const Text('تأكيد الاستبعاد'),
            ),
          ],
        ),
      ),
    );
  }

  void _processExit(String reason, String price, String note) {
    final cows = ref.read(cowProvider);
    final cowIndex = cows.indexWhere((c) => c.uniqueKey == _currentCalfData['motherUniqueKey']);
    
    if (cowIndex != -1) {
      final cow = cows[cowIndex];
      final originalDate = _currentCalfData['originalEventDate']; // Need to pass this
      
      final newHistory = cow.history.map((event) {
        final eventEventId = event['eventId']?.toString();
        final storedEventId = _currentCalfData['eventId']?.toString();
        final matchById = eventEventId != null && storedEventId != null && eventEventId == storedEventId;
        final matchByDate = event['date'].toString() == originalDate;
        if (event['title'] == 'تسجيل ولادة' && (matchById || (!matchById && eventEventId == null && matchByDate))) {
          final newEvent = Map<String, dynamic>.from(event);
          newEvent['isExited'] = true;
          newEvent['exitReason'] = reason;
          newEvent['exitPrice'] = price;
          newEvent['exitNote'] = note;
          newEvent['exitDate'] = DateTime.now().toIso8601String();
          
          setState(() {
            _currentCalfData['isExited'] = true;
            _currentCalfData['exitReason'] = reason;
            _currentCalfData['exitPrice'] = price;
            _currentCalfData['exitDate'] = newEvent['exitDate'];
          });
          
          return newEvent;
        }
        return event;
      }).toList();
      
      ref.read(cowProvider.notifier).updateCow(cow.copyWith(history: newHistory));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استبعاد العجل بنجاح (السبب: $reason)')),
      );
    }
  }

  void _showAddWeightDialog() {
    final weightController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل وزن جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        content: TextField(
          controller: weightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'الوزن',
            suffixText: 'كغ',
            prefixIcon: const Icon(Icons.monitor_weight),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (weightController.text.isNotEmpty) {
                _processAddWeight(double.tryParse(weightController.text) ?? 0);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _processAddWeight(double weight) {
    if (weight <= 0) return;

    final cows = ref.read(cowProvider);
    final cowIndex = cows.indexWhere((c) => c.uniqueKey == _currentCalfData['motherUniqueKey']);
    
    if (cowIndex != -1) {
      final cow = cows[cowIndex];
      final originalDate = _currentCalfData['originalEventDate'];
      
      final newHistory = cow.history.map((event) {
        final eventEventId = event['eventId']?.toString();
        final storedEventId = _currentCalfData['eventId']?.toString();
        final matchById = eventEventId != null && storedEventId != null && eventEventId == storedEventId;
        final matchByDate = event['date'].toString() == originalDate;
        if (event['title'] == 'تسجيل ولادة' && (matchById || (!matchById && eventEventId == null && matchByDate))) {
          final newEvent = Map<String, dynamic>.from(event);
          List<dynamic> weights = List.from(newEvent['weights'] ?? []);
          weights.add({
            'date': DateTime.now().toIso8601String(),
            'weight': weight,
          });
          newEvent['weights'] = weights;
          
          setState(() {
            _currentCalfData['weights'] = weights;
          });
          
          return newEvent;
        }
        return event;
      }).toList();
      
      ref.read(cowProvider.notifier).updateCow(cow.copyWith(history: newHistory));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الوزن بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMale = _currentCalfData['note'].toString().contains('ذكر');
    final calfColor = Color(_currentCalfData['calfColorValue']);
    final isExited = _currentCalfData['isExited'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('الملف الشخصي: ${_currentCalfData['calfId'] ?? 'عجل'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            if (isExited)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'هذا العجل مستبعد! (السبب: ${_currentCalfData['exitReason']})',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: calfColor.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 2),
                ],
                border: Border.all(color: calfColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: calfColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isMale ? Icons.male : Icons.female, size: 60, color: calfColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentCalfData['calfId'] != null ? 'رقم العجل: ${_currentCalfData['calfId']}' : 'بدون رقم',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isMale ? 'ذكر' : 'أنثى',
                    style: TextStyle(fontSize: 16, color: calfColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // Details
            _buildDetailCard(Icons.cake, 'تاريخ الولادة', DateFormat('yyyy/MM/dd').format(_currentCalfData['date'])),
            _buildDetailCard(Icons.female, 'رقم الأم', '#${_currentCalfData['motherId']}'),
            
            if (isExited && _currentCalfData['exitPrice'] != null && _currentCalfData['exitPrice'].toString().isNotEmpty)
              _buildDetailCard(Icons.attach_money, 'سعر البيع', '${_currentCalfData['exitPrice']}'),
            
            if (isExited && _currentCalfData['exitDate'] != null)
              _buildDetailCard(Icons.calendar_today, 'تاريخ الاستبعاد', DateFormat('yyyy/MM/dd').format(DateTime.parse(_currentCalfData['exitDate']))),

            const SizedBox(height: 30),
            
            // Future Features placeholders
            const Text('أدوات العناية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: isExited ? null : _showAddWeightDialog,
                    borderRadius: BorderRadius.circular(15),
                    child: _buildActionBtn(Icons.monitor_weight_outlined, 'تسجيل وزن', Colors.blue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildActionBtn(Icons.vaccines_outlined, 'اللقاحات (قريباً)', Colors.teal)),
              ],
            ),

            const SizedBox(height: 20),

            // Weights History
            if (_currentCalfData['weights'] != null && (_currentCalfData['weights'] as List).isNotEmpty) ...[
              const Text('سجل الأوزان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              ...(_currentCalfData['weights'] as List).reversed.map((w) {
                final date = DateTime.parse(w['date']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.monitor_weight, color: Colors.white, size: 20)),
                    title: Text('${w['weight']} كغ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(date)),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 40),

            // Exit Button
            if (!isExited)
              FilledButton.icon(
                icon: const Icon(Icons.outbox),
                label: const Text('استبعاد من القطيع (بيع / وفاة)'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _showExitDialog,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        trailing: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
