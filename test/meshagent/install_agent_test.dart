import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/install_agent.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';

void main() {
  group('powerboardsInstalledServiceRoute', () {
    test('routes website installs into the website folder in Files', () {
      const projectId = '7c12af6e-7a2f-4cb3-85d4-e6fadc6be7bb';
      final route = powerboardsInstalledServiceRoute(
        projectId: projectId,
        roomName: 'alpha-room',
        serviceId: powerboardsWebServerServiceId,
      );

      final uri = Uri.parse(route);
      expect(uri.path, '/p/${fromUUID(projectId)}/r/alpha-room');
      expect(uri.queryParameters['pane'], 'files');
      expect(uri.queryParameters['p'], 'website/');
    });

    test('routes other installs to the service details page', () {
      const projectId = '7c12af6e-7a2f-4cb3-85d4-e6fadc6be7bb';
      final route = powerboardsInstalledServiceRoute(projectId: projectId, roomName: 'alpha-room', serviceId: 'meshagent.voice');

      expect(route, '/p/${fromUUID(projectId)}/r/alpha-room/a/meshagent.voice');
    });
  });
}
