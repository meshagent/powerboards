import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/meshagent.dart' as meshagent_api;
import 'package:powerboards/meshagent/file_table_view.dart';

void main() {
  test('website preview uses route for app-like webserver folders', () {
    final entries = [
      meshagent_api.StorageEntry(
        name: 'package.json',
        isFolder: false,
        size: 750,
        createdAt: DateTime(2026, 6, 23),
        updatedAt: DateTime(2026, 6, 23),
      ),
      meshagent_api.StorageEntry(
        name: 'src',
        isFolder: true,
        size: null,
        createdAt: DateTime(2026, 6, 23),
        updatedAt: DateTime(2026, 6, 23),
      ),
    ];

    expect(powerboardsWebsitePreviewShouldUseRoute(entries), isTrue);
  });

  test('website preview keeps static mode for simple html folders', () {
    final entries = [
      meshagent_api.StorageEntry(
        name: 'index.html',
        isFolder: false,
        size: 1200,
        createdAt: DateTime(2026, 6, 23),
        updatedAt: DateTime(2026, 6, 23),
      ),
      meshagent_api.StorageEntry(
        name: 'styles.css',
        isFolder: false,
        size: 3200,
        createdAt: DateTime(2026, 6, 23),
        updatedAt: DateTime(2026, 6, 23),
      ),
    ];

    expect(powerboardsWebsitePreviewShouldUseRoute(entries), isFalse);
  });

  test('powerboardsRefreshFilesWebServerState waits for refreshed service state', () async {
    var servicesFetchCount = 0;
    var routesFetchCount = 0;
    final servicesRefreshCompleter = Completer<List<meshagent_api.ServiceSpec>>();
    final routesRefreshCompleter = Completer<List<meshagent_api.Route>>();

    final services = Resource<List<meshagent_api.ServiceSpec>>(() {
      servicesFetchCount += 1;
      if (servicesFetchCount == 1) {
        return Future.value(const <meshagent_api.ServiceSpec>[]);
      }
      return servicesRefreshCompleter.future;
    });
    final roomRoutes = Resource<List<meshagent_api.Route>>(() {
      routesFetchCount += 1;
      if (routesFetchCount == 1) {
        return Future.value(const <meshagent_api.Route>[]);
      }
      return routesRefreshCompleter.future;
    });

    await services.untilReady();
    await roomRoutes.untilReady();

    var completed = false;
    final refreshFuture = powerboardsRefreshFilesWebServerState(services: services, roomRoutes: roomRoutes).then((_) {
      completed = true;
    });

    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    expect(services.state.isReady, isTrue);
    expect(roomRoutes.state.isReady, isTrue);
    expect(services.state.asReady?.isRefreshing, isTrue);
    expect(roomRoutes.state.asReady?.isRefreshing, isTrue);

    servicesRefreshCompleter.complete(const <meshagent_api.ServiceSpec>[]);
    routesRefreshCompleter.complete(const <meshagent_api.Route>[]);
    await refreshFuture;

    expect(completed, isTrue);
    expect(servicesFetchCount, 2);
    expect(routesFetchCount, 2);
    expect(services.state.asReady?.isRefreshing, isFalse);
    expect(roomRoutes.state.asReady?.isRefreshing, isFalse);
  });
}
