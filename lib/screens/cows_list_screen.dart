import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/add_edit_cow_screen.dart';
import 'package:cow_pregnancy/widgets/cow_card.dart';
import 'package:cow_pregnancy/widgets/cow_search_delegate.dart';

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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cow = filteredCows[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Dismissible(
                    key: Key('cow_${cow.uniqueKey}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white, size: 30),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف البقرة'),
                          content: Text('هل أنت متأكد من حذف البقرة رقم ${cow.id}؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('حذف', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      ref.read(cowProvider.notifier).deleteCow(cow.uniqueKey);
                    },
                    child: CowCard(cow: cow, index: index),
                  ),
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
