import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cow_pregnancy/providers/alerts_provider.dart';
import 'package:cow_pregnancy/screens/summary_screen.dart';
import 'package:cow_pregnancy/screens/cows_list_screen.dart';
import 'package:cow_pregnancy/screens/calves_screen.dart';
import 'package:cow_pregnancy/screens/activity_log_screen.dart';
import 'package:cow_pregnancy/screens/reports_screen.dart';
import 'package:cow_pregnancy/screens/notes_screen.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:cow_pregnancy/screens/summary_screen.dart' show mainNavIndexProvider, mainNavMoreScreenProvider;

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  Widget _moreScreen = const ReportsScreen(); // Default to reports
  bool _isDialogShowing = false;

  void _checkAndShowNewAlerts(List<SmartAlert> alerts) async {
    if (alerts.isEmpty || _isDialogShowing) return;
    
    final box = Hive.box('settings');
    final List<String> seenAlerts = List<String>.from(box.get('seen_alerts', defaultValue: []));
    
    final newAlerts = alerts.where((alert) => !seenAlerts.contains(alert.id)).toList();
    
    if (newAlerts.isNotEmpty) {
      _isDialogShowing = true;
      // Mark as seen immediately to prevent double triggers
      seenAlerts.addAll(newAlerts.map((a) => a.id));
      await box.put('seen_alerts', seenAlerts);
      
      if (!mounted) return;
      
      showGeneralDialog(
        context: context,
        barrierDismissible: false, // Force them to click OK
        barrierLabel: 'New Alerts',
        barrierColor: Colors.black.withOpacity(0.5),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim1, anim2) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.orange, size: 28),
                const SizedBox(width: 10),
                const Text('تنبيهات جديدة!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: newAlerts.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final alert = newAlerts[index];
                    final color = Color(alert.cowColorValue);
                    
                    // Dynamically remove "البقرة #123 " from description if present
                    String cleanDescription = alert.description;
                    String prefixToRemove = 'البقرة #${alert.cowId} ';
                    if (cleanDescription.startsWith(prefixToRemove)) {
                      cleanDescription = cleanDescription.substring(prefixToRemove.length);
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(alert.title, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14, 
                                height: 1.6,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                              ),
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      border: Border.all(color: color.withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          alert.cowId,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                TextSpan(text: cleanDescription),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _isDialogShowing = false;
                },
                child: const Text('فهمت', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              )
            ],
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          );
        },
      ).then((_) => _isDialogShowing = false);
    }
  }

  List<Widget> get _screens => [
    const SummaryScreen(),
    const CowsListScreen(),
    const CalvesScreen(),
    const ActivityLogScreen(),
    _moreScreen,
  ];

  DateTime? _lastPressedAt;

  void _showGlassyMoreMenu(BuildContext context) {
    showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.1), // Very light dark overlay to make it glassy
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 110), // Adjust to be right above the bottom bar on the left
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMenuOption('التقارير', Icons.bar_chart, 'reports', context),
                        Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                        _buildMenuOption('الملاحظات', Icons.notes, 'notes', context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    ).then((value) {
      if (!context.mounted || value == null) return;
      if (value == 'reports') {
        setState(() {
          _moreScreen = const ReportsScreen();
          _selectedIndex = 4;
        });
      } else if (value == 'notes') {
        setState(() {
          _moreScreen = const NotesScreen();
          _selectedIndex = 4;
        });
      }
    });
  }

  Widget _buildMenuOption(String title, IconData icon, String value, BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for navigation commands from other screens (one-way trigger, not persistent watch)
    ref.listen<int>(mainNavIndexProvider, (previous, next) {
      if (next != 0 && next != _selectedIndex) {
        setState(() => _selectedIndex = next);
        // Reset immediately so back navigation works normally
        ref.read(mainNavIndexProvider.notifier).state = 0;
      }
    });
    ref.listen<String>(mainNavMoreScreenProvider, (previous, next) {
      if (next == 'notes' && _moreScreen is! NotesScreen) {
        setState(() => _moreScreen = const NotesScreen());
      } else if (next == 'reports' && _moreScreen is! ReportsScreen) {
        setState(() => _moreScreen = const ReportsScreen());
      }
    });

    ref.listen<List<SmartAlert>>(alertsProvider, (previous, next) {
      _checkAndShowNewAlerts(next);
      // جدولة الإشعار الصباحي بناءً على التنبيهات الجديدة
      NotificationService.scheduleDailyNotification(next);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // If not on the dashboard, go back to it
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }
        
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اضغط مرة أخرى للخروج من التطبيق'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              width: 250,
            ),
          );
          return;
        }
        
        // If pressed twice within 2 seconds, we allow exit
        SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: _buildBlurredBottomBar(),
      ),
    );
  }

  Widget _buildBlurredBottomBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomPadding),
      height: 75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark
                ? const Color(0xFF232A3B).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    );
                  }
                  return TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: theme.colorScheme.primary, size: 24);
                  }
                  return IconThemeData(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 24,
                  );
                }),
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
                child: NavigationBar(
                  height: 75,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    if (index == 4) {
                      _showGlassyMoreMenu(context);
                    } else {
                      setState(() => _selectedIndex = index);
                    }
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'الرئيسية',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt),
                      label: 'الأبقار',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.child_care_outlined),
                      selectedIcon: Icon(Icons.child_care),
                      label: 'العجول',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history),
                      label: 'النشاطات',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.more_horiz_outlined),
                      selectedIcon: Icon(Icons.more_horiz),
                      label: 'المزيد',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

