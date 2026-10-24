import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sat_east_client/core/text/text_direction.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

class BuilderNodeRow extends StatefulWidget {
  const BuilderNodeRow({
    required this.id,
    required this.code,
    required this.title,
    required this.inUse,
    required this.busy,
    required this.handle,
    required this.onRename,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    this.detail,
    this.addLabel,
    this.onAdd,
    this.isPublished,
    this.isFreePreview,
    this.onPublish,
    this.onNotes,
    this.onPreview,
    super.key,
  });
  final String id;
  final String code;
  final String title;
  final bool inUse;
  final bool busy;
  final Widget handle;
  final Future<void> Function(String) onRename;
  final Future<void> Function() onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String? detail;
  final String? addLabel;
  final VoidCallback? onAdd;
  final bool? isPublished;
  final bool? isFreePreview;
  final VoidCallback? onPublish;
  final VoidCallback? onNotes;
  final ValueChanged<bool>? onPreview;
  @override
  State<BuilderNodeRow> createState() => _BuilderNodeRowState();
}

class _BuilderNodeRowState extends State<BuilderNodeRow> {
  late final _title = TextEditingController(text: widget.title);
  final _form = GlobalKey<FormState>();
  var _editing = false;
  @override
  void didUpdateWidget(BuilderNodeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.title != widget.title) {
      _title.text = widget.title;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.busy || !_form.currentState!.validate()) {
      return;
    }
    setState(() => _editing = false);
    unawaited(widget.onRename(_title.text));
  }

  Widget _name(BuildContext context) => _editing
      ? Form(
          key: _form,
          child: TextFormField(
            key: ValueKey('title-${widget.id}'),
            controller: _title,
            autofocus: true,
            enabled: !widget.busy,
            maxLength: 120,
            textDirection: detectTextDirection(_title.text),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Rename',
              counterText: '',
              suffixIcon: IconButton(
                key: ValueKey('save-${widget.id}'),
                onPressed: widget.busy ? null : _save,
                icon: const Icon(Icons.check, semanticLabel: 'Save'),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a title.' : null,
            onFieldSubmitted: (_) => _save(),
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.code,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: BookletSpace.s2),
                Expanded(
                  child: Text(
                    widget.title,
                    textDirection: detectTextDirection(widget.title),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (widget.detail case final detail?)
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            if (widget.addLabel case final label?)
              TextButton.icon(
                onPressed: widget.busy ? null : widget.onAdd,
                icon: const Icon(Icons.add, size: BookletSize.iconSmall),
                label: Text(label),
              ),
          ],
        );
  Future<void> _openMenu(BuildContext buttonContext) async {
    final button = buttonContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final value = await showMenu<String>(
      context: buttonContext,
      position: RelativeRect.fromRect(
        origin & button.size,
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (widget.onNotes != null)
          const PopupMenuItem(value: 'notes', child: Text('Notes\u2026')),
        if (widget.onPublish != null)
          PopupMenuItem(
            value: 'publish',
            child: Text(widget.isPublished == true ? 'Unpublish' : 'Publish'),
          ),
        PopupMenuItem(
          value: 'delete',
          enabled: !widget.inUse,
          child: widget.inUse
              ? const ListTile(
                  enabled: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Delete'),
                  subtitle: Text('In use'),
                  trailing: Icon(Icons.info_outline),
                )
              : const Text('Delete'),
        ),
      ],
    );
    if (!mounted) return;
    switch (value) {
      case 'rename':
        setState(() {
          _title.text = widget.title;
          _editing = true;
        });
      case 'publish':
        widget.onPublish?.call();
      case 'notes':
        widget.onNotes?.call();
      case 'delete':
        unawaited(widget.onDelete());
    }
  }

  Widget _menu() => Builder(
    builder: (context) => IconButton(
      key: ValueKey('menu-${widget.id}'),
      onPressed: widget.busy ? null : () => unawaited(_openMenu(context)),
      icon: Icon(Icons.more_vert, semanticLabel: 'More actions ${widget.code}'),
    ),
  );
  Widget _moves() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        label: 'Move ${widget.code} up',
        button: true,
        child: IconButton(
          key: ValueKey('move-up-${widget.id}'),
          onPressed: widget.busy ? null : widget.onMoveUp,
          icon: const Icon(Icons.arrow_upward, size: BookletSize.iconSmall),
        ),
      ),
      Semantics(
        label: 'Move ${widget.code} down',
        button: true,
        child: IconButton(
          key: ValueKey('move-down-${widget.id}'),
          onPressed: widget.busy ? null : widget.onMoveDown,
          icon: const Icon(Icons.arrow_downward, size: BookletSize.iconSmall),
        ),
      ),
    ],
  );
  Widget _preview() => Semantics(
    label: 'Free preview ${widget.code}',
    child: Switch(
      key: ValueKey('preview-${widget.id}'),
      value: widget.isFreePreview ?? false,
      onChanged: widget.busy ? null : widget.onPreview,
    ),
  );
  Widget _status() => Semantics(
    button: true,
    label: '${widget.isPublished! ? 'Unpublish' : 'Publish'} ${widget.code}',
    child: TextButton.icon(
      key: ValueKey('publish-${widget.id}'),
      onPressed: widget.busy ? null : widget.onPublish,
      icon: Icon(
        widget.isPublished! ? Icons.check_circle_outline : Icons.edit_outlined,
        size: BookletSize.iconStatus,
      ),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.isPublished! ? 'Published' : 'Draft',
          maxLines: 1,
          softWrap: false,
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 600;
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BookletSpace.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  widget.handle,
                  Expanded(child: _name(context)),
                  if (!compact) ...[
                    SizedBox(
                      width: 120,
                      child: widget.isPublished == null ? null : _preview(),
                    ),
                    SizedBox(
                      width: 120,
                      child: widget.isPublished == null ? null : _status(),
                    ),
                    _moves(),
                  ],
                  _menu(),
                ],
              ),
              if (compact)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _moves(),
                    if (widget.isPublished != null) ...[_preview(), _status()],
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
