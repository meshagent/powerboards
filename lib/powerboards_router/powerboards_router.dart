import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uri/uri.dart';

abstract class PathRouterProvider {
  List<PathRoute> get routes;
}

class PathRouteMatch {
  PathRouteMatch({required this.parameters, required this.route, required this.builder, required this.uri, this.extra});

  /// The [Uri] that matched this route
  final Uri uri;

  /// Parameters pulled from the [UriTemplate] associated with this route
  final Map<String, String?> parameters;

  /// The [PathRoute] that matched this route
  final PathRoute route;

  /// Extra data passed to the route
  final Object? extra;

  /// Build the [Widget] to display for this route
  Widget Function(BuildContext context, PathRouteMatch route) builder;

  /// Lookup the [PathRouteMatch] from the current context
  static PathRouteMatch of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UriRouteData>()!.route;
  }
}

/// We use a private [InheritedWidget] to allow children to lookup the current
/// route if it was not explicitly passed to them.
class _UriRouteData extends InheritedWidget {
  const _UriRouteData(this.route, {required super.child});

  final PathRouteMatch route;

  @override
  bool updateShouldNotify(_UriRouteData oldWidget) {
    return oldWidget.route != route;
  }
}

typedef KeyBuilder = LocalKey Function(PathRouteMatch route);

class PathRoute {
  /// A [PathRoute] which uses a unique key
  PathRoute({this.name, required this.path, required this.builder})
    : parser = UriParser(UriTemplate(path)),
      keyBuilder = (() {
        final key = UniqueKey();
        return (route) => key;
      })();

  /// A [PathRoute] which uses a static key
  PathRoute.key({this.name, required this.path, required this.builder, required LocalKey key})
    : parser = UriParser(UriTemplate(path)),
      keyBuilder = ((route) => key);

  /// A [PathRoute] which uses a dynamic key
  PathRoute.keyBuilder({this.name, required this.path, required this.builder, required KeyBuilder? keyBuilder})
    : parser = UriParser(UriTemplate(path)),
      keyBuilder =
          keyBuilder ??
          (() {
            final key = UniqueKey();
            return (route) => key;
          })();

  /// The path used by this route, must be a valid [UriTemplate]
  final String path;

  /// A name to associate with the [Page] created when this matches
  final String? name;

  /// A [UriParser] used to match against this route's path
  final UriPattern parser;

  /// Returns a key for a given route, if the key matches the current page's
  /// key, the content of the current page will be updated instead of
  /// causing navigation to occur, allowing pages to share a [StatefulWidget]
  /// across different paths.
  final KeyBuilder keyBuilder;

  /// Builds the [Widget] for pages matched by this route
  final Widget Function(BuildContext context, PathRouteMatch route) builder;
}

class PathRouteInformationParser extends RouteInformationParser<PathRouteMatch> {
  const PathRouteInformationParser({required this.notFound, required this.routes});

  /// The route to use when no route is matched
  final PathRoute notFound;

  /// A list of routes to match against
  final List<PathRoute> routes;

  @override
  SynchronousFuture<PathRouteMatch> parseRouteInformation(RouteInformation routeInformation) {
    final u = routeInformation.uri;

    final normalizedPath = (u.path.isEmpty && u.host.isNotEmpty) ? '/${u.host}' : (u.path.isEmpty ? '/' : u.path);

    final routingUri = Uri(
      path: normalizedPath,
      queryParameters: u.queryParameters.isEmpty ? null : u.queryParameters,
      fragment: u.fragment.isEmpty ? null : u.fragment,
    );

    for (var route in routes) {
      final match = route.parser.match(routingUri);

      if (match != null && match.rest.path.isEmpty) {
        return SynchronousFuture(
          PathRouteMatch(
            uri: routeInformation.uri,
            route: route,
            parameters: match.parameters,
            builder: route.builder,
            extra: routeInformation.state,
          ),
        );
      }
    }

    return SynchronousFuture(
      PathRouteMatch(uri: routeInformation.uri, route: notFound, parameters: {}, builder: notFound.builder, extra: routeInformation.state),
    );
  }

  @override
  RouteInformation restoreRouteInformation(PathRouteMatch configuration) {
    return RouteInformation(uri: configuration.uri, state: configuration.extra);
  }
}

class PathRouteDelegate extends RouterDelegate<PathRouteMatch> with ChangeNotifier, PopNavigatorRouterDelegateMixin<PathRouteMatch> {
  PathRouteDelegate({required this.initialRoute}) {
    setNewRoutePath(initialRoute);
  }

  final PathRouteMatch initialRoute;
  final List<Page> _pages = [];

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      // The navigator wants a unique array every time it builds, if we
      // only pass the pages, it will not update
      pages: [..._pages],
      transitionDelegate: PathTransitionDelegate(),
      onDidRemovePage: (page) {
        _pages.remove(page);
      },
    );
  }

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  ValueNotifier<PathRouteMatch>? _pageRoutes;

  // we don't use an async function here because there's nothing async about
  // this and we want to be able to complete the work from the constructor
  // for our initial route
  @override
  Future<void> setNewRoutePath(PathRouteMatch configuration) {
    final key = configuration.route.keyBuilder(configuration);
    if (_pages.isNotEmpty && _pages.last.key == key) {
      _pageRoutes!.value = configuration;
    } else {
      // Just because we have multiple routes doesn't mean we want it to result
      // in multiple pages. For example in the case where we have a stateful
      // navigation bar and /contacts and /contacts/1, we don't want
      // a page transition when someone taps a contact.
      //
      // By using a ValueNotifier, we can update the content of a page when
      // it's key matches the route
      final routes = ValueNotifier<PathRouteMatch>(configuration);
      _pageRoutes = routes;

      // We only want a single level in our nav stack, so we'll clear the stack
      // on nav. We could add to the end of the list if we want the stack to
      // grow
      if (_pages.isNotEmpty) {
        _pages.clear();
      }
      _pages.add(
        MaterialPage(
          maintainState: false,
          key: key,
          name: configuration.route.name,
          arguments: configuration,
          child: ValueListenableBuilder<PathRouteMatch>(
            valueListenable: routes,
            builder: (context, current, _) => _UriRouteData(current, child: current.builder(context, current)),
          ),
        ),
      );

      notifyListeners();
    }
    return Future<void>(() {});
  }
}

extension PathRouterExtension on BuildContext {
  /// Navigate to a path
  ///
  /// @param location The location ro redirect to
  /// @param replace Whether to replace the path in the history
  Future<void> go(String location, {Object? extra, bool replace = false}) async {
    final router = Router.of(this);
    router.go(location, extra: extra, replace: replace);
  }
}

extension RouterExtension on Router {
  // Required to push new paths into the address bar on web
  //SystemNavigator.routeInformationUpdated(
  //    uri: Uri.parse(location), state: extra, replace: replace);
  Future<void> go(String location, {Object? extra, bool replace = false}) async {
    final route = await routeInformationParser!.parseRouteInformation(RouteInformation(uri: Uri.parse(location), state: extra));

    routeInformationProvider!.routerReportsNewRouteInformation(RouteInformation(uri: Uri.parse(location), state: extra));

    routerDelegate.setNewRoutePath(route);
  }
}

typedef PathRouteConfiguration = ({PathRouteInformationParser routeInformationParser, PathRouteDelegate routerDelegate});

PathRouteConfiguration setupPathRouter({Uri? uri, required PathRoute notFound, required List<PathRoute> routes}) {
  final parser = PathRouteInformationParser(routes: routes, notFound: notFound);
  late final PathRouteMatch initialRoute;

  parser.parseRouteInformation(RouteInformation(uri: uri ?? Uri.parse("/"))).then((value) {
    initialRoute = value;
  });

  return (routeInformationParser: parser, routerDelegate: PathRouteDelegate(initialRoute: initialRoute));
}

class NoAnimationTransitionDelegate extends TransitionDelegate<void> {
  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord> locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>> pageRouteToPagelessRoutes,
  }) {
    final List<RouteTransitionRecord> results = <RouteTransitionRecord>[];

    ///
    for (final RouteTransitionRecord pageRoute in newPageRouteHistory) {
      if (pageRoute.isWaitingForEnteringDecision) {
        pageRoute.markForAdd();
      }
      results.add(pageRoute);

      ///
    }
    for (final RouteTransitionRecord exitingPageRoute in locationToExitingPageRoute.values) {
      if (exitingPageRoute.isWaitingForExitingDecision) {
        exitingPageRoute.markForComplete();
        final List<RouteTransitionRecord>? pagelessRoutes = pageRouteToPagelessRoutes[exitingPageRoute];
        if (pagelessRoutes != null) {
          for (final RouteTransitionRecord pagelessRoute in pagelessRoutes) {
            pagelessRoute.markForComplete();
          }
        }
      }
      results.add(exitingPageRoute);

      ///
    }
    return results;
  }
}

/// Based on [DefaultTransitionDelegate] but pops if new route path is prefix
/// of exiting route path
class PathTransitionDelegate extends TransitionDelegate<void> {
  bool isPrefixPath(String basePath, String testPath) {
    final baseSegments = Uri.parse(basePath).pathSegments;
    final testSegments = Uri.parse(testPath).pathSegments;

    if (baseSegments.length >= testSegments.length) {
      return false;
    }

    for (int i = 0; i < baseSegments.length; i++) {
      if (baseSegments[i] != testSegments[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord> locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>> pageRouteToPagelessRoutes,
  }) {
    final List<RouteTransitionRecord> results = <RouteTransitionRecord>[];

    // Determine if we're performing a pop based on the paths
    PathRouteMatch? oldRouteMatch;
    if (locationToExitingPageRoute.isNotEmpty) {
      final exitingRouteRecord = locationToExitingPageRoute.values.last;
      oldRouteMatch = exitingRouteRecord.route.settings.arguments as PathRouteMatch?;
    }

    PathRouteMatch? newRouteMatch;
    if (newPageRouteHistory.isNotEmpty) {
      final enteringRouteRecord = newPageRouteHistory.last;
      newRouteMatch = enteringRouteRecord.route.settings.arguments as PathRouteMatch?;
    }

    final String? oldRoutePath = oldRouteMatch?.uri.path;
    final String? newRoutePath = newRouteMatch?.uri.path;

    bool isPop = false;
    if (oldRoutePath != null && newRoutePath != null) {
      if (isPrefixPath(newRoutePath, oldRoutePath)) {
        isPop = true;
      }
    }

    // This method will handle the exiting route and its corresponding pageless
    // route at this location. It will also recursively check if there is any
    // other exiting routes above it and handle them accordingly.
    void handleExitingRoute(RouteTransitionRecord? location, bool isLast) {
      final RouteTransitionRecord? exitingPageRoute = locationToExitingPageRoute[location];
      if (exitingPageRoute == null) {
        return;
      }
      if (exitingPageRoute.isWaitingForExitingDecision) {
        final bool hasPagelessRoute = pageRouteToPagelessRoutes.containsKey(exitingPageRoute);
        final bool isLastExitingPageRoute = isLast && !locationToExitingPageRoute.containsKey(exitingPageRoute);

        if (isPop) {
          exitingPageRoute.markForPop(exitingPageRoute.route.currentResult);
        } else if (isLastExitingPageRoute && !hasPagelessRoute) {
          exitingPageRoute.markForPop(exitingPageRoute.route.currentResult);
        } else {
          exitingPageRoute.markForComplete(exitingPageRoute.route.currentResult);
        }

        if (hasPagelessRoute) {
          final List<RouteTransitionRecord> pagelessRoutes = pageRouteToPagelessRoutes[exitingPageRoute]!;
          for (final RouteTransitionRecord pagelessRoute in pagelessRoutes) {
            // It is possible that a pageless route that belongs to an exiting
            // page-based route does not require exiting decision. This can
            // happen if the page list is updated right after a Navigator.pop.
            if (pagelessRoute.isWaitingForExitingDecision) {
              if (isPop) {
                pagelessRoute.markForPop(pagelessRoute.route.currentResult);
              } else if (isLastExitingPageRoute && pagelessRoute == pagelessRoutes.last) {
                pagelessRoute.markForPop(pagelessRoute.route.currentResult);
              } else {
                pagelessRoute.markForComplete(pagelessRoute.route.currentResult);
              }
            }
          }
        }
      }
      results.add(exitingPageRoute);

      // It is possible there is another exiting route above this exitingPageRoute.
      handleExitingRoute(exitingPageRoute, isLast);
    }

    void handleNewRoute() {
      for (final RouteTransitionRecord pageRoute in newPageRouteHistory) {
        final bool isLastIteration = newPageRouteHistory.last == pageRoute;
        if (pageRoute.isWaitingForEnteringDecision) {
          if (!locationToExitingPageRoute.containsKey(pageRoute) && isLastIteration && !isPop) {
            pageRoute.markForPush();
          } else {
            pageRoute.markForAdd();
          }
        }
        results.add(pageRoute);
        handleExitingRoute(pageRoute, isLastIteration);
      }
    }

    if (isPop) {
      //Ensure exiting route on top of results to see pop animation
      handleNewRoute();
      handleExitingRoute(null, newPageRouteHistory.isEmpty);
    } else {
      handleExitingRoute(null, newPageRouteHistory.isEmpty);
      handleNewRoute();
    }

    return results;
  }
}
