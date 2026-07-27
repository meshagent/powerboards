import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/grant.dart';

void main() {
  test('room grant summaries derive site user/owner/member display from OpenFGA roles', () {
    final owner = ProjectRoomGrant(
      resource: const AccessResource(type: 'room', id: 'room-1', name: 'demo'),
      subject: const AccessSubject(type: 'user', id: 'user-1'),
      directRoles: const ['admin', 'list'],
    );
    final member = ProjectRoomGrant(
      resource: const AccessResource(type: 'room', id: 'room-1', name: 'demo'),
      subject: const AccessSubject(type: 'group', id: 'group-1'),
      directRoles: const ['operator', 'list'],
    );
    final siteUser = ProjectRoomGrant(
      resource: const AccessResource(type: 'room', id: 'room-1', name: 'demo'),
      subject: const AccessSubject(type: 'user', id: 'user-2'),
      directRoles: const ['site_user', 'list'],
    );

    expect(GrantSummary.fromGrant(owner).role, GrantRole.owner);
    expect(GrantSummary.fromGrant(member).role, GrantRole.nonOwner);
    expect(GrantSummary.fromGrant(siteUser).role, GrantRole.siteUser);
  });
}
