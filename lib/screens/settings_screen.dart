import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _pregnancyController;
  late TextEditingController _recoveryController;
  late TextEditingController _heatController;
  late bool _exactSearchMatch;

  @override
  void initState() {
    super.initState();
    _pregnancyController = TextEditingController(text: AppSettings.pregnancyDays.toString());
    _recoveryController = TextEditingController(text: AppSettings.recoveryDays.toString());
    _heatController = TextEditingController(text: AppSettings.heatCycleDays.toString());
    _exactSearchMatch = AppSettings.exactSearchMatch;
    _notificationHour = AppSettings.notificationHour;
  }
  
  late int _notificationHour;

  @override
  void dispose() {
    _pregnancyController.dispose();
    _recoveryController.dispose();
    _heatController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    final preg = int.tryParse(_pregnancyController.text);
    final rec = int.tryParse(_recoveryController.text);
    final heat = int.tryParse(_heatController.text);

    if (preg != null) await AppSettings.setPregnancyDays(preg);
    if (rec != null) await AppSettings.setRecoveryDays(rec);
    if (heat != null) await AppSettings.setHeatCycleDays(heat);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات بنجاح. قد تتطلب التغييرات إعادة فتح التطبيق لتأثير كامل.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات المتقدمة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: const Text('الوضع الليلي (Dark Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                value: isDark,
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.blueAccent : Colors.orange),
                onChanged: (val) {
                  ref.read(themeProvider.notifier).toggleTheme(val);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.notifications_active, color: Colors.blueAccent),
                title: const Text('موعد التنبيه الصباحي', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${_notificationHour.toString().padLeft(2, '0')}:00', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: _notificationHour, minute: 0),
                  );
                  if (time != null) {
                    setState(() => _notificationHour = time.hour);
                    await AppSettings.setNotificationHour(time.hour);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: const Text('بحث دقيق برقم البقرة', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('عند التفعيل، يجب كتابة الرقم كاملاً لتظهر النتيجة'),
                value: _exactSearchMatch,
                secondary: Icon(Icons.search, color: Colors.blueAccent),
                onChanged: (val) {
                  setState(() => _exactSearchMatch = val);
                  AppSettings.setExactSearchMatch(val);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 30),
            const Text('تخصيص فترات دورة حياة البقرة (بالأيام)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _pregnancyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'مدة الحمل (الافتراضي: 280)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.calendar_month),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _recoveryController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'فترة التعافي للولادة (الافتراضي: 65)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.child_care),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _heatController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'دورة الشبق (الافتراضي: 21)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.loop),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('حفظ التغييرات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
