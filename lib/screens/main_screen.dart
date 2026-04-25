import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/screens/summary_screen.dart';
import 'package:cow_pregnancy/screens/cows_list_screen.dart';
import 'package:cow_pregnancy/screens/calves_screen.dart';
import 'package:cow_pregnancy/screens/activity_log_screen.dart';
import 'package:cow_pregnancy/screens/reports_screen.dart';
import 'package:cow_pregnancy/screens/notes_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  Widget _moreScreen = const ReportsScreen(); // Default to reports

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
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

