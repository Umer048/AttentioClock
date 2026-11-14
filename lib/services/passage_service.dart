
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/passage.dart';

class PassageService {
  PassageService({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const Map<String, String> _assetPaths = {
    'Islamic': 'assets/data/islamic/passages.json',
    'Motivation': 'assets/data/motivation/passages.json',
    'Sports': 'assets/data/sports/passages.json',
  };

  String _storageKey(String domain) {
    return 'attentio_remaining_passages_${domain.toLowerCase()}';
  }

  Future<List<Passage>> loadPassages(String domain) async {
    final assetPath = _assetPaths[domain];

    if (assetPath == null) {
      throw ArgumentError('Unknown learning domain: $domain');
    }

    final jsonString = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

    final passagesJson = decoded['passages'] as List<dynamic>;

    return passagesJson
        .map(
          (item) => Passage.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<Passage> getNextPassage(String domain) async {
    final passages = await loadPassages(domain);

    if (passages.isEmpty) {
      throw StateError('No passages found for $domain.');
    }

    final preferences = await SharedPreferences.getInstance();
    final key = _storageKey(domain);

    final savedIds = preferences.getStringList(key) ?? [];
    final validIds = passages.map((passage) => passage.id).toSet();

    // Keep only IDs that still exist in the current JSON collection.
    final remainingIds = savedIds
        .where((id) => validIds.contains(id))
        .toList();

    // Start a fresh shuffled cycle when all passages have been used.
    if (remainingIds.isEmpty) {
      remainingIds.addAll(validIds);
      remainingIds.shuffle(_random);
    }

    final nextId = remainingIds.removeAt(0);

    await preferences.setStringList(key, remainingIds);

    return passages.firstWhere(
      (passage) => passage.id == nextId,
    );
  }

  Future<void> resetDomain(String domain) async {
    if (!_assetPaths.containsKey(domain)) {
      throw ArgumentError('Unknown learning domain: $domain');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey(domain));
  }
}
