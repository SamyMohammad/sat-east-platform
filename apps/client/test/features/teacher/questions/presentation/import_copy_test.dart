import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/import_copy.dart';

void main() {
  const mathDelimiters = r'\( \) or \[ \]';
  for (final field in ['stem_md', 'hint_md', 'explanation_md', 'choices']) {
    test('QB-05: dollar LaTeX copy for $field', () {
      expect(
        importProblemCopy('latex_dollar:$field'),
        'Math must use $mathDelimiters, not \$\u2026\$.',
      );
    });
  }
}
