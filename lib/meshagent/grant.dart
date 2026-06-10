import 'package:collection/collection.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/meshagent.dart';

enum GrantRole {
  owner,
  nonOwner;

  String get displayName {
    switch (this) {
      case GrantRole.owner:
        return 'Owner';
      case GrantRole.nonOwner:
        return 'Member';
    }
  }

  ApiScope get apiScope {
    switch (this) {
      case GrantRole.owner:
        return ApiScope.full();
      case GrantRole.nonOwner:
        return ApiScope.userDefault();
    }
  }

  static GrantRole fromGrant(ProjectRoomGrant grant) {
    return grant.permissions.admin == null ? GrantRole.nonOwner : GrantRole.owner;
  }
}

class GrantSummary {
  const GrantSummary({required this.userId, required this.role});

  factory GrantSummary.fromGrant(ProjectRoomGrant grant) => GrantSummary(userId: grant.userId, role: GrantRole.fromGrant(grant));

  final String userId;
  final GrantRole role;
}

bool isMe(String userId) {
  final me = MeshagentAuth.current.getUser();
  return me?['id'] == userId;
}

Future<List<ProjectRoomGrant>> listRoomGrants({required String projectId, required String roomId}) async {
  final client = getMeshagentClient();
  return client.getResourcePolicy(projectId: projectId, resourceType: 'room', resourceId: roomId);
}

Future<ProjectRoomGrant?> myGrantForRoom({required String projectId, required String roomId}) async {
  final grants = await listRoomGrants(projectId: projectId, roomId: roomId);
  return grants.firstWhereOrNull((g) => g.subject.type == 'user' && isMe(g.subject.id));
}

Future<bool> amIOwnerOfRoom({required RoomClient room}) async {
  return room.apiGrant?.admin != null;
}

Future<Map<String, GrantSummary>> roomGrantSummaries({required String projectId, required String roomId}) async {
  final grants = await listRoomGrants(projectId: projectId, roomId: roomId);
  return {for (final g in grants.where((grant) => grant.subject.type == 'user')) g.subject.id: GrantSummary.fromGrant(g)};
}

Future<bool> canViewDeveloperLogs({required RoomClient room}) async {
  return room.apiGrant?.developer?.logs == true;
}

Future<bool> canViewStorage({required RoomClient room}) async {
  return room.apiGrant?.storage != null;
}
