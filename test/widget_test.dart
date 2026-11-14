import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attentio_clock/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AttentioClock opens successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AttentioClockApp());

    // Allow asynchronous alarm loading and UI updates to finish.
    await tester.pumpAndSettle();

    expect(find.text('ATTENTIOCLOCK'), findsOneWidget);
    expect(find.text('Your alarms'), findsOneWidget);
    expect(find.text('No alarms yet'), findsOneWidget);
  });
}
