import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:cow_pregnancy/services/firestore_service.dart';
import 'package:cow_pregnancy/providers/auth_provider.dart';
import 'package:cow_pregnancy/providers/theme_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CowNotifier extends Notifier<List<Cow>> {
  final FirestoreService _firestore = FirestoreService();
  StreamSubscription<List<Cow>>? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isInitialized = false;
  bool _wasOffline = false;

  @override
  List<Cow> build() {
    final localCows = Hive.box<Cow>('cows').values.toList();
    
    // Efficiently manage cloud listening
    if (!_isInitialized) {
      _isInitialized = true;
      Future.microtask(() {
        _startListeningToCloud();
        _startConnectivityListener();
      });
    }
    
    ref.onDispose(() {
      _subscription?.cancel();
      _connectivitySubscription?.cancel();
    });
    
    return localCows;
  }

  void _startListeningToCloud() {
    final user = ref.read(appUserProvider);
    if (user == null) return;

    _subscription?.cancel();
    _subscription = _firestore.cowsStream.listen((cloudCows) async {
      final box = Hive.box<Cow>('cows');
      
      // Smart Sync: Only update local if there's a real difference
      final localCows = box.values.toList();
      if (_hasDataChanged(cloudCows, localCows)) {
        // Use putAll for much faster bulk writing instead of clearing and looping
        final Map<String, Cow> cowMap = {for (var c in cloudCows) c.uniqueKey: c};
        await box.clear();
        await box.putAll(cowMap);
        state = cloudCows;
      }
    }, onError: (e) => debugPrint("Sync Error: $e"));
  }

  bool _hasDataChanged(List<Cow> cloud, List<Cow> local) {
    if (cloud.length != local.length) return true;
    
    for (int i = 0; i < cloud.length; i++) {
      if (cloud[i].uniqueKey != local[i].uniqueKey || 
          cloud[i].status != local[i].status ||
          cloud[i].history.length != local[i].history.length) {
        return true;
      }
    }
    return false; 
  }

  void _stopListeningToCloud() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && _wasOffline) {
        debugPrint('🌐 الإنترنت عاد - بدء المزامنة التلقائية...');
        _wasOffline = false;
        syncLocalToCloud();
        _startListeningToCloud();
      } else if (!isConnected) {
        _wasOffline = true;
        debugPrint('📴 لا يوجد إنترنت - العمل محلياً فقط');
        _subscription?.cancel();
      }
    });
  }

  Future<void> addCow(Cow cow) async {
    final user = ref.read(appUserProvider);
    final cowWithUser = cow.copyWith(userId: user?.id);
    
    final box = Hive.box<Cow>('cows');
    await box.put(cow.uniqueKey, cowWithUser);
    
    final updatedList = box.values.toList();
    state = updatedList;
    
    NotificationService().scheduleCowNotifications(cowWithUser);
    
    if (user != null) {
      _firestore.saveCow(cowWithUser).then((_) {
        ref.read(syncStatusProvider.notifier).setStatus(null);
      }).catchError((e) {
        debugPrint("Firestore save failed: $e");
        ref.read(syncStatusProvider.notifier).setStatus("فشل المزامنة: $e");
      });
    }
  }

  Future<void> updateCow(Cow cow, {String? oldKey}) async {
    final user = ref.read(appUserProvider);
    final cowWithUser = cow.copyWith(userId: user?.id);
    
    final box = Hive.box<Cow>('cows');
    if (oldKey != null && oldKey != cow.uniqueKey) {
      await box.delete(oldKey);
      NotificationService().cancelCowNotifications(oldKey);
      if (user != null) {
        _firestore.deleteCow(oldKey).catchError((e) => debugPrint("Cloud delete fail: $e"));
      }
    }
    
    await box.put(cow.uniqueKey, cowWithUser);
    
    final updatedList = box.values.toList();
    state = updatedList;
    
    NotificationService().scheduleCowNotifications(cowWithUser);
    
    if (user != null) {
      _firestore.saveCow(cowWithUser).catchError((e) => debugPrint("Cloud update fail: $e"));
    }
  }

  Future<void> deleteCow(String uniqueKey) async {
    final user = ref.read(appUserProvider);
    final box = Hive.box<Cow>('cows');
    await box.delete(uniqueKey);
    
    state = box.values.toList();
    
    NotificationService().cancelCowNotifications(uniqueKey);
    
    if (user != null) {
      _firestore.deleteCow(uniqueKey).catchError((e) => debugPrint("Cloud delete fail: $e"));
    }
  }

  Future<void> syncLocalToCloud() async {
    final user = ref.read(appUserProvider);
    if (user != null) {
      try {
        final box = Hive.box<Cow>('cows');
        final localCows = box.values.toList();
        
        for (var cow in localCows) {
          if (cow.userId != user.id) {
            final updatedCow = cow.copyWith(userId: user.id);
            await box.put(updatedCow.uniqueKey, updatedCow);
          }
        }
        
        final updatedLocalCows = box.values.toList();
        await _firestore.syncLocalToCloud(updatedLocalCows);
        
        ref.read(syncStatusProvider.notifier).setStatus(null);
        state = updatedLocalCows; 
      } catch (e) {
        debugPrint("Firestore sync failed: $e");
        ref.read(syncStatusProvider.notifier).setStatus("فشل المزامنة الشاملة: $e");
      }
    }
  }
}

final cowProvider = NotifierProvider<CowNotifier, List<Cow>>(() {
  return CowNotifier();
});

enum CowFilter { all, pregnant, monitoring, notInseminated, postBirth, heifer }
enum CowSortCriteria { id, inseminationDate, birthDate }
enum CowSortOrder { ascending, descending }

class CowSortState {
  final CowSortCriteria criteria;
  final CowSortOrder order;

  const CowSortState({
    this.criteria = CowSortCriteria.id,
    this.order = CowSortOrder.ascending,
  });

  CowSortState copyWith({
    CowSortCriteria? criteria,
    CowSortOrder? order,
  }) {
    return CowSortState(
      criteria: criteria ?? this.criteria,
      order: order ?? this.order,
    );
  }
}

class SortNotifier extends Notifier<CowSortState> {
  @override
  CowSortState build() => const CowSortState();

  void setCriteria(CowSortCriteria criteria) {
    state = state.copyWith(criteria: criteria);
  }

  void setOrder(CowSortOrder order) {
    state = state.copyWith(order: order);
  }
}

final sortProvider = NotifierProvider<SortNotifier, CowSortState>(() {
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
  final allCows = ref.watch(cowProvider);

  // Filter out standalone calves from the cows list
  final cows = allCows.where((c) => !c.isStandaloneCalf).toList();

  List<Cow> result;

  switch (filter) {
    case CowFilter.all:
      result = cows;
      break;
    case CowFilter.pregnant:
      result = cows.where((c) => !c.isPostBirth && c.isInseminated && c.daysSinceInsemination > 25).toList();
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
    case CowFilter.heifer:
      result = cows.where((c) => c.isHeifer).toList();
      break;
  }

  final isAsc = sort.order == CowSortOrder.ascending;
  
  result = List.from(result)..sort((a, b) {
    int cmp;
    switch (sort.criteria) {
      case CowSortCriteria.id:
        final aNum = int.tryParse(a.id);
        final bNum = int.tryParse(b.id);
        if (aNum != null && bNum != null) {
          cmp = aNum.compareTo(bNum);
        } else {
          cmp = a.id.compareTo(b.id);
        }
        break;
      case CowSortCriteria.inseminationDate:
        cmp = a.inseminationDate.compareTo(b.inseminationDate);
        break;
      case CowSortCriteria.birthDate:
        final aDate = a.birthDate ?? DateTime(1900);
        final bDate = b.birthDate ?? DateTime(1900);
        cmp = aDate.compareTo(bDate);
        break;
    }
    return isAsc ? cmp : -cmp;
  });

  return result;
});

final allCalvesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final allCows = ref.watch(cowProvider);
  final List<Map<String, dynamic>> calves = [];

  for (var cow in allCows) {
    // 1. History-based calves (traditional)
    for (var event in cow.history) {
      final title = event['title']?.toString() ?? '';
      if (title == 'تسجيل ولادة' || title == 'تسجيل ولادة سابقة') {
        calves.add({
          ...event,
          'motherId': cow.id,
          'motherUniqueKey': cow.uniqueKey,
          'motherColor': cow.color,
          'originalEventDate': event['date'],
          'isStandalone': false,
        });
      }
    }
    
    // 2. Standalone calves
    if (cow.isStandaloneCalf) {
      calves.add({
        'calfId': cow.id,
        'calfColorValue': cow.colorValue,
        'date': cow.dateOfBirth?.toIso8601String() ?? cow.inseminationDate.toIso8601String(),
        'note': cow.gender == 'male' ? 'ذكر' : 'أنثى',
        'eventId': cow.uniqueKey,
        'motherId': cow.motherId ?? 'غير محدد',
        'motherUniqueKey': cow.uniqueKey, // Use its own key for identification if standalone
        'motherColor': Color(cow.motherColorValue ?? 0xFF9E9E9E),
        'originalEventDate': cow.dateOfBirth?.toIso8601String() ?? cow.inseminationDate.toIso8601String(),
        'isStandalone': true,
        'uniqueKey': cow.uniqueKey,
      });
    }
  }
  return calves;
});

final birthStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final calves = ref.watch(allCalvesProvider);
  
  int totalCalves = 0, maleCalves = 0, femaleCalves = 0;
  int exitedSold = 0, exitedDead = 0, exitedTransfer = 0, exitedDeleted = 0;
  
  for (var calf in calves) {
    if (calf['isExited'] == true) {
      final reason = calf['exitReason'].toString().toLowerCase();
      if (reason.contains('بيع')) exitedSold++;
      else if (reason.contains('موت')) exitedDead++;
      else if (reason.contains('نقل')) exitedTransfer++;
      else exitedDeleted++;
      continue;
    }

    totalCalves++;
    final note = calf['note'].toString().toLowerCase();
    if (note.contains('ذكر') || note.contains('عجل')) {
      maleCalves++;
    } else {
      femaleCalves++;
    }
  }

  return {
    'total': totalCalves,
    'male': maleCalves,
    'female': femaleCalves,
    'sold': exitedSold,
    'dead': exitedDead,
    'transfer': exitedTransfer,
    'deleted': exitedDeleted,
    'active': totalCalves,
  };
});
