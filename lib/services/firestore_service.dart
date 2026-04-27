import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _cowsCollection => _db.collection('users').doc(_userId).collection('cows');
  CollectionReference get _notesCollection => _db.collection('users').doc(_userId).collection('notes');
  DocumentReference get _settingsDoc => _db.collection('users').doc(_userId).collection('settings').doc('security');

  /// Stream of Firebase Auth UID changes (null when logged out)
  Stream<String?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user?.uid);

  // Stream of cows for the current user
  Stream<List<Cow>> get cowsStream {
    if (_userId == null) return Stream.value([]);
    return _cowsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Cow.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Stream of notes for the current user
  Stream<List<Map<String, dynamic>>> get notesStream {
    if (_userId == null) return Stream.value([]);
    return _notesCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  // Stream of security settings
  Stream<Map<String, dynamic>?> get securitySettingsStream {
    if (_userId == null) return Stream.value(null);
    return _settingsDoc.snapshots().map((doc) => doc.data() as Map<String, dynamic>?);
  }

  Future<void> updateSecuritySettings(Map<String, dynamic> settings) async {
    if (_userId == null) return;
    await _settingsDoc.set(settings, SetOptions(merge: true));
  }

  // Save or update cow
  Future<void> saveCow(Cow cow) async {
    if (_userId == null) return;
    try {
      final cowWithUser = cow.copyWith(userId: _userId);
      await _cowsCollection.doc(cow.uniqueKey).set(cowWithUser.toMap());
    } catch (e) {
      debugPrint("Firestore Error saving cow: $e");
      rethrow;
    }
  }

  // Save or update note
  Future<void> saveNote(Map<String, dynamic> noteMap) async {
    if (_userId == null) return;
    try {
      noteMap['userId'] = _userId;
      await _notesCollection.doc(noteMap['id']).set(noteMap);
    } catch (e) {
      debugPrint("Firestore Error saving note: $e");
      rethrow;
    }
  }

  // Delete cow
  Future<void> deleteCow(String uniqueKey) async {
    if (_userId == null) return;
    try {
      await _cowsCollection.doc(uniqueKey).delete();
    } catch (e) {
      debugPrint("Firestore Error deleting cow: $e");
      rethrow;
    }
  }

  // Delete note
  Future<void> deleteNote(String noteId) async {
    if (_userId == null) return;
    try {
      await _notesCollection.doc(noteId).delete();
    } catch (e) {
      debugPrint("Firestore Error deleting note: $e");
      rethrow;
    }
  }

  // Initial sync from local to cloud
  Future<void> syncLocalToCloud(List<Cow> localCows) async {
    if (_userId == null) return;
    try {
      final batch = _db.batch();
      for (var cow in localCows) {
        final cowWithUser = cow.copyWith(userId: _userId);
        batch.set(_cowsCollection.doc(cow.uniqueKey), cowWithUser.toMap());
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Firestore Error batch sync cows: $e");
      rethrow;
    }
  }

  // Sync notes from local to cloud
  Future<void> syncLocalNotesToCloud(List<Map<String, dynamic>> localNotes) async {
    if (_userId == null) return;
    try {
      final batch = _db.batch();
      for (var note in localNotes) {
        note['userId'] = _userId;
        batch.set(_notesCollection.doc(note['id']), note);
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Firestore Error batch sync notes: $e");
      rethrow;
    }
  }
}
