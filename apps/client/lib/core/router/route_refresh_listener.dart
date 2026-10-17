import 'package:flutter/widgets.dart';

import 'package:go_router/go_router.dart';

/// Refreshes retained route content when its page becomes the visible leaf.
class RouteRefreshListener extends StatefulWidget {
  const RouteRefreshListener({
    required this.location,
    required this.onRefresh,
    required this.child,
    super.key,
    this.refreshOnReselect = false,
  });

  final String location;
  final VoidCallback onRefresh;
  final Widget child;
  final bool refreshOnReselect;

  @override
  State<RouteRefreshListener> createState() => _RouteRefreshListenerState();
}

class _RouteRefreshListenerState extends State<RouteRefreshListener> {
  GoRouter? _router;
  bool _visible = false;
  bool _refreshScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (identical(router, _router)) return;
    _removeListeners();
    _router = router;
    _visible = _isVisible;
    router?.routerDelegate.addListener(_routeChanged);
    router?.routeInformationProvider.addListener(_navigationRequested);
  }

  // The delegate leaf includes pushed pages, unlike the reported URL.
  bool get _isVisible =>
      _router?.routerDelegate.currentConfiguration.last.matchedLocation ==
      widget.location;

  void _routeChanged() {
    final visible = _isVisible;
    if (visible && !_visible) _scheduleRefresh();
    _visible = visible;
  }

  void _navigationRequested() {
    // An unchanged route does not notify the delegate on tab re-selection.
    if (widget.refreshOnReselect &&
        _visible &&
        _router?.routeInformationProvider.value.uri.path == widget.location) {
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted && _isVisible) widget.onRefresh();
    });
  }

  void _removeListeners() {
    _router?.routerDelegate.removeListener(_routeChanged);
    _router?.routeInformationProvider.removeListener(_navigationRequested);
  }

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
