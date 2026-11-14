
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AlarmStorageService {
  static const String _storageKey = 'attentio_saved_alarms';

  Future<List<Map<String, dynamic>>> loadAlarms() async {
    final preferences = await SharedPreferences.getInstance();

    final savedData = preferences.getString(_storageKey);

    if (savedData == null || savedData.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(savedData);

      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      return [];
    }
  }

  Future<void> saveAlarms(
    List<Map<String, dynamic>> alarms,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _storageKey,
      jsonEncode(alarms),
    );
  }
}
