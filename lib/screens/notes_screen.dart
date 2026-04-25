import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/providers/cow_provider.dart';
import 'package:cow_pregnancy/providers/notes_provider.dart';
import 'package:cow_pregnancy/models/cow_model.dart';
import 'package:cow_pregnancy/services/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملاحظات', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          onPressed: () => _showAddNoteSheet(context),
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: notes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notes, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد ملاحظات حالياً',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 16, left: 16, right: 16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return _NoteCard(
                  note: note,
                  onEdit: () => _showAddNoteSheet(context, note),
                );
              },
            ),
    );
  }

  void _showAddNoteSheet(BuildContext context, [NoteModel? noteToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AddNoteForm(noteToEdit: noteToEdit),
        );
      },
    );
  }
}

class _NoteCard extends ConsumerWidget {
  final NoteModel note;
  final VoidCallback onEdit;
  const _NoteCard({required this.note, required this.onEdit});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذه الملاحظة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              ref.read(notesProvider.notifier).deleteNote(note.id);
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onEdit,
        onLongPress: () => _confirmDelete(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(note.cowColorValue),
                    radius: 8,
                  ),
                  const SizedBox(width: 8),
                  Text('بقرة #${note.cowId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  const Icon(Icons.edit_note, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note.noteText, 
                style: const TextStyle(
                  fontSize: 17, 
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('yyyy-MM-dd').format(note.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  if (note.reminderDate != null)
                    Row(
                      children: [
                        const Icon(Icons.alarm, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(note.reminderDate!),
                          style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'مضى ${DateTime.now().difference(note.startDate).inDays} يوم',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddNoteForm extends ConsumerStatefulWidget {
  final NoteModel? noteToEdit;
  const _AddNoteForm({this.noteToEdit});

  @override
  ConsumerState<_AddNoteForm> createState() => _AddNoteFormState();
}

class _AddNoteFormState extends ConsumerState<_AddNoteForm> {
  final _noteController = TextEditingController();
  final _daysController = TextEditingController();
  Cow? _selectedCow;
  bool _hasReminder = false;
  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _startDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.noteToEdit != null) {
      _noteController.text = widget.noteToEdit!.noteText;
      _startDate = widget.noteToEdit!.startDate;
      if (widget.noteToEdit!.reminderDate != null) {
        _hasReminder = true;
        _selectedTime = TimeOfDay.fromDateTime(widget.noteToEdit!.reminderDate!);
        final diff = widget.noteToEdit!.reminderDate!.difference(DateTime.now()).inDays;
        _daysController.text = diff > 0 ? diff.toString() : '1';
      }
      // Delay fetching the cow until the build phase completes so ref is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cows = ref.read(cowProvider);
        try {
          setState(() {
            _selectedCow = cows.firstWhere((c) => c.id == widget.noteToEdit!.cowId);
          });
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  void _saveNote() {
    if (_selectedCow == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار البقرة')));
      return;
    }
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء كتابة الملاحظة')));
      return;
    }

    DateTime? reminderDate;
    if (_hasReminder && _daysController.text.isNotEmpty) {
      int days = int.tryParse(_daysController.text) ?? 0;
      if (days > 0) {
        final now = DateTime.now();
        reminderDate = DateTime(
          now.year,
          now.month,
          now.day + days,
          _selectedTime.hour,
          _selectedTime.minute,
        );
        
        final noteId = const Uuid().v4();
        NotificationService().scheduleCustomNotification(
          id: noteId.hashCode,
          title: 'تذكير: بقرة #${_selectedCow!.id}',
          body: _noteController.text,
          scheduledDate: reminderDate,
        );
      }
    } else if (widget.noteToEdit != null && widget.noteToEdit!.reminderDate != null) {
      // Cancel the old notification if the reminder was removed during edit
      NotificationService().cancelCustomNotification(widget.noteToEdit!.id.hashCode);
    }

    final newNote = NoteModel(
      id: widget.noteToEdit?.id ?? const Uuid().v4(),
      cowId: _selectedCow!.id,
      cowColorValue: _selectedCow!.colorValue,
      noteText: _noteController.text.trim(),
      createdAt: widget.noteToEdit?.createdAt ?? DateTime.now(),
      startDate: _startDate,
      reminderDate: reminderDate,
    );

    if (widget.noteToEdit != null) {
      ref.read(notesProvider.notifier).updateNote(newNote);
    } else {
      ref.read(notesProvider.notifier).addNote(newNote);
    }
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cows = ref.watch(cowProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('إضافة ملاحظة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Autocomplete for cow
          Autocomplete<Cow>(
            displayStringForOption: (Cow option) => option.id,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<Cow>.empty();
              }
              return cows.where((cow) => cow.id.contains(textEditingValue.text));
            },
            onSelected: (Cow selection) {
              setState(() {
                _selectedCow = selection;
              });
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'اختر البقرة (اكتب رقمها)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: _selectedCow != null
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircleAvatar(backgroundColor: _selectedCow!.color, radius: 10),
                        )
                      : const Icon(Icons.search),
                ),
                onChanged: (val) {
                  if (_selectedCow != null && _selectedCow!.id != val) {
                    setState(() {
                      _selectedCow = null;
                    });
                  }
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 40),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Cow option = options.elementAt(index);
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: option.color, radius: 12),
                          title: Text('بقرة #${option.id}'),
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Start Date Picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary),
            title: const Text('تاريخ بدء العداد', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: _pickStartDate,
          ),
          const SizedBox(height: 16),

          // Note Text
          TextField(
            controller: _noteController,
            maxLines: 3,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.start,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: 'تفاصيل الملاحظة',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          
          // Reminder Toggle
          SwitchListTile(
            title: const Text('تعيين منبه تذكيري', style: TextStyle(fontWeight: FontWeight.bold)),
            value: _hasReminder,
            activeThumbColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              setState(() {
                _hasReminder = val;
              });
            },
          ),
          
          if (_hasReminder) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'بعد كم يوم؟',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixText: 'أيام',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'الساعة',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_selectedTime.format(context)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveNote,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حفظ الملاحظة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
