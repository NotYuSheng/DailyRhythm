import 'package:flutter_test/flutter_test.dart';
import 'package:life_rhythm/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DailyRhythmApp());

    // Verify that the app title is displayed
    expect(find.text('DailyRhythm'), findsOneWidget);

    // Verify that the Journal tab is visible
    expect(find.text('Journal'), findsOneWidget);
  });
}
