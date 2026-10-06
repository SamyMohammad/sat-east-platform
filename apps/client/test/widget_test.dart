import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/app.dart';

void main() {
  testWidgets('F-1: app shell renders the home route', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.textContaining('SAT East'), findsOneWidget);
  });
}
