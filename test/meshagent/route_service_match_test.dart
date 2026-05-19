import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/route_service_match.dart';

void main() {
  ServiceSpec buildService({required String serviceId, required List<int> ports}) {
    return ServiceSpec(
      metadata: ServiceMetadata(name: 'demo', annotations: {'meshagent.service.id': serviceId}),
      ports: [for (final port in ports) PortSpec(num: PortNum.fromInt(port))],
    );
  }

  test('matches routes by service id annotation when present', () {
    final service = buildService(serviceId: 'demo-web', ports: [8000]);
    final routes = [
      buildRoute(domain: 'demo.meshagent.app', port: 9000, annotations: {'meshagent.service.id': 'demo-web'}),
      buildRoute(domain: 'other.meshagent.app', port: 8000, annotations: {'meshagent.service.id': 'other-web'}),
    ];

    final matched = routesForService(routes: routes, service: service);

    expect(matched.map((route) => route.domain).toList(), ['demo.meshagent.app']);
  });

  test('falls back to matching by port when service id annotation is missing', () {
    final service = buildService(serviceId: 'demo-web', ports: [8000, 9000]);
    final routes = [
      buildRoute(domain: 'demo.meshagent.app', port: 8000),
      buildRoute(domain: 'api.meshagent.app', port: 9000),
      buildRoute(domain: 'other.meshagent.app', port: 7000),
    ];

    final matched = routesForService(routes: routes, service: service);

    expect(matched.map((route) => route.domain).toList(), ['demo.meshagent.app', 'api.meshagent.app']);
  });
}

Route buildRoute({required String domain, required int port, Map<String, String> annotations = const {}}) {
  return Route(
    domain: domain,
    spec: RouteSpec(
      metadata: RouteMetadata(name: domain, annotations: annotations),
      domain: domain,
      backend: RouteBackend(room: RouteBackendTarget(name: 'room-1')),
      paths: [RoutePath(targetPort: port)],
    ),
  );
}
