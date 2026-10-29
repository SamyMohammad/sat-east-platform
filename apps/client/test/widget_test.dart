import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:sat_east_client/app.dart';

void main() {
  testWidgets('F-1: app uses the branded title', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Abdelrahman Elmenshawy | SAT & EST Math',
    );
  });
}
