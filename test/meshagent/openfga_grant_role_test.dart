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

  for (final reversed in [false, true]) {
    test('split room policy entries retain the strongest role regardless of ordering ($reversed)', () {
      ProjectRoomGrant grant(String id, List<String> roles, {String type = 'user'}) => ProjectRoomGrant(
        resource: const AccessResource(type: 'room', id: 'pirates'),
        subject: AccessSubject(type: type, id: id),
        directRoles: roles,
      );
      final policy = [
        grant('jesse', ['admin']),
        grant('jesse', ['list']),
        grant('site-user', ['site_user']),
        grant('site-user', ['list']),
        grant('member', ['operator']),
        grant('member', ['list']),
        grant('member', ['admin'], type: 'group'),
        grant('agent', ['admin'], type: 'agent'),
      ];
      final summaries = summarizeRoomGrants(reversed ? policy.reversed : policy);
      expect(summaries.keys, unorderedEquals(['jesse', 'site-user', 'member']));
      expect(summaries['jesse']!.role, GrantRole.owner);
      expect(summaries['site-user']!.role, GrantRole.siteUser);
      expect(summaries['member']!.role, GrantRole.nonOwner);
    });
  }

  test('updated policy can downgrade a previously displayed owner', () {
    final policy = [
      ProjectRoomGrant(
        resource: const AccessResource(type: 'room', id: 'pirates'),
        subject: const AccessSubject(type: 'user', id: 'jesse'),
        directRoles: const ['operator'],
      ),
      ProjectRoomGrant(
        resource: const AccessResource(type: 'room', id: 'pirates'),
        subject: const AccessSubject(type: 'user', id: 'jesse'),
        directRoles: const ['list'],
      ),
    ];
    expect(summarizeRoomGrants(policy)['jesse']!.role, GrantRole.nonOwner);
  });
}
