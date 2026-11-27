import 'package:flutter_gemma_poc/reminders/natural_date_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = NaturalDateParser();
  // Friday 2026-11-20 17:46.
  final now = DateTime(2026, 11, 20, 17, 46);

  DateTime? when(String input) => parser.parse(input, now: now)?.when;

  test('relative offsets', () {
    expect(when('in 20 minutes'), now.add(const Duration(minutes: 20)));
    expect(when('in an hour'), now.add(const Duration(hours: 1)));
    expect(when('in half an hour'), now.add(const Duration(minutes: 30)));
    expect(when('in 2 days'), now.add(const Duration(days: 2)));
  });

  test('days with and without times', () {
    expect(when('tomorrow at 5pm'), DateTime(2026, 11, 21, 17));
    expect(when('tomorrow'), DateTime(2026, 11, 21, 9));
    expect(when('day after tomorrow at 10am'), DateTime(2026, 11, 22, 10));
    expect(when('monday'), DateTime(2026, 11, 23, 9));
    expect(when('next friday morning'), DateTime(2026, 11, 27, 9));
    expect(when('today at noon'), DateTime(2026, 11, 20, 12));
  });

  test('time only rolls to tomorrow when already past', () {
    expect(when('5:30 pm'), DateTime(2026, 11, 21, 17, 30));
    expect(when('at 9'), DateTime(2026, 11, 21, 9));
    expect(when('at 7 in the evening'), DateTime(2026, 11, 20, 19));
    expect(when('tonight'), DateTime(2026, 11, 20, 20));
  });

  test('ISO strings', () {
    expect(when('2026-12-01'), DateTime(2026, 12, 1, 9));
    expect(when('2026-12-01T14:30'), DateTime(2026, 12, 1, 14, 30));
  });

  test('returns null without a date and strips date words from remainder', () {
    expect(when('buy milk'), isNull);
    expect(when('take 2 pills'), isNull);
    expect(
      parser.parse('call mom tomorrow at 5pm', now: now)?.remainder,
      'call mom',
    );
  });
}
