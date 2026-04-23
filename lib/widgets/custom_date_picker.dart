import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDatePickerField extends StatefulWidget {
  final String label;
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const CustomDatePickerField({
    super.key,
    required this.label,
    required this.initialDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
  });

  @override
  State<CustomDatePickerField> createState() => _CustomDatePickerFieldState();
}

class _CustomDatePickerFieldState extends State<CustomDatePickerField> {
  late TextEditingController _controller;
  final DateFormat _formatter = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatter.format(widget.initialDate));
  }

  @override
  void didUpdateWidget(CustomDatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate != widget.initialDate) {
      _controller.text = _formatter.format(widget.initialDate);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    try {
      final date = _formatter.parseStrict(value);
      widget.onDateSelected(date);
    } catch (_) {
      // Invalid date format, don't update parent yet
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'YYYY-MM-DD',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        suffixIcon: IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: widget.initialDate,
              firstDate: widget.firstDate ?? DateTime(2010),
              lastDate: widget.lastDate ?? DateTime.now(),
            );
            if (pickedDate != null) {
              setState(() {
                _controller.text = _formatter.format(pickedDate);
              });
              widget.onDateSelected(pickedDate);
            }
          },
        ),
      ),
      onChanged: _onTextChanged,
      validator: (value) {
        if (value == null || value.isEmpty) return 'التاريخ مطلوب';
        try {
          _formatter.parseStrict(value);
          return null;
        } catch (_) {
          return 'صيغة التاريخ غير صحيحة (YYYY-MM-DD)';
        }
      },
    );
  }
}
