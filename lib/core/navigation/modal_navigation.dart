import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'browser_history_stub.dart'
    if (dart.library.js_interop) 'browser_history_web.dart';

/// Connects imperative dialogs and sheets to the browser's back stack.
class ModalNavigation extends RouterDelegate<RouteInformation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteInformation> {
  ModalNavigation({required this.navigatorKey, required this.home}) {
    _observer = _ModalObserver(this);
  }

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget home;
  late final _ModalObserver _observer;
  final _routes = <Route<dynamic>, int>{};
  int _nextId = 0;
  bool _notificationScheduled = false;
  bool _disposed = false;
  Uri _uri = Uri.parse('/');

  @override
  RouteInformation get currentConfiguration => RouteInformation(
    uri: _uri,
    state: {'modalRoutes': _routes.values.toList()},
  );

  void _changed() {
    if (_notificationScheduled || _disposed) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  Future<void> setNewRoutePath(RouteInformation configuration) async {
    _uri = configuration.uri;
    final requested = _routeIds(configuration);
    final active = _routes.values.toList();
    var keep = 0;
    while (keep < requested.length &&
        keep < active.length &&
        requested[keep] == active[keep]) {
      keep++;
    }
    while (_routes.length > keep) {
      final count = _routes.length;
      await navigatorKey.currentState?.maybePop();
      // A PopScope may handle back inside the current dialog instead.
      if (_routes.length == count) break;
    }
    // Disposed dialogs are deliberately not reopened by forward or refresh.
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    observers: [_observer],
    pages: [MaterialPage<void>(key: const ValueKey('home'), child: home)],
    onDidRemovePage: (_) {},
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _ModalObserver extends NavigatorObserver {
  _ModalObserver(this.navigation);
  final ModalNavigation navigation;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    navigation._routes[route] = ++navigation._nextId;
    navigation._changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
  }

  void _remove(Route<dynamic> route) {
    if (navigation._routes.remove(route) != null) navigation._changed();
  }
}

class ModalRouteInformationParser
    extends RouteInformationParser<RouteInformation> {
  const ModalRouteInformationParser();

  @override
  Future<RouteInformation> parseRouteInformation(
    RouteInformation routeInformation,
  ) => SynchronousFuture(routeInformation);

  @override
  RouteInformation restoreRouteInformation(RouteInformation configuration) =>
      configuration;
}

/// Uses same-URL history entries, and consumes them on explicit dismissal.
class ModalRouteInformationProvider extends PlatformRouteInformationProvider {
  ModalRouteInformationProvider({
    required super.initialRouteInformation,
    ValueChanged<int>? go,
  }) : _go = go ?? (kIsWeb ? goBrowserHistory : null);

  final ValueChanged<int>? _go;
  RouteInformation? _reported;
  RouteInformation? _pending;
  bool _fromPlatform = false;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    if (_pending != null) {
      _pending = routeInformation;
      return;
    }
    final before = _routeIds(_reported ?? value);
    final after = _routeIds(routeInformation);
    var common = 0;
    while (common < before.length &&
        common < after.length &&
        before[common] == after[common]) {
      common++;
    }
    if (!_fromPlatform && _go != null && common < before.length) {
      _pending = routeInformation;
      _go(common - before.length);
      return;
    }
    final pushes =
        after.isNotEmpty &&
        (after.length > before.length ||
            !listEquals(after, before) && !_fromPlatform);
    _fromPlatform = false;
    _reported = routeInformation;
    // Each overlay needs its own entry even if several opened in one frame.
    if (pushes && common == before.length) {
      for (var count = before.length + 1; count < after.length; count++) {
        super.routerReportsNewRouteInformation(
          RouteInformation(
            uri: routeInformation.uri,
            state: {'modalRoutes': after.take(count).toList()},
          ),
          type: RouteInformationReportingType.navigate,
        );
      }
    }
    super.routerReportsNewRouteInformation(
      routeInformation,
      type: pushes
          ? RouteInformationReportingType.navigate
          : RouteInformationReportingType.neglect,
    );
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    _reported = routeInformation;
    final pending = _pending;
    if (pending != null) {
      // A new dialog may have opened while history.go was in flight.
      _pending = null;
      _fromPlatform = true;
      routerReportsNewRouteInformation(pending);
      return SynchronousFuture(true);
    }
    _fromPlatform = true;
    return super.didPushRouteInformation(routeInformation);
  }
}

List<int> _routeIds(RouteInformation information) {
  final state = information.state;
  if (state is! Map) return const [];
  final ids = state['modalRoutes'];
  return ids is List ? ids.whereType<int>().toList() : const [];
}
