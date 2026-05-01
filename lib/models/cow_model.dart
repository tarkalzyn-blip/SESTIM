import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';

class Cow {
  final String id;
  final DateTime inseminationDate;
  final int colorValue;
  final bool isInseminated;
  final DateTime? birthDate;
  final String? bullId;
  final List<dynamic> history;
  final String? motherId;
  final int? motherColorValue;
  final String? userId; // For cloud sync
  final DateTime? dateOfBirth;
  final bool isStandaloneCalf; // New: True if it's currently managed in calves screen
  final String? gender; // New: 'male' or 'female'
  final String? imagePath; // مسار صورة البقرة
  final bool? isManualCow; // جديد: لتحديد يدوياً هل هي بقرة (true) أم بكيرة (false)

  Cow({
    required this.id,
    required this.inseminationDate,
    required this.colorValue,
    this.isInseminated = true,
    this.birthDate,
    this.bullId,
    this.history = const [],
    this.motherId,
    this.motherColorValue,
    this.userId,
    this.dateOfBirth,
    this.isStandaloneCalf = false,
    this.gender,
    this.imagePath,
    this.isManualCow,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inseminationDate': inseminationDate.toIso8601String(),
      'colorValue': colorValue,
      'isInseminated': isInseminated,
      'birthDate': birthDate?.toIso8601String(),
      'bullId': bullId,
      'history': history,
      'motherId': motherId,
      'motherColorValue': motherColorValue,
      'userId': userId,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'isStandaloneCalf': isStandaloneCalf,
      'gender': gender,
      'imagePath': imagePath,
      'isManualCow': isManualCow,
    };
  }

  factory Cow.fromMap(Map<String, dynamic> map) {
    return Cow(
      id: map['id'] ?? '',
      inseminationDate: DateTime.parse(map['inseminationDate']),
      colorValue: map['colorValue'] ?? 0,
      isInseminated: map['isInseminated'] ?? true,
      birthDate: map['birthDate'] != null
          ? DateTime.parse(map['birthDate'])
          : null,
      bullId: map['bullId'],
      history: List<dynamic>.from(map['history'] ?? []),
      motherId: map['motherId'],
      motherColorValue: map['motherColorValue'],
      userId: map['userId'],
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.parse(map['dateOfBirth'])
          : null,
      isStandaloneCalf: map['isStandaloneCalf'] ?? false,
      gender: map['gender'],
      imagePath: map['imagePath'],
      isManualCow: map['isManualCow'],
    );
  }

  Cow copyWith({
    String? id,
    DateTime? inseminationDate,
    int? colorValue,
    bool? isInseminated,
    DateTime? birthDate,
    String? bullId,
    List<dynamic>? history,
    String? motherId,
    int? motherColorValue,
    String? userId,
    DateTime? dateOfBirth,
    bool? isStandaloneCalf,
    String? gender,
    String? imagePath,
    bool? isManualCow,
  }) {
    return Cow(
      id: id ?? this.id,
      inseminationDate: inseminationDate ?? this.inseminationDate,
      colorValue: colorValue ?? this.colorValue,
      isInseminated: isInseminated ?? this.isInseminated,
      birthDate: birthDate ?? this.birthDate,
      bullId: bullId ?? this.bullId,
      history: history ?? this.history,
      motherId: motherId ?? this.motherId,
      motherColorValue: motherColorValue ?? this.motherColorValue,
      userId: userId ?? this.userId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isStandaloneCalf: isStandaloneCalf ?? this.isStandaloneCalf,
      gender: gender ?? this.gender,
      imagePath: imagePath ?? this.imagePath,
      isManualCow: isManualCow ?? this.isManualCow,
    );
  }

  Color get color => Color(colorValue);

  int get daysSinceInsemination {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final insem = DateTime(
      inseminationDate.year,
      inseminationDate.month,
      inseminationDate.day,
    );
    return today.difference(insem).inDays;
  }

  DateTime? get effectiveBirthDate {
    if (birthDate != null && birthDate!.isAfter(inseminationDate)) return birthDate;
    
    // البحث في السجل للتوافق مع التسجيلات القديمة
    final births = history.where((e) {
      final title = e['title']?.toString() ?? '';
      final type = e['type']?.toString() ?? '';
      return title.contains('ولادة') || title.contains('مولود') || type == 'birth';
    }).toList();
    
    if (births.isNotEmpty) {
      births.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      try {
        final date = DateTime.parse(births.first['date']);
        if (date.isAfter(inseminationDate)) return date;
      } catch (_) {}
    }
    return null;
  }

  bool get isPostBirth => effectiveBirthDate != null;

  int get daysSinceBirth {
    final bDate = effectiveBirthDate;
    if (bDate == null) return 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(bDate.year, bDate.month, bDate.day);
    return today.difference(birth).inDays;
  }

  int get pregnancyDuration {
    final bDate = effectiveBirthDate;
    if (bDate != null) {
      return bDate.difference(inseminationDate).inDays;
    }
    return daysSinceInsemination;
  }

  double get pregnancyPercentage {
    if (isPostBirth) {
      if (daysSinceBirth > AppSettings.recoveryDays) return 1.0;
      return daysSinceBirth / AppSettings.recoveryDays;
    }

    int days = daysSinceInsemination;
    if (days < 0) return 0;
    if (!isInseminated) {
      if (days > AppSettings.heatCycleDays) return 1.0;
      return days / AppSettings.heatCycleDays;
    }
    if (days > AppSettings.pregnancyDays) return 1.0;
    return days / AppSettings.pregnancyDays;
  }

  bool get hasGivenBirth => history.any((e) {
    final title = e['title']?.toString() ?? '';
    return title.contains('ولادة') || title.contains('مولود');
  });

  bool get isHeifer {
    // الأولوية للتحديد اليدوي إذا وجد
    if (isManualCow == true) return false; // إذا حُددت كبقرة يدوياً → ليست بكيرة
    if (isManualCow == false) return true; // إذا حُددت كبكيرة يدوياً → هي بكيرة

    // التوافق مع السجلات القديمة
    if (gender == 'male') return false;
    if (hasGivenBirth) return false;
    if (isStandaloneCalf) return false;

    return true;
  }

  String get status {
    // العجول المستقلة (في صفحة العجول) - هذا لن يُستدعى عادةً من صفحة الأبقار
    if (isStandaloneCalf) {
      if (dateOfBirth != null) {
        final ageInDays = DateTime.now().difference(dateOfBirth!).inDays;
        if (ageInDays < 365) return gender == 'male' ? 'عجل' : 'عجولة';
      }
      return gender == 'male' ? 'عجل' : 'عجولة';
    }

    // البكيرة (في صفحة الأبقار لكن لم تلد)
    if (isHeifer) {
      if (isPostBirth) return 'بكيرة - حديثة الولادة';
      if (isInseminated) {
        if (daysSinceInsemination <= 25) return 'بكيرة - تحت المراقبة';
        if (daysSinceInsemination < AppSettings.pregnancyDays - 20)
          return 'بكيرة - حامل';
        if (daysSinceInsemination <= AppSettings.pregnancyDays)
          return 'بكيرة - قريبة من الولادة';
        return 'بكيرة - تجاوزت موعد الولادة';
      }
      return 'بكيرة - انتظار التلقيح';
    }

    // البقرة الوالدة
    if (isPostBirth) {
      if (daysSinceBirth < AppSettings.recoveryDays)
        return 'حديثة الولادة (التعافي)';
      return '⚠ تأخرت عن التلقيح';
    }

    int days = daysSinceInsemination;
    if (!isInseminated) {
      if (days < AppSettings.heatCycleDays - 3) return 'انتظار الشبق';
      if (days >= AppSettings.heatCycleDays - 3 &&
          days <= AppSettings.heatCycleDays + 1)
        return '⚠ موعد شبق متوقع';
      return 'تجاوزت موعد الشبق';
    }
    if (days <= 25) return 'تحت المراقبة';
    if (days > 25 && days < AppSettings.pregnancyDays - 20) return 'حامل';
    if (days >= AppSettings.pregnancyDays - 20 &&
        days <= AppSettings.pregnancyDays)
      return 'قريبة من الولادة';
    return 'تجاوزت موعد الولادة';
  }

  int? get daysSinceLastBirth {
    final birthEvents = history.where((e) => 
      e['type'] == 'birth' || e['title'] == 'تسجيل ولادة'
    ).toList();
    if (birthEvents.isEmpty) return null;
    birthEvents.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    final lastBirthDate = DateTime.parse(birthEvents.first['date']);
    return DateTime.now().difference(lastBirthDate).inDays;
  }

  String get age {
    if (dateOfBirth == null) return "غير محدد";
    final now = DateTime.now();
    final difference = now.difference(dateOfBirth!);
    final days = difference.inDays;

    if (days < 30) return '$days يوم';
    if (days < 365) {
      final months = days ~/ 30;
      final remainingDays = days % 30;
      String result = '$months شهر';
      if (remainingDays > 0) result += ' و $remainingDays يوم';
      return result;
    }
    final years = days ~/ 365;
    final remainingMonths = (days % 365) ~/ 30;
    String result = '$years سنة';
    if (remainingMonths > 0) result += ' و $remainingMonths شهر';
    return result;
  }

  String get uniqueKey => "${id}_$colorValue";
}

class CowAdapter extends TypeAdapter<Cow> {
  @override
  final int typeId = 0;

  @override
  Cow read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Cow(
      id: fields[0] as String,
      inseminationDate: fields[1] as DateTime,
      colorValue: fields[2] as int,
      isInseminated: fields[3] as bool? ?? true,
      birthDate: fields[4] as DateTime?,
      bullId: fields[5] as String?,
      history: fields[6] as List<dynamic>? ?? [],
      motherId: fields[7] as String?,
      motherColorValue: fields[8] as int?,
      userId: fields[9] as String?,
      dateOfBirth: fields[10] as DateTime?,
      isStandaloneCalf: fields[11] as bool? ?? false,
      gender: fields[12] as String?,
      imagePath: fields[13] as String?,
      isManualCow: fields[14] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Cow obj) {
    writer
      ..writeByte(15) // Updated count from 14 to 15
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.inseminationDate)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.isInseminated)
      ..writeByte(4)
      ..write(obj.birthDate)
      ..writeByte(5)
      ..write(obj.bullId)
      ..writeByte(6)
      ..write(obj.history)
      ..writeByte(7)
      ..write(obj.motherId)
      ..writeByte(8)
      ..write(obj.motherColorValue)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.dateOfBirth)
      ..writeByte(11)
      ..write(obj.isStandaloneCalf)
      ..writeByte(12)
      ..write(obj.gender)
      ..writeByte(13)
      ..write(obj.imagePath)
      ..writeByte(14)
      ..write(obj.isManualCow);
  }
}
