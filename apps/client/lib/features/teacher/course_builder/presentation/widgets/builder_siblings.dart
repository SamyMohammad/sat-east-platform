import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';
import 'package:sat_east_client/features/teacher/shell/teacher_animated_rows.dart';

class BuilderSiblings<T> extends StatelessWidget {
  const BuilderSiblings({
    required this.kind,
    required this.parentId,
    required this.busy,
    required this.children,
    required this.idOf,
    required this.row,
    super.key,
  });
  final NodeKind kind;
  final String parentId;
  final bool busy;
  final List<T> children;
  final String Function(T) idOf;
  final Widget Function(T, int, Widget, VoidCallback?, VoidCallback?) row;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourseBuilderCubit>();
    final ids = children.map(idOf).toList();
    void reorder(int oldIndex, int newIndex) {
      if (busy) {
        return;
      }
      if (oldIndex == newIndex) {
        return;
      }
      final next = [...ids];
      next.insert(newIndex, next.removeAt(oldIndex));
      unawaited(cubit.reorder(kind, parentId, next));
    }

    return TeacherAnimatedRows(
      layoutBuilder: (context, rows) => IgnorePointer(
        // Outgoing rows temporarily shift the indexes used by drag handles.
        ignoring: rows.length != children.length,
        child: ReorderableListView(
          key: ValueKey('siblings-${kind.name}-$parentId'),
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            if (rows.length == children.length) reorder(oldIndex, newIndex);
          },
          children: rows,
        ),
      ),
      children: [
        for (var index = 0; index < children.length; index++)
          KeyedSubtree(
            key: ValueKey(ids[index]),
            child: row(
              children[index],
              index,
              ReorderableDragStartListener(
                index: index,
                enabled: !busy,
                child: Semantics(
                  label: 'Drag to reorder',
                  child: const SizedBox(
                    width: AppSpace.s8,
                    height: AppSize.touchTarget,
                    child: Icon(AppIcons.drag, size: AppSize.iconSmall),
                  ),
                ),
              ),
              index == 0 || busy ? null : () => reorder(index, index - 1),
              index == children.length - 1 || busy
                  ? null
                  : () => reorder(index, index + 1),
            ),
          ),
      ],
    );
  }
}
