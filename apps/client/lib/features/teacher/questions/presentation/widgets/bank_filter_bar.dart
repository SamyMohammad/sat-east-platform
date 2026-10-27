import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/bank_copy.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_cubit.dart';
import 'package:sat_east_client/features/teacher/questions/presentation/cubit/question_bank_state.dart';

class BankFilterBar extends StatelessWidget {
  const BankFilterBar({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<QuestionBankCubit, QuestionBankState>(
    buildWhen: (previous, next) =>
        previous.filter != next.filter || previous.topics != next.topics,
    builder: (context, state) {
      final filter = state.filter;
      final topics = state.topics
          .where(
            (c) =>
                filter.courseCode == null || c.courseCode == filter.courseCode,
          )
          .expand((c) => c.topics)
          .toList();
      final subtopics = topics
          .where((t) => filter.topicId == null || t.id == filter.topicId)
          .expand((t) => t.subtopics)
          .toList();
      void change(String key, String? value) {
        final cubit = context.read<QuestionBankCubit>();
        unawaited(cubit.setFilter(cubit.state.filter.withValue(key, value)));
      }

      return Column(
        spacing: BookletSpace.s4,
        children: [
          _BankSearch(value: filter.q, onChanged: (q) => change('q', q)),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = switch (BookletLayout.forWidth(
                constraints.maxWidth,
              )) {
                BookletLayout.compact => 2,
                BookletLayout.medium => 3,
                BookletLayout.expanded => 4,
              };
              final width =
                  (constraints.maxWidth - BookletSpace.s3 * (columns - 1)) /
                  columns;
              Widget select(
                String key,
                String label,
                String? value,
                List<(String, String)> options,
              ) => SizedBox(
                width: width,
                child: _BankSelect(
                  field: key,
                  label: label,
                  value: value,
                  options: options,
                  onChanged: (value) => change(key, value),
                ),
              );
              return Wrap(
                spacing: BookletSpace.s3,
                runSpacing: BookletSpace.s4,
                children: [
                  select('courseCode', 'Course', filter.courseCode, [
                    for (final c in state.topics) (c.courseCode, c.courseCode),
                  ]),
                  select('topicId', 'Topic', filter.topicId, [
                    for (final t in topics) (t.id, t.title),
                  ]),
                  select('subtopicId', 'Subtopic', filter.subtopicId, [
                    for (final s in subtopics) (s.id, s.title),
                  ]),
                  select('status', 'Status', filter.status, [
                    for (final v in [
                      'draft',
                      'solved',
                      'needs_review',
                      'approved',
                      'published',
                      'retired',
                    ])
                      (v, bankValueLabel(v)),
                  ]),
                  select('pool', 'Pool', filter.pool, [
                    for (final v in ['practice', 'quiz', 'mock_reserve'])
                      (v, bankValueLabel(v)),
                  ]),
                  select('difficulty', 'Difficulty', filter.difficulty, [
                    for (final v in ['E', 'M', 'H']) (v, v),
                  ]),
                  select('type', 'Type', filter.type, [
                    for (final v in ['mcq', 'spr']) (v, bankValueLabel(v)),
                  ]),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

class _BankSelect extends StatelessWidget {
  const _BankSelect({
    required this.field,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String field;
  final String label;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: ValueKey('bank-filter-$field'),
        isExpanded: true,
        isDense: true,
        value: value,
        onChanged: onChanged,
        items: [
          const DropdownMenuItem(child: Text('All')),
          for (final (id, title) in options)
            DropdownMenuItem(
              value: id,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    ),
  );
}

class _BankSearch extends StatefulWidget {
  const _BankSearch({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  State<_BankSearch> createState() => _BankSearchState();
}

class _BankSearchState extends State<_BankSearch> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_BankSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('bank-search'),
    controller: _controller,
    onChanged: widget.onChanged,
    decoration: const InputDecoration(
      labelText: 'Search questions',
      prefixIcon: Icon(AppIcons.search),
    ),
  );
}
