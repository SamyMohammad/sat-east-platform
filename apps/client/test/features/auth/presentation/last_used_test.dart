import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/auth/presentation/last_used.dart';

void main() {
  final now = DateTime(2026, 10, 16, 15);

  test('P1-2: a time just after local midnight is today', () {
    expect(
      lastUsedText(DateTime(2026, 10, 16, 0, 1), now),
      'Last used today 00:01',
    );
  });

  test('P1-2: 23:59 the day before is yesterday', () {
    expect(
      lastUsedText(DateTime(2026, 10, 15, 23, 59), now),
      'Last used yesterday 23:59',
    );
  });

  test('P1-2: two days ago shows the day and month', () {
    expect(lastUsedText(DateTime(2026, 10, 14, 12), now), 'Last used 14 Oct');
  });

  test('P1-2: an older date in another month shows day and month', () {
    expect(lastUsedText(DateTime(2026, 3, 3, 8), now), 'Last used 3 Mar');
  });

  test('P1-2: just after midnight now, 23:59 yesterday is yesterday', () {
    final justAfterMidnight = DateTime(2026, 10, 16, 0, 5);
    expect(
      lastUsedText(DateTime(2026, 10, 15, 23, 59), justAfterMidnight),
      'Last used yesterday 23:59',
    );
  });
}
