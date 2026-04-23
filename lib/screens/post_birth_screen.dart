import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/widgets/cow_card.dart';
import 'package:cow_pregnancy/screens/add_edit_cow_screen.dart';

class PostBirthScreen extends ConsumerWidget {
  const PostBirthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCows = ref.watch(cowProvider);
    final postBirthCows = allCows.where((c) => c.isPostBirth).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أبقار بعد الولادة (التعافي)', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: postBirthCows.isEmpty
          ? const Center(
              child: Text(
                'لا توجد أبقار في مرحلة ما بعد الولادة حالياً.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: postBirthCows.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final cow = postBirthCows[index];
                return Column(
                  children: [
                    Dismissible(
                      key: Key('post_birth_${cow.uniqueKey}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
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
                      onDismissed: (_) => ref.read(cowProvider.notifier).deleteCow(cow.uniqueKey),
                      child: Stack(
                        children: [
                          CowCard(cow: cow, index: index),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Row(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => AddEditCowScreen(cow: cow),
                                      ));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit, size: 18, color: Colors.teal),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('حذف البقرة'),
                                          content: Text('هل أنت متأكد من حذف البقرة رقم ${cow.id}؟'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        ref.read(cowProvider.notifier).deleteCow(cow.uniqueKey);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index == postBirthCows.length - 1) const SizedBox(height: 100),
                  ],
                );
              },
            ),
    );
  }
}
