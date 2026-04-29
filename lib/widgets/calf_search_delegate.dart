import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/widgets/cow_id_badge.dart';
import 'package:cow_pregnancy/screens/calf_detail_screen.dart';
import 'package:intl/intl.dart';

class CalfSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  CalfSearchDelegate(this.ref) : super(
    searchFieldLabel: 'ابحث برقم العجل/الأم...',
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
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final cows = ref.read(cowProvider);
    List<Map<String, dynamic>> calves = [];

    // Extract calves logic (copied from CalvesScreen)
    for (var cow in cows) {
      for (var event in cow.history) {
        final title = event['title']?.toString() ?? '';
        if (title == 'تسجيل ولادة' || title == 'تسجيل ولادة سابقة') {
          calves.add({
            ...event,
            'motherId': cow.id,
            'motherUniqueKey': cow.uniqueKey,
            'motherColor': cow.color,
            'originalEventDate': event['date'],
          });
        }
      }
    }

    final results = query.isEmpty 
        ? calves 
        : calves.where((calf) {
            final calfId = (calf['calfId'] ?? '').toString();
            final motherId = (calf['motherId'] ?? '').toString();
            return calfId.contains(query) || motherId.contains(query);
          }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('لا توجد نتائج مطابقة', style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final calf = results[index];
        return _buildCalfCard(context, calf);
      },
    );
  }

  Widget _buildCalfCard(BuildContext context, Map<String, dynamic> calf) {
    int colorValue = calf['calfColorValue'] ?? (calf['note'].toString().contains('ذكر') ? Colors.blue.toARGB32() : Colors.pink.toARGB32());
    final calfColor = Color(colorValue);
    final isMale = calf['note'].toString().contains('ذكر');
    final isExited = calf['isExited'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CalfDetailScreen(calfData: calf),
          ));
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: calfColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(isMale ? Icons.male : Icons.female, color: calfColor),
        ),
        title: Row(
          children: [
            CowIdBadge(
              id: calf['calfId']?.toString() ?? 'بدون رقم',
              color: calfColor,
              fontSize: 12,
              boxSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            ),
            if (isExited) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('مستبعد', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('تاريخ الولادة: ${DateFormat('yyyy/MM/dd').format(DateTime.parse(calf['date']))}'),
            Row(
              children: [
                const Text('الأم: ', style: TextStyle(fontSize: 12)),
                CowIdBadge(
                  id: calf['motherId'].toString(),
                  color: calf['motherColor'] ?? Colors.grey,
                  fontSize: 10,
                  boxSize: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}
