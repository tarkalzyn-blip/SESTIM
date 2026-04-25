import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _cowsCollection => _db.collection('users').doc(_userId).collection('cows');

  // Stream of cows for the current user
  Stream<List<Cow>> get cowsStream {
    if (_userId == null) return Stream.value([]);
    return _cowsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Cow.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Save or update cow
  Future<void> saveCow(Cow cow) async {
    if (_userId == null) {
      debugPrint("Firestore: Cannot save, user not logged in.");
      return;
    }
    try {
      final cowWithUser = cow.copyWith(userId: _userId);
      await _cowsCollection.doc(cow.uniqueKey).set(cowWithUser.toMap());
      debugPrint("Firestore: Success saving cow ${cow.id}");
    } catch (e) {
      debugPrint("Firestore Error saving cow: $e");
      rethrow;
    }
  }

  // Delete cow
  Future<void> deleteCow(String uniqueKey) async {
    if (_userId == null) return;
    try {
      await _cowsCollection.doc(uniqueKey).delete();
      debugPrint("Firestore: Success deleting cow $uniqueKey");
    } catch (e) {
      debugPrint("Firestore Error deleting cow: $e");
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
      debugPrint("Firestore: Success batch sync ${localCows.length} cows");
    } catch (e) {
      debugPrint("Firestore Error batch sync: $e");
      rethrow;
    }
  }
}
