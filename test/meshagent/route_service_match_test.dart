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
      Route(domain: 'demo.meshagent.app', roomName: 'room-1', port: '9000', annotations: {'meshagent.service.id': 'demo-web'}),
      Route(domain: 'other.meshagent.app', roomName: 'room-1', port: '8000', annotations: {'meshagent.service.id': 'other-web'}),
    ];

    final matched = routesForService(routes: routes, service: service);

    expect(matched.map((route) => route.domain).toList(), ['demo.meshagent.app']);
  });

  test('falls back to matching by port when service id annotation is missing', () {
    final service = buildService(serviceId: 'demo-web', ports: [8000, 9000]);
    final routes = [
      Route(domain: 'demo.meshagent.app', roomName: 'room-1', port: '8000', annotations: const {}),
      Route(domain: 'api.meshagent.app', roomName: 'room-1', port: '9000', annotations: const {}),
      Route(domain: 'other.meshagent.app', roomName: 'room-1', port: '7000', annotations: const {}),
    ];

    final matched = routesForService(routes: routes, service: service);

    expect(matched.map((route) => route.domain).toList(), ['demo.meshagent.app', 'api.meshagent.app']);
  });
}
