import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';

import 'package:powerboards/nav/add_room_dialog.dart';
import 'package:powerboards/nav/new_project_dialog.dart';

import 'slug.dart';

bool isSupportedServiceType(ServiceSpec service) {
  final type = service.agents.firstOrNull?.annotations["meshagent.agent.type"];
  final widget = service.agents.firstOrNull?.annotations["meshagent.agent.widget"];
  return widget != null || type == "ChatBot" || type == "VoiceBot" || type == "MeetingTranscriber" || type == "Shell";
}

bool hasMessagingParticipant(ServiceSpec service) {
  final type = service.agents.firstOrNull?.annotations["meshagent.agent.type"];
  return type == "ChatBot" || type == "VoiceBot";
}

class MeshagentConfig {
  MeshagentConfig({
    required this.serverUrl,
    required this.appUrl,
    required this.billingUrl,
    required this.oauthCallbackUrl,
    required this.oauthClientId,
    required this.imageTagPrefix,
    required this.domains,
  });

  final Uri serverUrl;
  final Uri appUrl;
  final Uri billingUrl;
  final Uri oauthCallbackUrl;
  final String oauthClientId;
  final String imageTagPrefix;
  final List<String> domains;

  Uri getWsUrl(String roomName) {
    final scheme = serverUrl.scheme == "http" ? "ws" : "wss";

    return serverUrl.replace(scheme: scheme, path: "/rooms/$roomName");
  }

  factory MeshagentConfig.fromEnvironment() {
    final domains = _parseEnvList(const String.fromEnvironment("DOMAINS"));
    if (kIsWeb) {
      return MeshagentConfig(
        serverUrl: Uri.parse(const String.fromEnvironment("SERVER_URL")),
        appUrl: Uri.parse(const String.fromEnvironment("APP_URL")),
        oauthCallbackUrl: Uri.parse(const String.fromEnvironment("OAUTH_CALLBACK_URL")),
        oauthClientId: const String.fromEnvironment("OAUTH_CLIENT_ID"),
        billingUrl: Uri.parse(const String.fromEnvironment("BILLING_URL")),
        imageTagPrefix: const String.fromEnvironment("IMAGE_TAG_PREFIX"),
        domains: domains,
      );
    }

    return MeshagentConfig(
      serverUrl: Uri.parse(const String.fromEnvironment("SERVER_URL")),
      appUrl: Uri.parse(const String.fromEnvironment("APP_URL")),
      oauthCallbackUrl: Uri.parse(const String.fromEnvironment("OAUTH_MOBILE_CALLBACK_URL")),
      oauthClientId: const String.fromEnvironment("OAUTH_MOBILE_CLIENT_ID"),
      billingUrl: Uri.parse(const String.fromEnvironment("BILLING_URL")),
      imageTagPrefix: const String.fromEnvironment("IMAGE_TAG_PREFIX"),
      domains: domains,
    );
  }

  static MeshagentConfig? current;
}

List<String> _parseEnvList(String raw) {
  return raw.split(",").map((entry) => entry.trim()).where((entry) => entry.isNotEmpty).toList();
}

Meshagent getMeshagentClient() {
  final token = MeshagentAuth.current.getAccessToken();
  final serverUrl = MeshagentConfig.current?.serverUrl;
  final oauthClientId = MeshagentConfig.current?.oauthClientId;

  if (token == null) {
    throw Exception("No access token - you are not logged in");
  }

  if (serverUrl == null) {
    throw Exception("No base URL - you are not logged in");
  }

  if (oauthClientId == null) {
    throw Exception("No OAuth Client ID - you are not logged in");
  }

  return Meshagent.withTokenProvider(
    baseUrl: serverUrl.toString(),
    token: token,
    tokenProvider: RefreshAccessTokenProvider(oauthClientId: oauthClientId, serverUrl: serverUrl),
  );
}

Future<Room?> createMeshagentRoom(BuildContext context, String projectId) async {
  final res = await showRoomNameDialog(context);

  if (!context.mounted) return null;
  if (res == null) return null; // user cancelled

  final client = getMeshagentClient();
  final user = MeshagentAuth.current.getUser();

  if (user == null) {
    await showRoomCreationErrorDialog(context, MeshagentException("No user - you are not logged in"));
    return null;
  }

  final userId = user["id"];
  final existingSlugs = <String>{};
  const maxAttempts = 10;
  var attempt = 0;

  while (attempt < maxAttempts) {
    final slug = generateRoomSlug(res.name, existingSlugs: existingSlugs);

    try {
      return await client.createRoom(
        projectId: projectId,
        name: slug,
        metadata: {"displayName": res.name},
        permissions: {userId: res.owner ? ApiScope.full() : ApiScope.userDefault()},
      );
    } on NameInUseException catch (e) {
      existingSlugs.add(slug);
      attempt++;

      if (attempt >= maxAttempts) {
        if (!context.mounted) return null;
        await showRoomCreationErrorDialog(context, e);
        return null;
      }
    } catch (e) {
      if (!context.mounted) return null;
      await showRoomCreationErrorDialog(context, e);
      return null;
    }
  }

  return null;
}

Future<Map<String, dynamic>?> createMeshagentProject(BuildContext context) async {
  final projectName = await showNewProjectDialog(context);

  if (projectName != null) {
    final client = getMeshagentClient();

    return client.createProject(projectName);
  }

  return null;
}

Future<List<Room>> listMeshagentRooms(String projectId) async {
  final client = getMeshagentClient();
  final grants = await client.listRoomGrantsByUser(projectId: projectId, userId: "me");

  return grants.map((g) => g.room).toList();
}

Map<String, dynamic> getMeUser() {
  final user = MeshagentAuth.current.getUser();

  if (user == null) {
    throw Exception("No user - you are not logged in");
  }

  return user;
}

Future<List<AuthProvider>> listMeshagentOAuthProviders() async {
  final baseUrl = MeshagentConfig.current?.serverUrl;
  final client = Meshagent(baseUrl: baseUrl.toString(), token: '');
  final providers = await client.listOAuthProviders();

  return providers;
}

Future<bool> isBalanceLow(String? projectId) async {
  final client = getMeshagentClient();

  if (projectId == null) {
    return false;
  }

  final enabled = await client.getStatus(projectId);

  return !enabled;
}
