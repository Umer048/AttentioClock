import 'package:flutter/material.dart';

class AlarmModel {
  final int id;
  TimeOfDay time;
  String label;
  List<int> repeatDays;
  bool enabled;
  String domain;
  String soundId;
  String? customSoundPath;
  String? customSoundName;

  AlarmModel({
    required this.id, required this.time, required this.label, required this.repeatDays,
    this.enabled = true, this.domain = 'Islamic', this.soundId = 'gentle_chimes',
    this.customSoundPath, this.customSoundName,
  });

  String get formattedTime {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$h:${time.minute.toString().padLeft(2, '0')} ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'hour': time.hour, 'minute': time.minute, 'label': label,
    'repeatDays': repeatDays, 'enabled': enabled, 'domain': domain,
    'soundId': soundId, 'customSoundPath': customSoundPath, 'customSoundName': customSoundName,
  };

  factory AlarmModel.fromMap(Map<String, dynamic> map) {
    return AlarmModel(
      id: map['id'], time: TimeOfDay(hour: map['hour'], minute: map['minute']),
      label: map['label'] ?? '', repeatDays: List<int>.from(map['repeatDays'] ?? []),
      enabled: map['enabled'] ?? true, domain: map['domain'] ?? 'Islamic',
      soundId: map['soundId'] ?? 'gentle_chimes', customSoundPath: map['customSoundPath'],
      customSoundName: map['customSoundName'],
    );
  }
}