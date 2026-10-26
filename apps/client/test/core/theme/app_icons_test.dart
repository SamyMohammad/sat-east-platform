import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no_material_icons_left', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) =>
              RegExp(r'(?<![A-Za-z])Icons\.').hasMatch(file.readAsStringSync()),
        )
        .map((file) => file.path);
    expect(offenders, isEmpty);
  });
}
