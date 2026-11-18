import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmStorageService {
  static const _key = 'attentio_alarms_v2';

  Future<void> saveAlarms(List<Map<String, dynamic>> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(alarms));
  }

  Future<List<Map<String, dynamic>>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
}