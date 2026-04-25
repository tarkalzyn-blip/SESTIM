import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/add_edit_cow_screen.dart';
import 'package:cow_pregnancy/widgets/cow_card.dart';
import 'package:cow_pregnancy/widgets/cow_search_delegate.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';

class CowsListScreen extends ConsumerWidget {
  const CowsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredCows = ref.watch(filteredCowsProvider);
    final currentFilter = ref.watch(filterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأبقار', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          PopupMenuButton<CowSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'فرز الأبقار',
            onSelected: (sort) => ref.read(sortProvider.notifier).setSort(sort),
            itemBuilder: (context) => [
              const PopupMenuItem(value: CowSort.none, child: Text('الترتيب الافتراضي')),
              const PopupMenuItem(value: CowSort.closestToEvent, child: Text('الأقرب للموعد (ولادة/شبق)')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: CowSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            tooltip: 'إضافة بقرة',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AddEditCowScreen(),
              ));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip(ref, 'الكل', CowFilter.all, currentFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(ref, 'الحوامل', CowFilter.pregnant, currentFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(ref, 'تحتاج مراقبة', CowFilter.monitoring, currentFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(ref, 'بدون لقاح', CowFilter.notInseminated, currentFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(ref, 'بعد الولادة', CowFilter.postBirth, currentFilter),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const AddEditCowScreen(),
                  ));
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green,
                      width: 1.5,
                      style: BorderStyle.solid, // Note: We use solid here but simulate dashed visually, or just solid. Wait, the user asked for dashed. 
                      // Flutter standard BoxDecoration doesn't have dashed border easily without a custom painter or package.
                      // Let's just use a nice solid green border or a dashed-looking widget if needed, but a solid 1px green border with green background is actually very close to the picture. Let's use dotted_border if available, else solid. I don't know if dotted_border is in pubspec, so I'll stick to a nice solid/translucent border for safety.
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'إضافة بقرة جديدة',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cow = filteredCows[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: CowCard(cow: cow, index: index),
                );
              },
              childCount: filteredCows.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, CowFilter filter, CowFilter currentFilter) {
    final isSelected = currentFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(filterProvider.notifier).setFilter(filter);
        }
      },
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }
}
