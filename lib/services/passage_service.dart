import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/passage.dart';

class PassageService {
  Future<Passage> getNextPassage(String domain) async {
    // List of domains to try. If "More" is selected, it shuffles all domains.
    List<String> domainsToTry = [];

    if (domain.toLowerCase() == 'more') {
      domainsToTry = ['islamic', 'motivation', 'sports'];
      domainsToTry.shuffle();
    } else {
      domainsToTry = [domain.toLowerCase()];
    }

    for (String d in domainsToTry) {
      try {
        final path = 'assets/data/$d/passages.json';
        final jsonString = await rootBundle.loadString(path);
        final jsonList = jsonDecode(jsonString) as List;

        if (jsonList.isEmpty) continue; // Agar file khali hai toh agla try karein

        final passages = jsonList.map((j) => Passage.fromJson(j)).toList();

        final prefs = await SharedPreferences.getInstance();
        final key = 'passage_index_$d';
        int index = prefs.getInt(key) ?? 0;

        if (index >= passages.length) index = 0;

        await prefs.setInt(key, index + 1);
        return passages[index];

      } catch (e) {
        debugPrint("Could not load domain $d: $e");
        // Agar is domain mein error aaya, toh loop agla domain try karega
      }
    }

    // AGAR SAARI FILES FAIL HO JAYEIN (Emergency Fallback)
    // Toh app crash na ho, isliye yeh default passage return karega
    return Passage(
      id: 'fallback_1',
      title: 'Welcome to AttentioClock',
      body: 'Your passage could not be loaded. Please make sure the JSON files are correctly placed in assets/data/.',
      questions: [
        PassageQuestion(
          question: 'Are you ready to start your day?',
          options: ['Yes, I am', 'No'],
          correctIndex: 0,
          explanation: 'Have a great day ahead!',
          references: [],
        )
      ],
    );
  }
}