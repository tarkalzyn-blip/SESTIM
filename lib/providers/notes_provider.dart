import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cow_pregnancy/services/firestore_service.dart';
import 'package:cow_pregnancy/providers/auth_provider.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ==============================
// NoteModel
// ==============================
class NoteModel {
  final String id;
  final String cowId;
  final int cowColorValue;
  final String noteText;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime? reminderDate;
  final String? userId;

  NoteModel({
    required this.id,
    required this.cowId,
    required this.cowColorValue,
    required this.noteText,
    required this.createdAt,
    required this.startDate,
    this.reminderDate,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cowId': cowId,
      'cowColorValue': cowColorValue,
      'noteText': noteText,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'reminderDate': reminderDate?.toIso8601String(),
      'userId': userId,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'],
      cowId: map['cowId'],
      cowColorValue: map['cowColorValue'],
      noteText: map['noteText'],
      createdAt: DateTime.parse(map['createdAt']),
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : DateTime.parse(map['createdAt']),
      reminderDate:
          map['reminderDate'] != null ? DateTime.parse(map['reminderDate']) : null,
      userId: map['userId'],
    );
  }

  NoteModel copyWith({String? userId, DateTime? reminderDate}) {
    return NoteModel(
      id: id,
      cowId: cowId,
      cowColorValue: cowColorValue,
      noteText: noteText,
      createdAt: createdAt,
      startDate: startDate,
      reminderDate: reminderDate ?? this.reminderDate,
      userId: userId ?? this.userId,
    );
  }

  /// Stable integer ID for notifications — consistent across devices
  int get notificationId => id.substring(0, 8).hashCode.abs();
}

// ==============================
// NotesNotifier
// ==============================
class NotesNotifier extends Notifier<List<NoteModel>> {
  final FirestoreService _firestore = FirestoreService();
  StreamSubscription<List<Map<String, dynamic>>>? _cloudSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;
  String? _listeningForUserId;

  @override
  List<NoteModel> build() {
    // Load local notes from Hive only — do NOT watch appUserProvider here
    // to avoid rebuild loops. We listen for auth changes separately.
    final box = Hive.box('notes_box');
    final localNotes = box.values
        .map((e) => NoteModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // Start listening after the first build
    Future.microtask(() => _initSync());

    ref.onDispose(() {
      _cloudSubscription?.cancel();
      _connectivitySubscription?.cancel();
    });

    return localNotes;
  }

  /// Called once after build — sets up auth watcher & connectivity
  void _initSync() {
    // Watch auth state changes via a separate stream (not inside build)
    _firestore.authStateChanges.listen((uid) {
      if (uid != null && uid != _listeningForUserId) {
        _listeningForUserId = uid;
        _startCloudListener();
        _startConnectivityListener();
      } else if (uid == null) {
        _listeningForUserId = null;
        _cloudSubscription?.cancel();
        _cloudSubscription = null;
      }
    });
  }

  void _startCloudListener() {
    _cloudSubscription?.cancel();
    _cloudSubscription = _firestore.notesStream.listen(
      (cloudData) async {
        final cloudNotes =
            cloudData.map((m) => NoteModel.fromMap(m)).toList();
        final box = Hive.box('notes_box');

        // Compare content to detect ANY change (not just count)
        final localJson = jsonEncode(
            box.values.map((e) => Map<String, dynamic>.from(e)).toList());
        final cloudJson =
            jsonEncode(cloudNotes.map((n) => n.toMap()).toList());

        if (cloudJson != localJson) {
          await box.clear();
          for (var note in cloudNotes) {
            await box.put(note.id, note.toMap());
            // Re-schedule reminder if it's still in the future
            if (note.reminderDate != null &&
                note.reminderDate!.isAfter(DateTime.now())) {
              await NotificationService().scheduleCustomNotification(
                id: note.notificationId,
                title: 'تذكير: بقرة #${note.cowId}',
                body: note.noteText,
                scheduledDate: note.reminderDate!,
              );
            }
          }
          state = cloudNotes;
        }
      },
      onError: (e) => debugPrint('Cloud notes stream error: $e'),
    );
  }

  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && _wasOffline) {
        _wasOffline = false;
        syncLocalToCloud();
        _startCloudListener();
      } else if (!isConnected) {
        _wasOffline = true;
        _cloudSubscription?.cancel();
      }
    });
  }

  // ---- CRUD ----

  Future<void> addNote(NoteModel note) async {
    final user = ref.read(appUserProvider);
    final noteWithUser = note.copyWith(userId: user?.id);

    await Hive.box('notes_box').put(note.id, noteWithUser.toMap());
    state = [noteWithUser, ...state];

    if (user != null) {
      try {
        await _firestore.saveNote(noteWithUser.toMap());
      } catch (e) {
        debugPrint('Notes Cloud Save Error: $e');
      }
    }
  }

  Future<void> updateNote(NoteModel updatedNote) async {
    final user = ref.read(appUserProvider);
    final noteWithUser = updatedNote.copyWith(userId: user?.id);

    await Hive.box('notes_box').put(updatedNote.id, noteWithUser.toMap());
    state = state
        .map((n) => n.id == updatedNote.id ? noteWithUser : n)
        .toList();

    if (user != null) {
      try {
        await _firestore.saveNote(noteWithUser.toMap());
      } catch (e) {
        debugPrint('Notes Cloud Update Error: $e');
      }
    }
  }

  Future<void> deleteNote(String id) async {
    final user = ref.read(appUserProvider);
    final note = state.firstWhere((n) => n.id == id, orElse: () => state.first);

    await Hive.box('notes_box').delete(id);
    state = state.where((n) => n.id != id).toList();

    // Cancel using the SAME stable ID used when scheduling
    await NotificationService().cancelCustomNotification(note.notificationId);

    if (user != null) {
      try {
        await _firestore.deleteNote(id);
      } catch (e) {
        debugPrint('Notes Cloud Delete Error: $e');
      }
    }
  }

  Future<void> syncLocalToCloud() async {
    final user = ref.read(appUserProvider);
    if (user == null) return;

    final box = Hive.box('notes_box');
    final localNotes = box.values.map((e) {
      final map = Map<String, dynamic>.from(e);
      map['userId'] = user.id;
      return map;
    }).toList();

    try {
      await _firestore.syncLocalNotesToCloud(localNotes);
    } catch (e) {
      debugPrint('Notes Bulk Sync Error: $e');
    }
  }
}

final notesProvider =
    NotifierProvider<NotesNotifier, List<NoteModel>>(() {
  return NotesNotifier();
});
