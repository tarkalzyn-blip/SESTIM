import 'dart:async';
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
    
    // Check if any cow has a different ID or status (simple but effective check)
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

  /// يراقب الاتصال بالإنترنت ويمزامن البيانات تلقائياً عند عودته
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
    
    await Hive.box<Cow>('cows').put(cow.uniqueKey, cowWithUser);
    
    // Update state immediately for responsive UI (Optimistic UI)
    state = Hive.box<Cow>('cows').values.toList();
    
    await NotificationService().scheduleCowNotifications(cowWithUser);
    
    if (user != null) {
      try {
        await _firestore.saveCow(cowWithUser);
        ref.read(syncStatusProvider.notifier).setStatus(null);
      } catch (e) {
        debugPrint("Firestore save failed: $e");
        ref.read(syncStatusProvider.notifier).setStatus("فشل المزامنة: $e");
      }
    }
  }

  Future<void> updateCow(Cow cow, {String? oldKey}) async {
    final user = ref.read(appUserProvider);
    final cowWithUser = cow.copyWith(userId: user?.id);
    
    final box = Hive.box<Cow>('cows');
    if (oldKey != null && oldKey != cow.uniqueKey) {
      await box.delete(oldKey);
      await NotificationService().cancelCowNotifications(oldKey);
      if (user != null) {
        try {
          await _firestore.deleteCow(oldKey);
          ref.read(syncStatusProvider.notifier).setStatus(null);
        } catch (e) {
          debugPrint("Firestore delete failed: $e");
          ref.read(syncStatusProvider.notifier).setStatus("فشل الحذف السحابي: $e");
        }
      }
    }
    
    await box.put(cow.uniqueKey, cowWithUser);
    
    // Update state immediately for responsive UI
    state = box.values.toList();
    
    await NotificationService().scheduleCowNotifications(cowWithUser);
    
    if (user != null) {
      try {
        await _firestore.saveCow(cowWithUser);
        ref.read(syncStatusProvider.notifier).setStatus(null);
      } catch (e) {
        debugPrint("Firestore save failed: $e");
        ref.read(syncStatusProvider.notifier).setStatus("فشل المزامنة: $e");
      }
    }
  }

  Future<void> deleteCow(String uniqueKey) async {
    final user = ref.read(appUserProvider);
    await Hive.box<Cow>('cows').delete(uniqueKey);
    
    // Update state immediately for responsive UI
    state = Hive.box<Cow>('cows').values.toList();
    
    await NotificationService().cancelCowNotifications(uniqueKey);
    
    if (user != null) {
      try {
        await _firestore.deleteCow(uniqueKey);
        ref.read(syncStatusProvider.notifier).setStatus(null);
      } catch (e) {
        debugPrint("Firestore delete failed: $e");
        ref.read(syncStatusProvider.notifier).setStatus("فشل الحذف السحابي: $e");
      }
    }
  }

  Future<void> syncLocalToCloud() async {
    final user = ref.read(appUserProvider);
    if (user != null) {
      try {
        final box = Hive.box<Cow>('cows');
        final localCows = box.values.toList();
        
        // Force update all local cows to the CURRENT user's ID to avoid permission conflicts
        for (var cow in localCows) {
          if (cow.userId != user.id) {
            final updatedCow = cow.copyWith(userId: user.id);
            await box.put(updatedCow.uniqueKey, updatedCow);
          }
        }
        
        final updatedLocalCows = box.values.toList();
        await _firestore.syncLocalToCloud(updatedLocalCows);
        
        ref.read(syncStatusProvider.notifier).setStatus(null);
        state = updatedLocalCows; // Refresh UI
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

enum CowFilter { all, pregnant, monitoring, notInseminated, postBirth }
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
  final cows = ref.watch(cowProvider);

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
  }

  final isAsc = sort.order == CowSortOrder.ascending;
  
  result = List.from(result)..sort((a, b) {
    int cmp;
    switch (sort.criteria) {
      case CowSortCriteria.id:
        // Try to sort numerically if possible
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
