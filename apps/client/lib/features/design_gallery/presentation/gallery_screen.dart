import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sat_east_client/core/router/app_router.dart';
import 'package:sat_east_client/core/theme/app_icons.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';
import 'package:sat_east_client/features/design_gallery/presentation/gallery_entries.dart';

/// Dev-only screen that shows one `QuestionView` state at a time.
///
/// A [StatefulWidget] only to hold the [GlobalKey] used by "Reopen"; it never
/// calls `setState` (the entry comes from the route).
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({required this.entryId, super.key});

  final String? entryId;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _hostKey = GlobalKey<_EntryHostState>();

  @override
  Widget build(BuildContext context) {
    final entry = galleryEntryById(widget.entryId);
    final index = galleryEntries.indexOf(entry);
    final hasPrevious = index > 0;
    final hasNext = index < galleryEntries.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(BookletSize.touchTarget),
          child: Row(
            children: [
              const SizedBox(width: BookletSpace.s4),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: BookletSize.galleryPicker,
                  ),
                  child: DropdownButton<String>(
                    value: entry.id,
                    isExpanded: true,
                    onChanged: (id) {
                      if (id != null) context.go(galleryLocation(id));
                    },
                    items: [
                      for (final e in galleryEntries)
                        DropdownMenuItem(
                          value: e.id,
                          child: Text(e.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.previous),
                tooltip: 'Previous entry',
                onPressed: hasPrevious
                    ? () => context.go(
                        galleryLocation(galleryEntries[index - 1].id),
                      )
                    : null,
              ),
              IconButton(
                icon: const Icon(AppIcons.next),
                tooltip: 'Next entry',
                onPressed: hasNext
                    ? () => context.go(
                        galleryLocation(galleryEntries[index + 1].id),
                      )
                    : null,
              ),
              if (entry.openOverlay != null)
                TextButton(
                  onPressed: () => _hostKey.currentState?.reopen(),
                  child: const Text('Reopen'),
                ),
              const SizedBox(width: BookletSpace.s2),
            ],
          ),
        ),
      ),
      body: _EntryHost(key: _hostKey, entry: entry),
    );
  }
}

class _EntryHost extends StatefulWidget {
  const _EntryHost({required this.entry, super.key});

  final GalleryEntry entry;

  @override
  State<_EntryHost> createState() => _EntryHostState();
}

class _EntryHostState extends State<_EntryHost> {
  @override
  void initState() {
    super.initState();
    _scheduleOverlay();
  }

  @override
  void didUpdateWidget(_EntryHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) _scheduleOverlay();
  }

  void _scheduleOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      reopen();
    });
  }

  /// Closes leftover overlays, then opens this entry's overlay (if any).
  void reopen() {
    _closeOverlays();
    widget.entry.openOverlay?.call(context);
  }

  void _closeOverlays() {
    _removePopups(Navigator.of(context, rootNavigator: true));
    _removePopups(Navigator.of(context));
  }

  /// Removes (without the exit animation) every [PopupRoute] on [navigator].
  /// `popUntil` would animate out and leave the route mounted for extra
  /// frames, so a fast entry change could still show the old overlay.
  static void _removePopups(NavigatorState navigator) {
    var found = true;
    while (found) {
      found = false;
      // The predicate only peeks at the top route; returning true never pops.
      navigator.popUntil((route) {
        if (route is PopupRoute) {
          found = true;
          navigator.removeRoute(route);
        }
        return true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.entry.builder(context);
}
