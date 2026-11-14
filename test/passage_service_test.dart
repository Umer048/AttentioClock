import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attentio_clock/services/passage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const domains = ['Islamic', 'Motivation', 'Sports'];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final domain in domains) {
    group('$domain passages', () {
      test('loads exactly 50 passages', () async {
        final service = PassageService();

        final passages = await service.loadPassages(domain);

        expect(passages.length, 50);
        expect(passages.map((p) => p.id).toSet().length, 50);
      });

      test('does not repeat passages before completing the cycle', () async {
        final firstService = PassageService();
        final usedIds = <String>{};

        // Simulate using the first 10 passages.
        for (var i = 0; i < 10; i++) {
          final passage = await firstService.getNextPassage(domain);
          expect(usedIds.add(passage.id), isTrue);
        }

        // Simulate recreating the service, as after an app restart.
        final restartedService = PassageService();

        for (var i = 10; i < 50; i++) {
          final passage = await restartedService.getNextPassage(domain);
          expect(
            usedIds.add(passage.id),
            isTrue,
            reason: 'Repeated passage before completing the cycle: ${passage.id}',
          );
        }

        expect(usedIds.length, 50);
      });

      test('starts another cycle after all 50 passages are used', () async {
        final service = PassageService();
        final allPassages = await service.loadPassages(domain);
        final validIds = allPassages.map((p) => p.id).toSet();

        for (var i = 0; i < 50; i++) {
          await service.getNextPassage(domain);
        }

        final nextPassage = await service.getNextPassage(domain);

        expect(validIds.contains(nextPassage.id), isTrue);
      });
    });
  }
}

