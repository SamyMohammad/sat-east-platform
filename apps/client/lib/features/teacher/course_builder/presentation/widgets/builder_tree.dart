import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/course_tree.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_state.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/widgets/builder_node_row.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/widgets/builder_siblings.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/widgets/builder_title_dialog.dart';

class BuilderTree extends StatelessWidget {
  const BuilderTree({required this.loaded, super.key});
  final CourseBuilderLoaded loaded;

  Future<void> _add(
    BuildContext context,
    String label,
    Future<void> Function(String) action,
  ) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => BuilderTitleDialog(label: label),
    );
    if (context.mounted && title != null) {
      await action(title);
    }
  }

  Future<void> _publish(
    BuildContext context,
    BuilderTopic topic,
    String code,
  ) async {
    final cubit = context.read<CourseBuilderCubit>();
    if (!topic.isPublished) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publish'),
          content: Text(
            'Publish $code ${topic.title}? '
            'Students on the path will see it.',
            textDirection: detectTextDirection('Publish $code ${topic.title}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Publish'),
            ),
          ],
        ),
      );
      if (!context.mounted || confirmed != true) {
        return;
      }
    }
    await cubit.setFlags(topic.id, isPublished: !topic.isPublished);
  }

  Future<void> _delete(
    BuildContext context,
    NodeKind kind,
    String id,
    String code,
    String title,
  ) async {
    final cubit = context.read<CourseBuilderCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text(
          "Delete $code $title? This can't be undone.",
          textDirection: detectTextDirection('Delete $code $title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    await cubit.delete(kind, id);
  }

  Widget _units(BuildContext context) {
    final tree = loaded.tree!;
    final cubit = context.read<CourseBuilderCubit>();
    return BuilderSiblings<BuilderUnit>(
      kind: NodeKind.unit,
      parentId: tree.courseId,
      busy: loaded.busyId != null,
      children: tree.units,
      idOf: (unit) => unit.id,
      row: (unit, index, handle, up, down) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BuilderNodeRow(
            key: ValueKey(unit.id),
            id: unit.id,
            code: '${index + 1}',
            title: unit.title,
            detail: '${unit.topics.length} topics',
            inUse: unit.inUse,
            busy: loaded.busyId != null,
            handle: handle,
            onRename: (title) => cubit.rename(NodeKind.unit, unit.id, title),
            onDelete: () => _delete(
              context,
              NodeKind.unit,
              unit.id,
              '${index + 1}',
              unit.title,
            ),
            onMoveUp: up,
            onMoveDown: down,
            addLabel: 'Add topic',
            onAdd: () => unawaited(
              _add(
                context,
                'Add topic',
                (title) => cubit.addTopic(unit.id, title),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: BookletSpace.s2),
            child: _topics(context, unit, index + 1),
          ),
        ],
      ),
    );
  }

  Widget _topics(BuildContext context, BuilderUnit unit, int number) {
    final cubit = context.read<CourseBuilderCubit>();
    return BuilderSiblings<BuilderTopic>(
      kind: NodeKind.topic,
      parentId: unit.id,
      busy: loaded.busyId != null,
      children: unit.topics,
      idOf: (topic) => topic.id,
      row: (topic, index, handle, up, down) {
        final code = '$number.${index + 1}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BuilderNodeRow(
              key: ValueKey(topic.id),
              id: topic.id,
              code: code,
              title: topic.title,
              detail: '${topic.subtopicCount} subtopics',
              inUse: topic.inUse,
              busy: loaded.busyId != null,
              handle: handle,
              onRename: (title) =>
                  cubit.rename(NodeKind.topic, topic.id, title),
              onDelete: () => _delete(
                context,
                NodeKind.topic,
                topic.id,
                code,
                topic.title,
              ),
              onMoveUp: up,
              onMoveDown: down,
              addLabel: 'Add subtopic',
              onAdd: () => unawaited(
                _add(
                  context,
                  'Add subtopic',
                  (title) => cubit.addSubtopic(topic.id, title),
                ),
              ),
              isPublished: topic.isPublished,
              isFreePreview: topic.isFreePreview,
              onPublish: () => unawaited(_publish(context, topic, code)),
              onPreview: (value) =>
                  unawaited(cubit.setFlags(topic.id, isFreePreview: value)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: BookletSpace.s2),
              child: _subtopics(context, topic, code),
            ),
          ],
        );
      },
    );
  }

  Widget _subtopics(BuildContext context, BuilderTopic topic, String prefix) {
    final cubit = context.read<CourseBuilderCubit>();
    return BuilderSiblings<BuilderSubtopic>(
      kind: NodeKind.subtopic,
      parentId: topic.id,
      busy: loaded.busyId != null,
      children: topic.subtopics,
      idOf: (subtopic) => subtopic.id,
      row: (subtopic, index, handle, up, down) => BuilderNodeRow(
        key: ValueKey(subtopic.id),
        id: subtopic.id,
        code: '$prefix.${index + 1}',
        title: subtopic.title,
        inUse: subtopic.inUse,
        busy: loaded.busyId != null,
        handle: handle,
        onRename: (title) =>
            cubit.rename(NodeKind.subtopic, subtopic.id, title),
        onDelete: () => _delete(
          context,
          NodeKind.subtopic,
          subtopic.id,
          '$prefix.${index + 1}',
          subtopic.title,
        ),
        onMoveUp: up,
        onMoveDown: down,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, box) => box.maxWidth < 600
            ? const Text('Course structure')
            : const Row(
                children: [
                  Expanded(child: Text('Name')),
                  SizedBox(width: 120, child: Text('Free preview')),
                  SizedBox(width: 120, child: Text('Status')),
                  SizedBox(width: 144),
                ],
              ),
      ),
      const Divider(),
      _units(context),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: loaded.busyId != null
              ? null
              : () => unawaited(
                  _add(
                    context,
                    'Add unit',
                    context.read<CourseBuilderCubit>().addUnit,
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Add unit'),
        ),
      ),
    ],
  );
}
