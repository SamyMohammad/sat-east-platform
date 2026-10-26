import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';

class VariantCBluebook extends StatefulWidget {
  const VariantCBluebook({required this.question, super.key});
  final QuestionData question;

  @override
  State<VariantCBluebook> createState() => _VariantCBluebookState();
}

class _VariantCBluebookState extends State<VariantCBluebook> {
  String _selected = 'A';
  String get _result => _selected == 'B' ? 'Correct' : 'Incorrect';
  final _eliminated = <String>{};
  bool _checked = false;
  bool _marked = false;
  bool _timerVisible = true;
  bool _hint = false;
  bool _annotate = false;
  static const _ink = Color(0xFF20242B);
  static const _blue = Color(0xFF224FAD);
  static final _theme = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: _blue,
      onSurface: _ink,
      outline: Color(0xFF93979E),
    ),
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'NotoSans',
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 18, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        foregroundColor: _ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme,
    child: Builder(builder: _screen),
  );

  Widget _screen(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          _header(context),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                for (var i = 0; i < (constraints.maxWidth / 12).floor(); i++)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(right: 5),
                      color: _ink,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1024;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 48 : 20,
                    vertical: 32,
                  ),
                  child: wide
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _stem()),
                              const VerticalDivider(
                                width: 64,
                                color: Color(0xFFCACDD2),
                              ),
                              Expanded(child: _answers()),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _stem(),
                            const SizedBox(height: 32),
                            _answers(),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _footer(context),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const section = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Math · Module 1',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Practice session', style: TextStyle(fontSize: 11)),
          ],
        );
        final timer = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _timerVisible ? '31:42' : '−−:−−',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: _timerVisible ? 'Hide timer' : 'Show timer',
              onPressed: () => setState(() => _timerVisible = !_timerVisible),
              icon: Icon(
                _timerVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
            ),
          ],
        );
        final tools = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _marked = !_marked),
              icon: Icon(
                _marked ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
              ),
              label: const Text('Mark for review'),
            ),
            IconButton(
              tooltip: _annotate ? 'Stop annotating' : 'Annotate',
              isSelected: _annotate,
              onPressed: () => setState(() => _annotate = !_annotate),
              icon: const Icon(Icons.edit_note),
            ),
            IconButton(
              tooltip: 'Tools',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Practice tools\n\n'
                      'Use the elimination buttons to cross out choices, '
                      'or mark this question for review.',
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.construction_outlined, size: 20),
            ),
          ],
        );
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [section, timer],
              ),
              Align(alignment: Alignment.centerRight, child: tools),
            ],
          );
        }
        return Row(
          children: [
            const Expanded(child: section),
            timer,
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: tools),
            ),
          ],
        );
      },
    ),
  );

  Widget _stem() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: _ink,
            child: const Text(
              '3',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Linear equations',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (_marked) const Icon(Icons.bookmark, size: 20, color: _blue),
        ],
      ),
      const Divider(height: 32),
      const Text(
        'Skill: Linear equations · Easy',
        style: TextStyle(fontSize: 12, color: Color(0xFF60646C)),
      ),
      const SizedBox(height: 24),
      ColoredBox(
        color: _annotate ? const Color(0xFFFFF2B5) : Colors.white,
        child: MathText(
          widget.question.stemMd,
          style: _theme.textTheme.bodyLarge,
        ),
      ),
      if (_annotate)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Annotation preview · stem highlighted',
            style: TextStyle(fontSize: 12),
          ),
        ),
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _hint = !_hint),
          icon: const Icon(Icons.lightbulb_outline, size: 18),
          label: Text(_hint ? 'Hide hint' : 'Hint'),
        ),
      ),
      if (_hint)
        const Text(
          'Undo subtraction first: add 7 to each side of the equation.',
        ),
    ],
  );

  Widget _answers() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Select one answer.', style: TextStyle(fontSize: 13)),
      const SizedBox(height: 20),
      for (final choice in (widget.question.kind as McqKind).choices)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: _selected == choice.label
                      ? const Color(0xFFEDF2FF)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: _selected == choice.label
                          ? _blue
                          : const Color(0xFF93979E),
                      width: _selected == choice.label ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _eliminated.contains(choice.label)
                        ? null
                        : () => setState(() {
                            _selected = choice.label;
                            _checked = false;
                          }),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _ink),
                            ),
                            child: Text(choice.label),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: _eliminated.contains(choice.label)
                                      ? .4
                                      : 1,
                                  child: MathText(
                                    choice.md,
                                    style: _theme.textTheme.bodyLarge,
                                  ),
                                ),
                                if (_eliminated.contains(choice.label))
                                  const Divider(color: _ink, thickness: 2),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _eliminated.contains(choice.label)
                    ? 'Restore ${choice.label}'
                    : 'Eliminate ${choice.label}',

                onPressed: () => setState(() {
                  if (!_eliminated.remove(choice.label)) {
                    _eliminated.add(choice.label);
                    if (_selected == choice.label) _selected = '';
                  }
                  _checked = false;
                }),
                icon: Icon(
                  _eliminated.contains(choice.label)
                      ? Icons.undo
                      : Icons.remove_circle_outline,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => setState(() => _checked = true),
          child: const Text('Check answer'),
        ),
      ),
      if (_checked)
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F4F9),
            border: Border(left: BorderSide(color: _blue, width: 3)),
          ),
          child: Text(
            'Practice: $_result. '
            'Add 7, then divide by 3: x = 12. The answer is B.',
          ),
        ),
    ],
  );

  Widget _footer(BuildContext context) {
    final navigator = OutlinedButton(
      onPressed: () => _showQuestions(context),
      child: const Text('Question 3 of 10 ▲'),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () => _navigationNotice(context),
          child: const Text('Back'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => _navigationNotice(context),
          child: const Text('Next'),
        ),
      ],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _ink)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 700) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    navigator,
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('Student'), actions],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(child: Text('Student')),
                  navigator,
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: actions,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigationNotice(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prototype preview: only question 3 is available.'),
        ),
      );

  Future<void> _showQuestions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Math · Module 1',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Filled = answered · outline = current · bookmark = marked',
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (var n = 1; n <= 10; n++)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            n <= 2 || (n == 3 && _selected.isNotEmpty)
                            ? const Color(0xFFE1E9FB)
                            : Colors.white,
                        side: BorderSide(
                          color: n == 3 ? _blue : const Color(0xFF93979E),
                          width: n == 3 ? 2 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        if (n != 3) _navigationNotice(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$n'),
                          if (n == 3 && _marked)
                            const Icon(Icons.bookmark, size: 12),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
