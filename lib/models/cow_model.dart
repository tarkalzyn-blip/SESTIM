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
    };
  }

  factory Cow.fromMap(Map<String, dynamic> map) {
    return Cow(
      id: map['id'] ?? '',
      inseminationDate: DateTime.parse(map['inseminationDate']),
      colorValue: map['colorValue'] ?? 0,
      isInseminated: map['isInseminated'] ?? true,
      birthDate: map['birthDate'] != null ? DateTime.parse(map['birthDate']) : null,
      bullId: map['bullId'],
      history: List<dynamic>.from(map['history'] ?? []),
      motherId: map['motherId'],
      motherColorValue: map['motherColorValue'],
      userId: map['userId'],
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
    );
  }

  Color get color => Color(colorValue);

  int get daysSinceInsemination {
    return DateTime.now().difference(inseminationDate).inDays;
  }

  bool get isPostBirth => birthDate != null && birthDate!.isAfter(inseminationDate);
  int get daysSinceBirth => isPostBirth ? DateTime.now().difference(birthDate!).inDays : 0;

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

  String get status {
    if (isPostBirth) {
      if (daysSinceBirth < AppSettings.recoveryDays) return "حديثة الولادة (التعافي)";
      return "⚠ تأخرت عن التلقيح";
    }

    int days = daysSinceInsemination;
    if (!isInseminated) {
      if (days < AppSettings.heatCycleDays - 3) return "انتظار الشبق القادم";
      if (days >= AppSettings.heatCycleDays - 3 && days <= AppSettings.heatCycleDays + 1) return "⚠ موعد شبق متوقع";
      return "تجاوزت موعد الشبق";
    }

    if (days <= 25) return "تحت المراقبة";
    if (days > 25 && days < AppSettings.pregnancyDays - 20) return "حامل";
    if (days >= AppSettings.pregnancyDays - 20 && days <= AppSettings.pregnancyDays) return "قريبة من الولادة";
    return "تجاوزت موعد الولادة";
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
    );
  }

  @override
  void write(BinaryWriter writer, Cow obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.userId);
  }
}
