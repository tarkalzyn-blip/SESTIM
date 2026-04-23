import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/screens/settings_screen.dart';
import 'package:intl/intl.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cows = ref.watch(cowProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ── Data Extraction ──────────────────────────────────────────
    List<Map<String, dynamic>> births = [];
    List<Map<String, dynamic>> sales = [];
    List<Map<String, dynamic>> deaths = [];
    List<Map<String, dynamic>> inseminations = [];

    for (var cow in cows) {
      for (var event in cow.history) {
        final title = event['title']?.toString() ?? '';
        
        // Births
        if (title == 'تسجيل ولادة' || title == 'تسجيل ولادة سابقة') {
          births.add({...event, 'motherId': cow.id});
          
          if (event['isExited'] == true) {
            final reason = event['exitReason']?.toString() ?? '';
            if (reason == 'بيع') {
              sales.add({...event, 'motherId': cow.id});
            } else if (reason == 'وفاة') {
              deaths.add({...event, 'motherId': cow.id});
            }
          }
        }
        
        // Inseminations
        if (title == 'تسجيل تلقيح') {
          inseminations.add({...event, 'cowId': cow.id});
        }
      }
    }

    // Sort by date descending
    births.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    sales.sort((a, b) => (b['exitDate'] ?? '').toString().compareTo((a['exitDate'] ?? '').toString()));
    deaths.sort((a, b) => (b['exitDate'] ?? '').toString().compareTo((a['exitDate'] ?? '').toString()));
    inseminations.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('📜 سجل النشاطات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(icon: Icon(Icons.monetization_on, size: 20), text: 'المبيعات'),
            Tab(icon: Icon(Icons.child_friendly, size: 20), text: 'الولادات'),
            Tab(icon: Icon(Icons.dangerous, size: 20), text: 'الوفيات'),
            Tab(icon: Icon(Icons.science, size: 20), text: 'التلقيح'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesList(sales, isDark),
          _buildBirthsList(births, isDark),
          _buildDeathsList(deaths, isDark),
          _buildInseminationsList(inseminations, isDark),
        ],
      ),
    );
  }

  Widget _buildRecoveryList(List<dynamic> items, bool isDark) {
    if (items.isEmpty) return _emptyState('لا توجد أبقار في مرحلة التعافي');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildRecoveryCard(items[i], isDark),
    );
  }

  Widget _buildSalesList(List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) return _emptyState('لا توجد مبيعات مسجلة');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildLogCard(items[i], LogType.sale, isDark),
    );
  }

  Widget _buildBirthsList(List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) return _emptyState('لا توجد ولادات مسجلة');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildLogCard(items[i], LogType.birth, isDark),
    );
  }

  Widget _buildDeathsList(List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) return _emptyState('لا توجد وفيات مسجلة');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildLogCard(items[i], LogType.death, isDark),
    );
  }

  Widget _buildInseminationsList(List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) return _emptyState('لا توجد تلقيحات مسجلة');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _buildLogCard(items[i], LogType.insemination, isDark),
    );
  }

  Widget _emptyState(String msg) => Center(child: Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 16)));

  Widget _buildRecoveryCard(dynamic cow, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.medical_services, color: Colors.teal),
        ),
        title: Text('البقرة رقم ${cow.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('تاريخ الولادة: ${DateFormat('yyyy/MM/dd').format(cow.birthDate!)}', style: const TextStyle(fontSize: 12)),
            Text('مرّ ${cow.daysSinceBirth} يوم من فترة التعافي', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: cow.pregnancyPercentage, // This getter handles recovery % in the model
                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                color: Colors.teal,
                minHeight: 6,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: cow.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(cow.status, style: TextStyle(color: cow.color, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> item, LogType type, bool isDark) {
    final date = DateTime.parse(item[type == LogType.sale || type == LogType.death ? 'exitDate' : 'date']);
    final birthDate = DateTime.parse(item['date']);
    final ageDays = type == LogType.sale || type == LogType.death 
        ? date.difference(birthDate).inDays 
        : 0;

    String title = '';
    IconData icon = Icons.info;
    Color color = Colors.blue;

    switch (type) {
      case LogType.sale:
        title = 'بيع عجل رقم ${item['calfId'] ?? 'غير معروف'}';
        icon = Icons.attach_money;
        color = Colors.green;
        break;
      case LogType.birth:
        title = 'ولادة عجل رقم ${item['calfId'] ?? 'غير معروف'}';
        icon = Icons.child_friendly;
        color = Colors.blue;
        break;
      case LogType.death:
        title = 'وفاة عجل رقم ${item['calfId'] ?? 'غير معروف'}';
        icon = Icons.priority_high;
        color = Colors.red;
        break;
      case LogType.insemination:
        title = 'تلقيح البقرة ${item['cowId']}';
        icon = Icons.science;
        color = Colors.purple;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(date)}', style: const TextStyle(fontSize: 12)),
            if (type == LogType.sale) ...[
              Text('السعر: ${item['exitPrice'] ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Text('العمر عند البيع: $ageDays يوم', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
            if (type == LogType.death) ...[
              Text('العمر عند الوفاة: $ageDays يوم', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              if (item['note'] != null && item['note'].toString().isNotEmpty)
                Text('الملاحظات: ${item['note']}', style: const TextStyle(fontSize: 11)),
            ],
            if (type == LogType.birth)
              Text('الأم: ${item['motherId']}', style: const TextStyle(fontSize: 12)),
            if (type == LogType.insemination)
              Text('ملاحظات: ${item['note'] ?? 'لا يوجد'}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: type == LogType.birth ? _genderBadge(item['note'] ?? '') : null,
      ),
    );
  }

  Widget _genderBadge(String note) {
    final isMale = note.contains('ذكر');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isMale ? Colors.blue : Colors.pink).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isMale ? 'ذكر' : 'أنثى',
        style: TextStyle(color: isMale ? Colors.blue : Colors.pink, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}

enum LogType { birth, sale, death, insemination }
