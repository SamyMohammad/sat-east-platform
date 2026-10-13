import 'package:flutter_test/flutter_test.dart';
import 'package:sat_east_client/core/math_render/math_markup.dart';

void main() {
  test('F-4: plain text is one run', () {
    expect(parseMathMarkup('Hello'), [const TextRun('Hello')]);
  });
  test('F-4: inline math splits the text', () {
    expect(parseMathMarkup(r'If \(x+1\) is 3'), [
      const TextRun('If '),
      const InlineMath('x+1'),
      const TextRun(' is 3'),
    ]);
  });
  test('F-4: block math becomes a block', () {
    expect(parseMathMarkup(r'Solve \[\frac{1}{x}=2\] now'), [
      const TextRun('Solve '),
      const BlockMath([r'\frac{1}{x}=2']),
      const TextRun(' now'),
    ]);
  });
  test('F-4: || splits a block into wrap chunks', () {
    expect(parseMathMarkup(r'\[a=b || c=d ||e\]'), [
      const BlockMath(['a=b', 'c=d', 'e']),
    ]);
  });
  test('F-4: **bold** toggles bold runs, also around math', () {
    expect(parseMathMarkup(r'**Rule \(x\) here** done'), [
      const TextRun('Rule ', bold: true),
      const InlineMath('x'),
      const TextRun(' here', bold: true),
      const TextRun(' done'),
    ]);
  });
  test('F-4: unclosed delimiters stay literal', () {
    expect(parseMathMarkup(r'cost \(x'), [const TextRun(r'cost \(x')]);
    expect(parseMathMarkup(r'a \[b'), [const TextRun(r'a \[b')]);
    expect(parseMathMarkup('2 ** 3'), [const TextRun('2 ** 3')]);
  });
  test('F-4: empty math is dropped', () {
    expect(parseMathMarkup(r'a\(\)b'), [
      const TextRun('a'),
      const TextRun('b'),
    ]);
  });
}
