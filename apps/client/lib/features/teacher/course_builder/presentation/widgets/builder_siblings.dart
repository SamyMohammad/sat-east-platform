import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/teacher/course_builder/domain/entities/node_kind.dart';
import 'package:sat_east_client/features/teacher/course_builder/presentation/cubit/course_builder_cubit.dart';

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

    return ReorderableListView.builder(
      key: ValueKey('siblings-${kind.name}-$parentId'),
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: children.length,
      onReorderItem: reorder,
      itemBuilder: (context, index) => KeyedSubtree(
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
                width: BookletSpace.s8,
                height: BookletSize.touchTarget,
                child: Icon(AppIcons.drag, size: BookletSize.iconSmall),
              ),
            ),
          ),
          index == 0 || busy ? null : () => reorder(index, index - 1),
          index == children.length - 1 || busy
              ? null
              : () => reorder(index, index + 1),
        ),
      ),
    );
  }
}
