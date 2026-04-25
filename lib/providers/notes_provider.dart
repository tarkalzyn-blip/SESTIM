import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoteModel {
  final String id;
  final String cowId;
  final int cowColorValue;
  final String noteText;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime? reminderDate;

  NoteModel({
    required this.id,
    required this.cowId,
    required this.cowColorValue,
    required this.noteText,
    required this.createdAt,
    required this.startDate,
    this.reminderDate,
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
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'],
      cowId: map['cowId'],
      cowColorValue: map['cowColorValue'],
      noteText: map['noteText'],
      createdAt: DateTime.parse(map['createdAt']),
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.parse(map['createdAt']),
      reminderDate: map['reminderDate'] != null ? DateTime.parse(map['reminderDate']) : null,
    );
  }
}

class NotesNotifier extends Notifier<List<NoteModel>> {
  static const String _key = 'user_notes';

  @override
  List<NoteModel> build() {
    _loadNotes();
    return [];
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString(_key);
    if (notesJson != null) {
      final List<dynamic> decoded = jsonDecode(notesJson);
      state = decoded.map((map) => NoteModel.fromMap(map)).toList();
    }
  }

  Future<void> addNote(NoteModel note) async {
    state = [note, ...state];
    await _saveNotes();
  }

  Future<void> updateNote(NoteModel updatedNote) async {
    state = state.map((note) => note.id == updatedNote.id ? updatedNote : note).toList();
    await _saveNotes();
  }

  Future<void> deleteNote(String id) async {
    state = state.where((n) => n.id != id).toList();
    await _saveNotes();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((n) => n.toMap()).toList());
    await prefs.setString(_key, encoded);
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<NoteModel>>(() {
  return NotesNotifier();
});
