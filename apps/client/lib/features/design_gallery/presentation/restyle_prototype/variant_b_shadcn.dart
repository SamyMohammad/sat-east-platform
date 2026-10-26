import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';

class VariantBShadcn extends StatefulWidget {
  const VariantBShadcn({required this.question, super.key});
  final QuestionData question;

  @override
  State<VariantBShadcn> createState() => _VariantBShadcnState();
}

class _VariantBShadcnState extends State<VariantBShadcn> {
  String _selected = 'A';
  String get _result => _selected == 'B' ? 'Correct' : 'Incorrect';
  bool _checked = false;
  bool _hint = false;
  static const _ink = Color(0xFF18181B);
  static const _line = Color(0xFFE4E4E7);
  static final _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(7),
  );
  static final _theme = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: _ink,
      secondary: Color(0xFF71717A),
      onSurface: _ink,
      outline: _line,
    ),
    fontFamily: 'NotoSans',
    visualDensity: VisualDensity.compact,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
      bodyMedium: TextStyle(fontSize: 13, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: _shape.copyWith(side: const BorderSide(color: _line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: _shape,
        minimumSize: const Size(140, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: _shape,
        side: const BorderSide(color: _line),
      ),
    ),
  );

  void _select(String label) => setState(() {
    _selected = label;
    _checked = false;
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme,
    child: CallbackShortcuts(
      bindings: {
        for (var i = 0; i < 4; i++)
          SingleActivator(
            [
              LogicalKeyboardKey.keyA,
              LogicalKeyboardKey.keyB,
              LogicalKeyboardKey.keyC,
              LogicalKeyboardKey.keyD,
            ][i],
          ): () =>
              _select(String.fromCharCode(65 + i)),
      },
      child: Focus(autofocus: true, child: Builder(builder: _screen)),
    ),
  );

  Widget _screen(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1024;
          return SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 48 : 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'WORKSPACE / PRACTICE',
                      style: _theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Linear equations',
                      style: _theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Build fluency, one problem at a time.',
                      style: _theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: _line, height: 1),
                    const SizedBox(height: 28),
                    if (!wide) ...[
                      _metadata(compact: true),
                      const SizedBox(height: 24),
                    ],
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _question()),
                          const SizedBox(width: 48),
                          SizedBox(
                            width: 280,
                            child: _metadata(compact: false),
                          ),
                        ],
                      )
                    else
                      _question(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _metadata({required bool compact}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          const Text(
            'SESSION DETAILS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Skill: Linear equations'),
            Text('Difficulty: Easy'),
            Text('3/10'),
          ],
        ),
        const SizedBox(height: 16),
        const LinearProgressIndicator(
          value: .3,
          minHeight: 3,
          backgroundColor: _line,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() => _hint = !_hint),
          icon: const Icon(Icons.lightbulb_outline, size: 16),
          label: Text(_hint ? 'Hide hint' : 'Show hint'),
        ),
        if (_hint)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Add 7 to both sides. What remains on the left?'),
          ),
        if (!compact) ...[
          const SizedBox(height: 24),
          const Divider(color: _line),
          const SizedBox(height: 12),
          Text('KEYBOARD SHORTCUTS', style: _theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          const Text('A–D   Select an answer\n← →   Compare designs'),
        ],
      ],
    ),
  );

  Widget _question() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Question 3 of 10',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(widget.question.label, style: _theme.textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 28),
      MathText(widget.question.stemMd, style: _theme.textTheme.titleLarge),
      const SizedBox(height: 28),
      for (final choice in (widget.question.kind as McqKind).choices)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: _selected == choice.label
                ? const Color(0xFFF4F4F5)
                : Colors.white,
            shape: _shape.copyWith(
              side: BorderSide(color: _selected == choice.label ? _ink : _line),
            ),
            child: InkWell(
              customBorder: _shape,
              onTap: () => _select(choice.label),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _line),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        choice.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: MathText(choice.md)),
                    if (_selected == choice.label)
                      const Icon(Icons.check, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () => setState(() => _checked = true),
          child: const Text('Check answer'),
        ),
      ),
      if (_checked)
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: _ink),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$_result.\n'
            'Add 7: 3x = 36. Divide by 3: x = 12. The answer is B.',
          ),
        ),
    ],
  );
}
