import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';
import 'package:cow_pregnancy/providers/auth_provider.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/providers/alerts_provider.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cow_pregnancy/screens/about_screen.dart';
import 'package:cow_pregnancy/providers/edit_access_provider.dart';
import 'package:cow_pregnancy/providers/settings_provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/widgets/cow_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Profile Section
            if (appUser != null) _buildProfileCard(context, appUser),

            // Access Permissions Section (Moved to TOP)
            _buildSettingsTile(
              context,
              icon: Icons.admin_panel_settings_outlined,
              color: Colors.redAccent,
              title: 'صلاحيات الوصول',
              subtitle: 'تفعيل وضع المسؤول أو تغيير كلمة السر',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
              ),
            ),

            const SizedBox(height: 12),

            // Settings Sections
            _buildSettingsTile(
              context,
              icon: Icons.palette_outlined,
              color: Colors.purple,
              title: 'المظهر والخط',
              subtitle: 'الوضع الليلي ونوع الخط المستخدم',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppearanceSettingsPage(),
                ),
              ),
            ),

            _buildSettingsTile(
              context,
              icon: Icons.style_outlined,
              color: Colors.pinkAccent,
              title: 'ألوان الكروت',
              subtitle: 'إضافة أو حذف الألوان المميزة للبقر والعجول',
              onTap: () => ref.read(editAccessProvider.notifier).runWithAccess(
                context,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CowColorsSettingsPage()),
                ),
              ),
            ),

            _buildSettingsTile(
              context,
              icon: Icons.settings_suggest_outlined,
              color: Colors.orange,
              title: 'إعدادات المزرعة',
              subtitle: 'تخصيص أيام الحمل، التعافي، ودورة الشبق',
              onTap: () => ref.read(editAccessProvider.notifier).runWithAccess(
                context,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FarmSettingsPage()),
                ),
              ),
            ),

            _buildSettingsTile(
              context,
              icon: Icons.notifications_none_outlined,
              color: Colors.blue,
              title: 'إعدادات النظام',
              subtitle: 'وقت التنبيهات الصباحية وطرق البحث',
              onTap: () => ref.read(editAccessProvider.notifier).runWithAccess(
                context,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SystemSettingsPage()),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // About Section
            _sectionHeader('حول التطبيق'),
            const SizedBox(height: 8),
            _buildSettingsTile(
              context,
              icon: Icons.info_outline,
              color: Colors.blueGrey,
              title: 'لمحة عنا',
              subtitle: 'معلومات عن النظام وأهداف التطبيق',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),

            const SizedBox(height: 32),

            // Logout Button
            _buildLogoutButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic appUser) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundImage: appUser.photoUrl != null
                  ? NetworkImage(appUser.photoUrl!)
                  : null,
              child: appUser.photoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appUser.displayName ?? 'مستخدم',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    appUser.email,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
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
        label: const Text(
          'تسجيل الخروج',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'هل أنت متأكد أنك تريد تسجيل الخروج؟ سيتم حفظ بياناتك سحابياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
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
    final fontScale = ref.watch(fontScaleProvider);

    final previewCow = Cow(
      id: 'A-150',
      inseminationDate: DateTime.now().subtract(const Duration(days: 40)),
      colorValue: Colors.teal.value,
      isInseminated: true,
      history: [],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('المظهر والخط')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text(
              'الوضع الليلي (Dark Mode)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: isDark ? Colors.blue : Colors.orange,
            ),
            value: isDark,
            onChanged: (val) =>
                ref.read(themeProvider.notifier).toggleTheme(val),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sync, color: Colors.blue),
            title: const Text(
              'مزامنة البيانات سحابياً',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('رفع كافة البيانات المحلية إلى حسابك الآن'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('بدء المزامنة...')));
              await ref.read(cowProvider.notifier).syncLocalToCloud();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت المزامنة بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text(
              'نوع الخط العربي',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('اختر الخط المناسب لراحتك البصرية'),
            leading: const Icon(
              Icons.font_download_outlined,
              color: Colors.purple,
            ),
            trailing: DropdownButton<String>(
              value: currentFont,
              underline: const SizedBox(),
              items: [
                'Cairo',
                'Tajawal',
                'Almarai',
                'Traditional',
                'Changa',
              ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) {
                if (val != null) ref.read(fontProvider.notifier).setFont(val);
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'حجم خط التطبيق (معاينة حية)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          // Preview Card
          IgnorePointer(
            child: CowCard(cow: previewCow),
          ),
          const SizedBox(height: 16),
          // Font Scale Slider
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Slider(
                    value: fontScale,
                    min: 1.0,
                    max: 1.4,
                    divisions: 4,
                    label: '${(fontScale * 100).toInt()}%',
                    activeColor: Colors.teal,
                    inactiveColor: Colors.teal.withOpacity(0.2),
                    onChanged: (val) {
                      ref.read(fontScaleProvider.notifier).setScale(val);
                    },
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'قم بسحب الشريط لتكبير الخط. لن تتأثر الأيقونات بهذا التغيير حفاظاً على شكل التطبيق.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
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
  late TextEditingController _minInsem;

  @override
  void initState() {
    super.initState();
    _preg = TextEditingController(text: AppSettings.pregnancyDays.toString());
    _rec = TextEditingController(text: AppSettings.recoveryDays.toString());
    _late = TextEditingController(
      text: AppSettings.lateInseminationDays.toString(),
    );
    _dry = TextEditingController(text: AppSettings.dryingDays.toString());
    _heat = TextEditingController(text: AppSettings.heatCycleDays.toString());
    _minInsem = TextEditingController(
      text: AppSettings.minInseminationDaysAfterBirth.toString(),
    );
  }

  @override
  void dispose() {
    _preg.dispose();
    _rec.dispose();
    _late.dispose();
    _dry.dispose();
    _heat.dispose();
    _minInsem.dispose();
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
          _buildInput('بداية الجاهزية للتلقيح بعد الولادة (يوم)', _rec, Icons.child_care),
          _buildInput(
            'الحد الأدنى للتلقيح بعد الولادة (يوم)',
            _minInsem,
            Icons.block,
            hint: 'لن يُسمح بتسجيل التلقيح قبل هذه المدة من الولادة',
            color: Colors.red,
          ),
          _buildInput('تأخر في التلقيح (يوم)', _late, Icons.warning_amber),
          _buildInput(
            'بداية فترة التجفيف قبل الولادة (يوم)',
            _dry,
            Icons.dry_cleaning,
          ),
          _buildInput('دورة الشبق (يوم)', _heat, Icons.loop),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () async {
              await AppSettings.setPregnancyDays(
                int.tryParse(_preg.text) ?? 280,
              );
              await AppSettings.setRecoveryDays(int.tryParse(_rec.text) ?? 60);
              await AppSettings.setMinInseminationDaysAfterBirth(
                int.tryParse(_minInsem.text) ?? 45,
              );
              await AppSettings.setLateInseminationDays(
                int.tryParse(_late.text) ?? 70,
              );
              await AppSettings.setDryingDays(int.tryParse(_dry.text) ?? 60);
              await AppSettings.setHeatCycleDays(
                int.tryParse(_heat.text) ?? 21,
              );
              if (mounted) {
                ref.invalidate(cowProvider);
                ref.invalidate(alertsProvider);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ الإعدادات'),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: hint,
          helperMaxLines: 2,
          prefixIcon: Icon(icon, color: color),
          labelStyle: color != null ? TextStyle(color: color) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color ?? Colors.blue, width: 2),
          ),
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
            title: const Text(
              'موعد التنبيه الصباحي',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('سيصلك ملخص يومي بالمهام في هذا الوقت'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatTimeDisplay(_hour, _minute),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
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
                final urgentCount = alerts
                    .where((a) => a.severity == AlertSeverity.high)
                    .length;
                await NotificationService().scheduleDailyMorningSummary(
                  urgentCount,
                  alerts.length,
                );

                // إظهار رسالة تأكيد
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تحديث المنبه فوراً إلى ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                      ),
                      backgroundColor: Colors.teal,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text(
              'نغمة التنبيه',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('اختر نغمة الإشعارات المفضلة لديك'),
            leading: const Icon(Icons.music_note, color: Colors.blue),
            trailing: DropdownButton<String>(
              value: AppSettings.notificationSound,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_left),
              items: const [
                DropdownMenuItem(
                  value: 'default_sound',
                  child: Text('النغمة الافتراضية'),
                ),
                DropdownMenuItem(
                  value: 'farm_tone',
                  child: Text('نغمة المزرعة'),
                ),
                DropdownMenuItem(
                  value: 'nature_birds',
                  child: Text('أصوات الطبيعة'),
                ),
                DropdownMenuItem(
                  value: 'modern_alert',
                  child: Text('تنبيه عصري'),
                ),
                DropdownMenuItem(value: 'soft_chime', child: Text('جرس ناعم')),
                DropdownMenuItem(
                  value: 'classic_bell',
                  child: Text('جرس كلاسيك'),
                ),
              ],
              onChanged: (val) async {
                if (val != null) {
                  await AppSettings.setNotificationSound(val);
                  setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث نغمة التنبيه للمهمات القادمة'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          ListTile(
            title: const Text(
              'نغمة عجلة التاريخ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('اختر نغمة الحركة عند تغيير التاريخ'),
            leading: const Icon(Icons.slow_motion_video, color: Colors.blue),
            trailing: DropdownButton<String>(
              value: AppSettings.datePickerSound,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_left),
              items: const [
                DropdownMenuItem(
                  value: 'tick.mp3',
                  child: Text('النغمة الأصلية'),
                ),
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
            title: const Text(
              'إعدادات النظام للإشعارات',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text('فتح إعدادات أندرويد للتحكم المتقدم'),
            leading: const Icon(
              Icons.settings_applications,
              color: Colors.grey,
              size: 20,
            ),
            onTap: () => NotificationService().openNotificationSettings(),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text(
              'البحث الدقيق برقم البقرة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _oldCodeController = TextEditingController();
  final _newCodeController = TextEditingController();
  final _confirmCodeController = TextEditingController();

  @override
  void dispose() {
    _oldCodeController.dispose();
    _newCodeController.dispose();
    _confirmCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditor = ref.watch(editAccessProvider);
    // Use a local state for the switch to allow a "Save" button flow
    return _AdminSettingsBody(isEditor: isEditor);
  }
}

class _AdminSettingsBody extends ConsumerStatefulWidget {
  final bool isEditor;
  const _AdminSettingsBody({required this.isEditor});

  @override
  ConsumerState<_AdminSettingsBody> createState() => _AdminSettingsBodyState();
}

class _AdminSettingsBodyState extends ConsumerState<_AdminSettingsBody> {
  late bool _tempProtectionEnabled;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tempProtectionEnabled = AppSettings.isProtectionEnabled;
  }

  final _oldCodeController = TextEditingController();
  final _newCodeController = TextEditingController();
  final _confirmCodeController = TextEditingController();

  @override
  void dispose() {
    _oldCodeController.dispose();
    _newCodeController.dispose();
    _confirmCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('صلاحيات الوصول')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Global Toggle with Protection
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'نظام حماية المسؤول',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _tempProtectionEnabled 
                      ? 'الحماية مفعلة: التعديل يتطلب كود' 
                      : 'الحماية معطلة: يمكن للجميع التعديل',
                    style: TextStyle(fontSize: 12, color: _tempProtectionEnabled ? Colors.green : Colors.red),
                  ),
                  value: _tempProtectionEnabled,
                  onChanged: (val) {
                    // Only allow changing if already an editor
                    if (widget.isEditor) {
                      setState(() {
                        _tempProtectionEnabled = val;
                        _hasChanges = true;
                      });
                    } else {
                      // If not editor, trigger the access dialog
                      ref.read(editAccessProvider.notifier).runWithAccess(context, () {
                        setState(() {
                          _tempProtectionEnabled = val;
                          _hasChanges = true;
                        });
                      });
                    }
                  },
                ),
                if (_hasChanges)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, right: 16, left: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('حفظ إعدادات الحماية'),
                        onPressed: () async {
                          await ref.read(editAccessProvider.notifier).toggleProtection(_tempProtectionEnabled);
                          setState(() {
                            _hasChanges = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ إعدادات الحماية بنجاح'), backgroundColor: Colors.teal),
                            );
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.isEditor
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isEditor
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  widget.isEditor ? Icons.verified_user : Icons.visibility,
                  size: 48,
                  color: widget.isEditor ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isEditor ? 'أنت الآن في وضع المسؤول' : 'أنت الآن في وضع المشاهد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.isEditor ? Colors.green : Colors.orange,
                  ),
                ),
                if (AppSettings.adminCode == '1234') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'تنبيه: أنت تستخدم الكود العام (1234)',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'يرجى تغيير الكود لتجنب الخطأ مع العمال ولتفعيل الحماية الفعلية.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  widget.isEditor
                      ? 'لديك كامل الصلاحيات للتعديل والحذف والإضافة.'
                      : 'يمكنك تصفح البيانات فقط، لا يمكنك التعديل بدون كود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (widget.isEditor && AppSettings.adminCode == '1234') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'أنت تستخدم الكود الافتراضي (1234)، يرجى تغييره للأمان.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.isEditor) ...[
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(editAccessProvider.notifier).disableEditMode();
                      // Also reset the temp toggle to match current system state
                      setState(() {
                        _tempProtectionEnabled = AppSettings.isProtectionEnabled;
                        _hasChanges = false;
                      });
                    },
                    icon: const Icon(Icons.no_accounts, color: Colors.red),
                    label: const Text(
                      'الخروج من وضع المسؤول (العودة للمشاهد)',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(editAccessProvider.notifier).runWithAccess(
                            context,
                            () {},
                          );
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('تفعيل وضع المسؤول الآن'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (widget.isEditor) ...[
            const Text(
              'تغيير كلمة السر (كود المسؤول)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _oldCodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الكود الحالي',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الكود الجديد',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'تأكيد الكود الجديد',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                if (_newCodeController.text != _confirmCodeController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الأكواد الجديدة غير متطابقة!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                try {
                  await ref.read(editAccessProvider.notifier).updateCode(
                        _oldCodeController.text,
                        _newCodeController.text,
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تغيير كود المسؤول بنجاح'),
                        backgroundColor: Colors.teal,
                      ),
                    );
                    _oldCodeController.clear();
                    _newCodeController.clear();
                    _confirmCodeController.clear();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ الكود الجديد'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'يجب أن تكون في وضع المسؤول لتتمكن من تغيير كود الوصول.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CowColorsSettingsPage extends ConsumerStatefulWidget {
  const CowColorsSettingsPage({super.key});

  @override
  ConsumerState<CowColorsSettingsPage> createState() => _CowColorsSettingsPageState();
}

class _CowColorsSettingsPageState extends ConsumerState<CowColorsSettingsPage> {
  Color _pickerColor = Colors.blue;

  void _changeColor(Color color) {
    setState(() => _pickerColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final availableColors = ref.watch(cowColorsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String hexCode = '#${_pickerColor.value.toRadixString(16).substring(2).toUpperCase()}';

    return Scaffold(
      appBar: AppBar(title: const Text('اختيار لون الكرت', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            // ── عجلة الألوان ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  HueRingPicker(
                    pickerColor: _pickerColor,
                    onColorChanged: _changeColor,
                    enableAlpha: false,
                    displayThumbColor: true,
                    colorPickerHeight: 250,
                    hueRingStrokeWidth: 25,
                  ),
                  const SizedBox(height: 24),
                  
                  // ── معاينة اللون والكود ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: _pickerColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _pickerColor.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Text(
                          hexCode,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // ── زر إضافة اللون ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        final int colorValue = _pickerColor.toARGB32();
                        if (availableColors.contains(colorValue)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('اللون موجود مسبقاً!'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        ref.read(cowColorsProvider.notifier).addColor(colorValue);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم إضافة اللون بنجاح: $hexCode'), backgroundColor: Colors.green),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text('إضافة اللون', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // ── قسم الألوان المحفوظة ──────────────────────────────────
            Row(
              children: [
                Icon(Icons.palette_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'ألواني',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.primary.withOpacity(0.05) : theme.colorScheme.primary.withOpacity(0.03),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15), width: 1.5),
              ),
              child: availableColors.isEmpty
                  ? const Text('لم يتم حفظ أي ألوان بعد.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: availableColors.map((colorVal) {
                        final color = Color(colorVal);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () => _changeColor(color),
                                child: Container(
                                  width: 55,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: GestureDetector(
                                  onTap: () {
                                    if (availableColors.length <= 1) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('يجب أن تحتفظ بلون واحد على الأقل.')),
                                      );
                                      return;
                                    }
                                    _confirmDelete(context, ref, colorVal);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int colorVal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف اللون'),
        content: const Text('هل أنت متأكد من حذف هذا اللون من قائمتك؟\n\nلن يختفي اللون من الأبقار التي تستخدمه حالياً، لكنه لن يظهر في قائمة الاختيار مستقبلاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              ref.read(cowColorsProvider.notifier).removeColor(colorVal);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
