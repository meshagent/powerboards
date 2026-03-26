import 'package:meshagent/meshagent.dart';
import 'package:meshagent/meshagent.dart' as ma;

const _serviceIdAnnotation = 'meshagent.service.id';

String serviceIdForSpec(ServiceSpec service) {
  final value = service.metadata.annotations[_serviceIdAnnotation];
  return value?.trim() ?? '';
}

Set<String> serviceRoutePorts(ServiceSpec service) {
  final ports = <String>{};
  for (final port in service.ports) {
    final portValue = port.num.value;
    if (portValue != null) {
      ports.add(portValue.toString());
    }
  }
  return ports;
}

List<ma.Route> routesForService({required Iterable<ma.Route> routes, required ServiceSpec service}) {
  final serviceId = serviceIdForSpec(service);
  final ports = serviceRoutePorts(service);

  return [
    for (final route in routes)
      if (_routeMatchesService(route: route, serviceId: serviceId, ports: ports)) route,
  ];
}

bool _routeMatchesService({required ma.Route route, required String serviceId, required Set<String> ports}) {
  final routeServiceId = route.annotations[_serviceIdAnnotation]?.trim();
  if (routeServiceId != null && routeServiceId.isNotEmpty) {
    return serviceId.isNotEmpty && routeServiceId == serviceId;
  }

  return ports.contains(route.port);
}
