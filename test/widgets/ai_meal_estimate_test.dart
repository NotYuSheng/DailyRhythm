import 'dart:convert';

import 'package:daily_rhythm/features/ai/data/ai_client.dart';
import 'package:daily_rhythm/features/ai/data/ai_providers.dart';
import 'package:daily_rhythm/features/ai/domain/ai_settings.dart';
import 'package:daily_rhythm/features/meals/presentation/screens/add_meal_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart';

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await openTestDatabase();
  });
  tearDown(closeTestDatabase);

  testWidgets('no AI set up: no AI button', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [aiClientProvider.overrideWithValue(null)],
      child: MaterialApp(home: AddMealScreen(date: DateTime(2026, 10, 20))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Estimate with AI'), findsNothing);
  });

  testWidgets('with AI set up, Estimate with AI fills one serving\'s calories from just the name', (tester) async {
    String? sentName;
    final ai = AiClient(
      const AiSettings(enabled: true, provider: AiProvider.ollama, baseUrl: 'http://pc.ts.net:11434/v1', model: 'llama3.2'),
      MockClient((r) async {
        sentName = ((jsonDecode(r.body) as Map)['messages'] as List).last['content'] as String;
        return http.Response(jsonEncode({'choices': [{'message': {'content': '{"kcal": 610, "serving": "one plate"}'}}]}), 200);
      }),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [aiClientProvider.overrideWithValue(ai)],
      child: MaterialApp(home: AddMealScreen(date: DateTime(2026, 10, 20))),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Meal Name'), 'Char kway teow');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Estimate with AI'));
    await tester.tap(find.text('Estimate with AI'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(sentName, 'Char kway teow');
    expect(tester.widget<TextField>(_field('Calories (optional)')).controller!.text, '610');
    expect(find.textContaining('AI estimate, for one plate'), findsOneWidget);
  });
}
