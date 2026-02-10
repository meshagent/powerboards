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

Future<List<ProjectRoomGrant>> listRoomGrants({required String projectId, required String roomName}) async {
  final client = getMeshagentClient();
  return client.listRoomGrantsByRoom(projectId: projectId, roomName: roomName);
}

Future<ProjectRoomGrant?> myGrantForRoom({required String projectId, required String roomName}) async {
  final grants = await listRoomGrants(projectId: projectId, roomName: roomName);
  return grants.firstWhereOrNull((g) => isMe(g.userId));
}

Future<bool> amIOwnerOfRoom({required String projectId, required String roomName}) async {
  final myGrant = await myGrantForRoom(projectId: projectId, roomName: roomName);
  return myGrant != null && GrantRole.fromGrant(myGrant) == GrantRole.owner;
}

Future<Map<String, GrantSummary>> roomGrantSummaries({required String projectId, required String roomName}) async {
  final grants = await listRoomGrants(projectId: projectId, roomName: roomName);
  return {for (final g in grants) g.userId: GrantSummary.fromGrant(g)};
}

Future<bool> canViewDeveloperLogs({required String projectId, required String roomName, required String userId}) async {
  final client = getMeshagentClient();
  final grants = await client.listRoomGrantsByUser(projectId: projectId, userId: userId);
  final grantForRoom = grants.cast<ProjectRoomGrant?>().firstWhere((g) => g?.room.name == roomName, orElse: () => null);
  final developer = grantForRoom?.permissions.developer;

  return developer?.logs == true;
}

Future<bool> canViewStorage({required String projectId, required String roomName, required String userId}) async {
  final client = getMeshagentClient();
  final grants = await client.listRoomGrantsByUser(projectId: projectId, userId: userId);
  final grantForRoom = grants.cast<ProjectRoomGrant?>().firstWhere((g) => g?.room.name == roomName, orElse: () => null);
  return grantForRoom?.permissions.storage != null;
}
