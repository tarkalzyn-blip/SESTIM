import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';
import 'package:cow_pregnancy/providers/auth_provider.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/providers/alerts_provider.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:audioplayers/audioplayers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Profile Section
            if (appUser != null)
              _buildProfileCard(context, appUser),
            
            const SizedBox(height: 24),

            // Settings Sections
            _buildSettingsTile(
              context,
              icon: Icons.palette_outlined,
              color: Colors.purple,
              title: 'المظهر والخط',
              subtitle: 'الوضع الليلي ونوع الخط المستخدم',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceSettingsPage())),
            ),
            
            _buildSettingsTile(
              context,
              icon: Icons.settings_suggest_outlined,
              color: Colors.orange,
              title: 'إعدادات المزرعة',
              subtitle: 'تخصيص أيام الحمل، التعافي، ودورة الشبق',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmSettingsPage())),
            ),

            _buildSettingsTile(
              context,
              icon: Icons.notifications_none_outlined,
              color: Colors.blue,
              title: 'إعدادات النظام',
              subtitle: 'وقت التنبيهات الصباحية وطرق البحث',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsPage())),
            ),

            const SizedBox(height: 32),
            
            // Logout Button
            _buildLogoutButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic appUser) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundImage: appUser.photoUrl != null ? NetworkImage(appUser.photoUrl!) : null,
              child: appUser.photoUrl == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appUser.displayName ?? 'مستخدم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text(appUser.email, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => _showLogoutDialog(context, ref),
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟ سيتم حفظ بياناتك سحابياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authActionProvider.notifier).signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}

// --- Sub-Pages ---

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final currentFont = ref.watch(fontProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المظهر والخط')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('الوضع الليلي (Dark Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? Colors.blue : Colors.orange),
            value: isDark,
            onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(val),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sync, color: Colors.blue),
            title: const Text('مزامنة البيانات سحابياً', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('رفع كافة البيانات المحلية إلى حسابك الآن'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بدء المزامنة...')));
              await ref.read(cowProvider.notifier).syncLocalToCloud();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت المزامنة بنجاح'), backgroundColor: Colors.green));
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('نوع الخط العربي', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('اختر الخط المناسب لراحتك البصرية'),
            leading: const Icon(Icons.font_download_outlined, color: Colors.purple),
            trailing: DropdownButton<String>(
              value: currentFont,
              underline: const SizedBox(),
              items: ['Cairo', 'Tajawal'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) {
                if (val != null) ref.read(fontProvider.notifier).setFont(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FarmSettingsPage extends ConsumerStatefulWidget {
  const FarmSettingsPage({super.key});

  @override
  ConsumerState<FarmSettingsPage> createState() => _FarmSettingsPageState();
}

class _FarmSettingsPageState extends ConsumerState<FarmSettingsPage> {
  late TextEditingController _preg;
  late TextEditingController _rec;
  late TextEditingController _heat;
  late TextEditingController _late;
  late TextEditingController _dry;

  @override
  void initState() {
    super.initState();
    _preg = TextEditingController(text: AppSettings.pregnancyDays.toString());
    _rec = TextEditingController(text: AppSettings.recoveryDays.toString());
    _late = TextEditingController(text: AppSettings.lateInseminationDays.toString());
    _dry = TextEditingController(text: AppSettings.dryingDays.toString());
    _heat = TextEditingController(text: AppSettings.heatCycleDays.toString());
  }

  @override
  void dispose() {
    _preg.dispose();
    _rec.dispose();
    _late.dispose();
    _dry.dispose();
    _heat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المزرعة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInput('مدة الحمل (يوم)', _preg, Icons.calendar_month),
          _buildInput('بداية الجاهزية للتلقيح (يوم)', _rec, Icons.child_care),
          _buildInput('تأخر في التلقيح (يوم)', _late, Icons.warning_amber),
          _buildInput('بداية فترة التجفيف قبل الولادة (يوم)', _dry, Icons.dry_cleaning),
          _buildInput('دورة الشبق (يوم)', _heat, Icons.loop),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () async {
              await AppSettings.setPregnancyDays(int.tryParse(_preg.text) ?? 280);
              await AppSettings.setRecoveryDays(int.tryParse(_rec.text) ?? 60);
              await AppSettings.setLateInseminationDays(int.tryParse(_late.text) ?? 70);
              await AppSettings.setDryingDays(int.tryParse(_dry.text) ?? 60);
              await AppSettings.setHeatCycleDays(int.tryParse(_heat.text) ?? 21);
              if (mounted) {
                ref.invalidate(cowProvider);
                ref.invalidate(alertsProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ الإعدادات'),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class SystemSettingsPage extends ConsumerStatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  ConsumerState<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends ConsumerState<SystemSettingsPage> {
  late int _hour;
  late int _minute;
  late bool _exact;
  late AudioPlayer _previewPlayer;

  @override
  void initState() {
    super.initState();
    _hour = AppSettings.notificationHour;
    _minute = AppSettings.notificationMinute;
    _exact = AppSettings.exactSearchMatch;
    _previewPlayer = AudioPlayer();
    _previewPlayer.setPlayerMode(PlayerMode.lowLatency);
    _previewPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  String _formatTimeDisplay(int hour, int minute) {
    final period = hour >= 12 ? 'مساءً' : 'صباحاً';
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النظام')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('موعد التنبيه الصباحي', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('سيصلك ملخص يومي بالمهام في هذا الوقت'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTimeDisplay(_hour, _minute),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
              ),
            ),
            leading: const Icon(Icons.alarm, color: Colors.blue),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: _hour, minute: _minute),
                helpText: 'اختر وقت التنبيه الصباحي',
              );
              if (time != null) {
                setState(() {
                  _hour = time.hour;
                  _minute = time.minute;
                });
                await AppSettings.setNotificationHour(time.hour);
                await AppSettings.setNotificationMinute(time.minute);
                
                // إعادة برمجة المنبه فوراً
                final alerts = ref.read(alertsProvider);
                final urgentCount = alerts.where((a) => a.severity == AlertSeverity.high).length;
                await NotificationService().scheduleDailyMorningSummary(urgentCount, alerts.length);
                
                // إظهار رسالة تأكيد
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث المنبه فوراً إلى ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}'),
                      backgroundColor: Colors.teal,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('نغمة التنبيه', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('اختر نغمة الإشعارات المفضلة لديك'),
            leading: const Icon(Icons.music_note, color: Colors.blue),
            trailing: DropdownButton<String>(
              value: AppSettings.notificationSound,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_left),
              items: const [
                DropdownMenuItem(value: 'default_sound', child: Text('النغمة الافتراضية')),
                DropdownMenuItem(value: 'farm_tone', child: Text('نغمة المزرعة')),
                DropdownMenuItem(value: 'nature_birds', child: Text('أصوات الطبيعة')),
                DropdownMenuItem(value: 'modern_alert', child: Text('تنبيه عصري')),
                DropdownMenuItem(value: 'soft_chime', child: Text('جرس ناعم')),
                DropdownMenuItem(value: 'classic_bell', child: Text('جرس كلاسيك')),
              ],
              onChanged: (val) async {
                if (val != null) {
                  await AppSettings.setNotificationSound(val);
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث نغمة التنبيه للمهمات القادمة'))
                    );
                  }
                }
              },
            ),
          ),
          ListTile(
            title: const Text('نغمة عجلة التاريخ', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('اختر نغمة الحركة عند تغيير التاريخ'),
            leading: const Icon(Icons.slow_motion_video, color: Colors.blue),
            trailing: DropdownButton<String>(
              value: AppSettings.datePickerSound,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_left),
              items: const [
                DropdownMenuItem(value: 'tick.mp3', child: Text('النغمة الأصلية')),
                DropdownMenuItem(value: 'tick_1.mp3', child: Text('النغمة 1')),
                DropdownMenuItem(value: 'tick_2.mp3', child: Text('النغمة 2')),
                DropdownMenuItem(value: 'tick_3.mp3', child: Text('النغمة 3')),
              ],
              onChanged: (val) async {
                if (val != null) {
                  await AppSettings.setDatePickerSound(val);
                  setState(() {});
                  // Preview sound safely
                  try {
                    await _previewPlayer.stop();
                    await _previewPlayer.play(AssetSource('sounds/$val'));
                  } catch (e) {
                    debugPrint('Preview sound error: $e');
                  }
                }
              },
            ),
          ),
          ListTile(
            title: const Text('إعدادات النظام للإشعارات', style: TextStyle(fontSize: 13)),
            subtitle: const Text('فتح إعدادات أندرويد للتحكم المتقدم'),
            leading: const Icon(Icons.settings_applications, color: Colors.grey, size: 20),
            onTap: () => NotificationService().openNotificationSettings(),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('البحث الدقيق برقم البقرة', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('يتطلب كتابة الرقم كامل للعثور على البقرة'),
            secondary: const Icon(Icons.search, color: Colors.blue),
            value: _exact,
            onChanged: (val) {
              setState(() => _exact = val);
              AppSettings.setExactSearchMatch(val);
            },
          ),
        ],
      ),
    );
  }
}
