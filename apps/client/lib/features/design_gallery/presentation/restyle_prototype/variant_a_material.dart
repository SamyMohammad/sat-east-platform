import 'package:flutter/material.dart';

import 'package:sat_east_client/core/math_render/math_text.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';

class VariantAMaterial extends StatefulWidget {
  const VariantAMaterial({required this.question, super.key});

  final QuestionData question;

  @override
  State<VariantAMaterial> createState() => _VariantAMaterialState();
}

class _VariantAMaterialState extends State<VariantAMaterial> {
  String _selected = 'A';
  String get _result => _selected == 'B' ? 'Correct' : 'Incorrect';
  bool _checked = false;
  bool _hint = false;

  static final _theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5546FF)),
    fontFamily: 'NotoSans',
    visualDensity: VisualDensity.standard,
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: _theme,
    child: Builder(builder: _screen),
  );

  Widget _screen(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final choices = (widget.question.kind as McqKind).choices;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const LinearProgressIndicator(value: .3, minHeight: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Icon(
                          Icons.auto_awesome,
                          color: colors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Linear equations',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Practice · Question 3 of 10',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          children: [
                            const Chip(label: Text('Skill · Linear equations')),
                            const Chip(label: Text('Easy')),
                            FilterChip(
                              selected: _hint,
                              avatar: const Icon(
                                Icons.lightbulb_outline,
                                size: 18,
                              ),
                              label: const Text('Hint'),
                              onSelected: (value) =>
                                  setState(() => _hint = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card.filled(
                          color: colors.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.question.label,
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 20),
                                MathText(
                                  widget.question.stemMd,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_hint)
                          const Card.outlined(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Start by adding 7 to both sides '
                                'to isolate the term with x.',
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          'Choose your answer',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        for (final choice in choices)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card.outlined(
                              color: _selected == choice.label
                                  ? colors.primaryContainer
                                  : colors.surface,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => setState(() {
                                  _selected = choice.label;
                                  _checked = false;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selected == choice.label
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        choice.label,
                                        style: theme.textTheme.labelLarge,
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: MathText(
                                          choice.md,
                                          style: theme.textTheme.bodyLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_checked)
                          Card.filled(
                            color: _selected == 'B'
                                ? colors.tertiaryContainer
                                : colors.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                '$_result.\n'
                                'Add 7 to get 3x = 36, then divide by 3. '
                                'The answer is B: x = 12.',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: colors.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: FilledButton.icon(
                  onPressed: () => setState(() => _checked = true),
                  icon: const Icon(Icons.check),
                  label: const Text('Check answer'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
