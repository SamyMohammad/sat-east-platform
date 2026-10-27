import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/errors/result.dart';
import 'package:sat_east_client/features/teacher/questions/data/services/file_picker_stub.dart';
import 'package:sat_east_client/features/teacher/questions/domain/entities/picked_file.dart';
import 'package:sat_east_client/features/teacher/questions/domain/services/file_picker_service.dart';

import '../notes_fixtures.dart';

void main() {
  test('C-3: PDF picker returns original name, bytes and actual byte size', () {
    final file = pdf(name: 'Lesson.PDF', size: 123);
    expect(file.name, 'Lesson.PDF');
    expect(file.size, 123);
    expect(file.bytes, hasLength(123));
  });
  test(
    'C-3: native stub reports unsupported for PDFs and preserves JSON behavior',
    () async {
      final picker = StubFilePickerService();
      expect(
        (await picker.pickPdf() as Failure<PickedPdf>).error.code,
        'unsupported',
      );
      expect(
        (await picker.pickJson() as Failure<PickedFile>).error.code,
        'unsupported',
      );
    },
  );
}
