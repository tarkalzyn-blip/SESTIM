import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/widgets/cow_card.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class CowSearchDelegate extends SearchDelegate<Cow?> {
  final WidgetRef ref;

  CowSearchDelegate(this.ref) : super(
    searchFieldLabel: 'ابحث برقم البقرة...',
    searchFieldStyle: const TextStyle(fontSize: 18),
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final cows = ref.read(cowProvider);
    final exactMatch = AppSettings.exactSearchMatch;
    
    final results = query.isEmpty 
        ? cows 
        : cows.where((cow) => exactMatch ? cow.id == query : cow.id.contains(query)).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('لا توجد أبقار مطابقة للبحث', style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: CowCard(cow: results[index], index: index),
        );
      },
    );
  }
}
