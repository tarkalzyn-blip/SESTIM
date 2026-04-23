import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/services/notification_service.dart';

class CowNotifier extends Notifier<List<Cow>> {
  @override
  List<Cow> build() {
    return Hive.box<Cow>('cows').values.toList();
  }

  Future<void> addCow(Cow cow) async {
    await Hive.box<Cow>('cows').put(cow.uniqueKey, cow);
    await NotificationService().scheduleCowNotifications(cow);
    state = Hive.box<Cow>('cows').values.toList();
  }

  Future<void> updateCow(Cow cow, {String? oldKey}) async {
    final box = Hive.box<Cow>('cows');
    if (oldKey != null && oldKey != cow.uniqueKey) {
      await box.delete(oldKey);
      await NotificationService().cancelCowNotifications(oldKey);
    }
    await box.put(cow.uniqueKey, cow);
    await NotificationService().scheduleCowNotifications(cow);
    state = box.values.toList();
  }

  Future<void> deleteCow(String uniqueKey) async {
    await Hive.box<Cow>('cows').delete(uniqueKey);
    await NotificationService().cancelCowNotifications(uniqueKey);
    state = Hive.box<Cow>('cows').values.toList();
  }
}

final cowProvider = NotifierProvider<CowNotifier, List<Cow>>(() {
  return CowNotifier();
});

enum CowFilter { all, pregnant, monitoring, notInseminated, postBirth }
enum CowSort { none, closestToEvent }

class SortNotifier extends Notifier<CowSort> {
  @override
  CowSort build() => CowSort.none;

  void setSort(CowSort sort) {
    state = sort;
  }
}

final sortProvider = NotifierProvider<SortNotifier, CowSort>(() {
  return SortNotifier();
});

class FilterNotifier extends Notifier<CowFilter> {
  @override
  CowFilter build() => CowFilter.all;

  void setFilter(CowFilter filter) {
    state = filter;
  }
}

final filterProvider = NotifierProvider<FilterNotifier, CowFilter>(() {
  return FilterNotifier();
});

final filteredCowsProvider = Provider<List<Cow>>((ref) {
  final filter = ref.watch(filterProvider);
  final sort = ref.watch(sortProvider);
  final cows = ref.watch(cowProvider);

  List<Cow> result;

  switch (filter) {
    case CowFilter.all:
      result = cows;
      break;
    case CowFilter.pregnant:
      result = cows.where((c) => !c.isPostBirth && c.isInseminated && c.daysSinceInsemination > 60).toList();
      break;
    case CowFilter.monitoring:
      result = cows.where((c) => !c.isPostBirth && (c.status.contains('راقب') || !c.isInseminated)).toList();
      break;
    case CowFilter.notInseminated:
      result = cows.where((c) => !c.isInseminated || c.isPostBirth).toList();
      break;
    case CowFilter.postBirth:
      result = cows.where((c) => c.isPostBirth).toList();
      break;
  }

  if (sort == CowSort.closestToEvent) {
    result = List.from(result)..sort((a, b) => b.pregnancyPercentage.compareTo(a.pregnancyPercentage));
  } else {
    result = List.from(result)..sort((a, b) => a.id.compareTo(b.id));
  }

  return result;
});
