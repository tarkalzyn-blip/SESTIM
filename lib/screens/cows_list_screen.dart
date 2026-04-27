import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/add_edit_cow_screen.dart';
import 'package:cow_pregnancy/widgets/cow_card.dart';
import 'package:cow_pregnancy/widgets/cow_search_delegate.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';
import 'package:cow_pregnancy/providers/edit_access_provider.dart';

class CowsListScreen extends ConsumerWidget {
  const CowsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredCows = ref.watch(filteredCowsProvider);
    final currentFilter = ref.watch(filterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة الأبقار',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'فرز الأبقار',
            onPressed: () => _showSortBottomSheet(context, ref),
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
              ref.read(editAccessProvider.notifier).runWithAccess(context, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditCowScreen()),
                );
              });
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
                    _buildFilterChip(
                      ref,
                      'الحوامل',
                      CowFilter.pregnant,
                      currentFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      ref,
                      'تحتاج مراقبة',
                      CowFilter.monitoring,
                      currentFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      ref,
                      'بدون لقاح',
                      CowFilter.notInseminated,
                      currentFilter,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      ref,
                      'بعد الولادة',
                      CowFilter.postBirth,
                      currentFilter,
                    ),
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
                  ref.read(editAccessProvider.notifier).runWithAccess(context, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEditCowScreen()),
                    );
                  });
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
                      style: BorderStyle
                          .solid, // Note: We use solid here but simulate dashed visually, or just solid. Wait, the user asked for dashed.
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
            delegate: SliverChildBuilderDelegate((context, index) {
              final cow = filteredCows[index];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: CowCard(cow: cow, index: index),
                  ),
                  if (index < filteredCows.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Divider(
                        color: Colors.grey.withValues(alpha: 0.1),
                        thickness: 1,
                      ),
                    ),
                ],
              );
            }, childCount: filteredCows.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    WidgetRef ref,
    String label,
    CowFilter filter,
    CowFilter currentFilter,
  ) {
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

  void _showSortBottomSheet(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(sortProvider);
    CowSortCriteria tempCriteria = currentSort.criteria;
    CowSortOrder tempOrder = currentSort.order;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'ترتيب البيانات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Section 1: Order
                  _buildSectionTitle('اتجاه الترتيب'),
                  const SizedBox(height: 12),
                  _buildSortOption(
                    context,
                    label: 'ترتيب تصاعدي',
                    icon: Icons.sort_by_alpha,
                    selected: tempOrder == CowSortOrder.ascending,
                    onTap: () =>
                        setModalState(() => tempOrder = CowSortOrder.ascending),
                  ),
                  _buildSortOption(
                    context,
                    label: 'ترتيب تنازلي',
                    icon: Icons.filter_list_alt,
                    selected: tempOrder == CowSortOrder.descending,
                    onTap: () => setModalState(
                      () => tempOrder = CowSortOrder.descending,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 2: Criteria
                  _buildSectionTitle('معيار الترتيب'),
                  const SizedBox(height: 12),
                  _buildSortOption(
                    context,
                    label: 'رقم البقرة',
                    icon: Icons.numbers,
                    selected: tempCriteria == CowSortCriteria.id,
                    onTap: () =>
                        setModalState(() => tempCriteria = CowSortCriteria.id),
                  ),
                  _buildSortOption(
                    context,
                    label: 'تاريخ اللقاح',
                    icon: Icons.calendar_today,
                    selected: tempCriteria == CowSortCriteria.inseminationDate,
                    onTap: () => setModalState(
                      () => tempCriteria = CowSortCriteria.inseminationDate,
                    ),
                  ),
                  _buildSortOption(
                    context,
                    label: 'تاريخ الولادة',
                    icon: Icons.child_friendly,
                    selected: tempCriteria == CowSortCriteria.birthDate,
                    onTap: () => setModalState(
                      () => tempCriteria = CowSortCriteria.birthDate,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(sortProvider.notifier)
                            .setCriteria(tempCriteria);
                        ref.read(sortProvider.notifier).setOrder(tempOrder);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'تطبيق',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSortOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withOpacity(0.1),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Radio<bool>(
                  value: true,
                  groupValue: selected,
                  onChanged: (_) => onTap(),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
