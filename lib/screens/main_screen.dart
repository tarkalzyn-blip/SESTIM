import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/screens/summary_screen.dart';
import 'package:cow_pregnancy/screens/cows_list_screen.dart';
import 'package:cow_pregnancy/screens/calves_screen.dart';
import 'package:cow_pregnancy/screens/post_birth_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 3; // Default to Dashboard

  final List<Widget> _screens = [
    const PostBirthScreen(),
    const CalvesScreen(),
    const CowsListScreen(),
    const SummaryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBlurredBottomBar(),
    );
  }

  Widget _buildBlurredBottomBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.medical_services_outlined),
                  activeIcon: Icon(Icons.medical_services),
                  label: 'بعد الولادة',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.child_care_outlined),
                  activeIcon: Icon(Icons.child_care),
                  label: 'العجول',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_outlined),
                  activeIcon: Icon(Icons.list_alt),
                  label: 'إدارة الأبقار',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'لوحة التحكم',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
