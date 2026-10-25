import 'package:daily_rhythm/shared/utils/date_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayOf', () {
    test('drops the time of day', () {
      expect(dayOf(DateTime(2026, 10, 25, 23, 59, 59)), DateTime(2026, 10, 25));
    });
  });

  group('sleepDurationHours', () {
    test('bedtime before midnight', () {
      expect(sleepDurationHours(DateTime(2026, 10, 24, 23, 30), DateTime(2026, 10, 25, 7)), 7.5);
    });

    test('bedtime after midnight (the 00:45 median case)', () {
      expect(sleepDurationHours(DateTime(2026, 10, 24, 0, 45), DateTime(2026, 10, 25, 7)), 6.25);
    });

    test('ignores which calendar day each time was recorded on', () {
      // Times entered days apart used to give negative or 30h+ totals.
      final bed = DateTime(2026, 10, 27, 23);
      final wake = DateTime(2026, 10, 20, 7);
      expect(sleepDurationHours(bed, wake), 8);
    });

    test('identical times give zero, never 24h', () {
      expect(sleepDurationHours(DateTime(2026, 1, 1, 7), DateTime(2026, 1, 2, 7)), 0);
    });
  });
}
