import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';

import 'package:powerboards/nav/add_room_dialog.dart';
import 'package:powerboards/nav/new_project_dialog.dart';
import 'slug.dart';

const meshagentDeploymentConfigFetchTimeout = Duration(seconds: 5);

bool hasAgentMetadata(ServiceSpec service) => service.agents.isNotEmpty;

String? serviceAgentType(ServiceSpec service) => service.agents.firstOrNull?.annotations["meshagent.agent.type"];

String? serviceTemplateAgentType(ServiceTemplateSpec template) => template.agents.firstOrNull?.annotations["meshagent.agent.type"];

bool serviceUsesVoiceAgent(ServiceSpec service) => serviceAgentType(service) == "VoiceBot";

bool serviceTemplateUsesVoiceAgent(ServiceTemplateSpec template) => serviceTemplateAgentType(template) == "VoiceBot";

bool isSupportedServiceType(ServiceSpec service) {
  final type = serviceAgentType(service);
  return type == "ChatBot" || type == "VoiceBot" || type == "MeetingTranscriber" || type == "Shell";
}

bool hasMessagingParticipant(ServiceSpec service) {
  final type = serviceAgentType(service);
  return type == "ChatBot" || type == "VoiceBot";
}

Future<bool> testCurrentUserProjectRole(String projectId, ProjectRole role) async {
  final client = getMeshagentClient();
  return (await client.testAccess(
    projectId: projectId,
    subject: const AccessSubject(type: 'user', id: 'me'),
    resource: AccessResource(type: 'project', id: projectId),
    relation: role.relation,
  )).allowed;
}

class MeshagentConfig {
  MeshagentConfig({
    required this.serverUrl,
    required this.appUrl,
    required this.billingUrl,
    required this.oauthCallbackUrl,
    required this.oauthClientId,
    required this.sentryEnabled,
    required this.sentryDsn,
    required this.sentryRelease,
    required this.sentryEnvironment,
    required this.imageTagPrefix,
    required this.domains,
    required this.meshagentMailDomain,
    this.registryHost,
  });

  final Uri serverUrl;
  final Uri appUrl;
  final Uri billingUrl;
  final Uri oauthCallbackUrl;
  final String oauthClientId;
  final bool sentryEnabled;
  final String sentryDsn;
  final String sentryRelease;
  final String sentryEnvironment;
  final String imageTagPrefix;
  final List<String> domains;
  final String meshagentMailDomain;
  final String? registryHost;

  Uri get oauth2CallbackUrl => oauthCallbackUrl.replace(path: "/oauth2/callback");

  MeshagentConfig copyWith({
    Uri? serverUrl,
    Uri? appUrl,
    Uri? billingUrl,
    Uri? oauthCallbackUrl,
    String? oauthClientId,
    bool? sentryEnabled,
    String? sentryDsn,
    String? sentryRelease,
    String? sentryEnvironment,
    String? imageTagPrefix,
    List<String>? domains,
    String? meshagentMailDomain,
    Object? registryHost = _unchanged,
  }) {
    return MeshagentConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      appUrl: appUrl ?? this.appUrl,
      billingUrl: billingUrl ?? this.billingUrl,
      oauthCallbackUrl: oauthCallbackUrl ?? this.oauthCallbackUrl,
      oauthClientId: oauthClientId ?? this.oauthClientId,
      sentryEnabled: sentryEnabled ?? this.sentryEnabled,
      sentryDsn: sentryDsn ?? this.sentryDsn,
      sentryRelease: sentryRelease ?? this.sentryRelease,
      sentryEnvironment: sentryEnvironment ?? this.sentryEnvironment,
      imageTagPrefix: imageTagPrefix ?? this.imageTagPrefix,
      domains: domains ?? this.domains,
      meshagentMailDomain: meshagentMailDomain ?? this.meshagentMailDomain,
      registryHost: identical(registryHost, _unchanged) ? this.registryHost : registryHost as String?,
    );
  }

  MeshagentConfig withApiUrlOverride(String apiUrl) {
    final normalizedApiUrl = _normalizeUrl(apiUrl);
    final serverUri = Uri.parse(normalizedApiUrl);
    return copyWith(serverUrl: serverUri);
  }

  Future<MeshagentConfig> withDeploymentConfig({http.Client? client}) async {
    final deploymentConfig = await _fetchDeploymentConfig(serverUrl: serverUrl, client: client);

    return copyWith(
      serverUrl: deploymentConfig.apiUrl ?? serverUrl,
      appUrl: deploymentConfig.powerboardsUrl ?? appUrl,
      billingUrl: deploymentConfig.accountsUrl ?? billingUrl,
      domains: deploymentConfig.pagesDomain == null ? domains : [deploymentConfig.pagesDomain!],
      meshagentMailDomain: deploymentConfig.mailDomain ?? meshagentMailDomain,
      registryHost: deploymentConfig.registryHost ?? registryHost,
    );
  }

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
        sentryEnabled: const bool.fromEnvironment("SENTRY_ENABLED", defaultValue: false),
        sentryDsn: const String.fromEnvironment("SENTRY_DSN"),
        sentryRelease: const String.fromEnvironment("SENTRY_RELEASE"),
        sentryEnvironment: const String.fromEnvironment("SENTRY_ENVIRONMENT"),
        imageTagPrefix: const String.fromEnvironment("IMAGE_TAG_PREFIX"),
        domains: domains,
        meshagentMailDomain: const String.fromEnvironment("MESHAGENT_MAIL_DOMAIN"),
      );
    }

    return MeshagentConfig(
      serverUrl: Uri.parse(const String.fromEnvironment("SERVER_URL")),
      appUrl: Uri.parse(const String.fromEnvironment("APP_URL")),
      oauthCallbackUrl: Uri.parse(const String.fromEnvironment("OAUTH_MOBILE_CALLBACK_URL")),
      oauthClientId: const String.fromEnvironment("OAUTH_MOBILE_CLIENT_ID"),
      billingUrl: Uri.parse(const String.fromEnvironment("BILLING_URL")),
      sentryEnabled: const bool.fromEnvironment("SENTRY_ENABLED", defaultValue: false),
      sentryDsn: const String.fromEnvironment("SENTRY_DSN"),
      sentryRelease: const String.fromEnvironment("SENTRY_RELEASE"),
      sentryEnvironment: const String.fromEnvironment("SENTRY_ENVIRONMENT"),
      imageTagPrefix: const String.fromEnvironment("IMAGE_TAG_PREFIX"),
      domains: domains,
      meshagentMailDomain: const String.fromEnvironment("MESHAGENT_MAIL_DOMAIN"),
    );
  }

  static Future<MeshagentConfig> fromUri(Uri uri) async {
    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    return MeshagentConfig(
      serverUrl: Uri.parse(data["SERVER_URL"]),
      appUrl: Uri.parse(data["APP_URL"]),
      oauthCallbackUrl: Uri.parse(data["OAUTH_CALLBACK_URL"]),
      oauthClientId: data["OAUTH_CLIENT_ID"],
      billingUrl: Uri.parse(data["BILLING_URL"]),
      sentryEnabled: _parseEnvBool(data["SENTRY_ENABLED"]),
      sentryDsn: data["SENTRY_DSN"] ?? "",
      sentryRelease: data["SENTRY_RELEASE"] ?? "",
      sentryEnvironment: data["SENTRY_ENVIRONMENT"] ?? "",
      imageTagPrefix: data["IMAGE_TAG_PREFIX"],
      domains: _parseEnvList(data["DOMAINS"]),
      meshagentMailDomain: data["MESHAGENT_MAIL_DOMAIN"],
    );
  }

  static MeshagentConfig? current;

  static Future<_DeploymentConfig> _fetchDeploymentConfig({required Uri serverUrl, http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(serverUrl.replace(path: '/config')).timeout(meshagentDeploymentConfigFetchTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _DeploymentConfig();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const _DeploymentConfig();
      }

      final domains = decoded['domains'];
      if (domains is! Map<String, dynamic>) {
        return const _DeploymentConfig();
      }

      final accounts = domains['accounts'];
      final api = domains['api'];
      final mail = domains['mail'];
      final pages = domains['pages'];
      final powerboards = domains['powerboards'];
      final registry = domains['registry'];

      return _DeploymentConfig(
        accountsUrl: accounts is String && accounts.trim().isNotEmpty ? _httpsUrlForDomain(accounts.trim()) : null,
        apiUrl: api is String && api.trim().isNotEmpty ? _httpsUrlForDomain(api.trim()) : null,
        mailDomain: mail is String && mail.trim().isNotEmpty ? mail.trim() : null,
        pagesDomain: pages is String && pages.trim().isNotEmpty ? pages.trim() : null,
        powerboardsUrl: powerboards is String && powerboards.trim().isNotEmpty ? _httpsUrlForDomain(powerboards.trim()) : null,
        registryHost: registry is String && registry.trim().isNotEmpty ? registry.trim() : null,
      );
    } catch (_) {
      return const _DeploymentConfig();
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}

class _DeploymentConfig {
  const _DeploymentConfig({this.accountsUrl, this.apiUrl, this.mailDomain, this.pagesDomain, this.powerboardsUrl, this.registryHost});

  final Uri? accountsUrl;
  final Uri? apiUrl;
  final String? mailDomain;
  final String? pagesDomain;
  final Uri? powerboardsUrl;
  final String? registryHost;
}

const _unchanged = Object();

List<String> _parseEnvList(String raw) {
  return raw.split(",").map((entry) => entry.trim()).where((entry) => entry.isNotEmpty).toList();
}

bool _parseEnvBool(dynamic raw) {
  if (raw is bool) {
    return raw;
  }

  return raw.toString().toLowerCase() == "true";
}

String _normalizeUrl(String url) {
  final normalized = url.trim();
  if (normalized.endsWith("/")) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

Uri _httpsUrlForDomain(String domain) {
  if (domain.startsWith('http://') || domain.startsWith('https://')) {
    return Uri.parse(domain);
  }
  return Uri.parse('https://$domain');
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

Future<Room?> createMeshagentRoom(BuildContext context, String projectId, {ValueChanged<String>? onCreateStarted}) async {
  final res = await showRoomNameDialog(context);

  if (!context.mounted) return null;
  if (res == null) return null; // user cancelled

  onCreateStarted?.call(res.name);

  final client = getMeshagentClient();
  final user = MeshagentAuth.current.getUser();

  if (user == null) {
    await showRoomCreationErrorDialog(context, MeshagentException("No user - you are not logged in"));
    return null;
  }
  final existingSlugs = <String>{};
  const maxAttempts = 10;
  var attempt = 0;

  while (attempt < maxAttempts) {
    final slug = generateRoomSlug(res.name, existingSlugs: existingSlugs);

    try {
      return await client.createRoom(projectId: projectId, name: slug, metadata: {"displayName": res.name});
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

const int _roomPageSize = 100;

typedef RoomPageLoader = Future<RoomsPage> Function(int limit, int offset);
typedef RoomCursorPageLoader = Future<RoomsPage> Function(int limit, String? continuationToken);

@visibleForTesting
Future<List<Room>> collectMeshagentRoomsFromGrantPages(RoomPageLoader loadPage, {int pageSize = _roomPageSize}) async {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Must be greater than zero.');
  }

  final roomsByName = <String, Room>{};
  var offset = 0;

  while (true) {
    final page = await loadPage(pageSize, offset);

    for (final room in page.rooms) {
      roomsByName.putIfAbsent(room.name, () => room);
    }

    // Keep paging until the server returns a short page; the reported total
    // has not always been enough to trust as the lone termination condition.
    if (page.rooms.length < pageSize) {
      return roomsByName.values.toList(growable: false);
    }

    offset += page.rooms.length;
  }
}

@visibleForTesting
Future<List<Room>> collectMeshagentRoomsFromPermissionPages(RoomCursorPageLoader loadPage, {int pageSize = _roomPageSize}) async {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Must be greater than zero.');
  }

  final roomsByName = <String, Room>{};
  String? continuationToken;
  do {
    final page = await loadPage(pageSize, continuationToken);
    for (final room in page.rooms) {
      roomsByName.putIfAbsent(room.name, () => room);
    }
    continuationToken = page.continuationToken;
  } while (continuationToken != null);

  return roomsByName.values.toList(growable: false)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

Future<List<Room>> listMeshagentRooms(String projectId) async {
  final client = getMeshagentClient();
  return collectMeshagentRoomsFromPermissionPages((limit, continuationToken) {
    return client.listRoomsPage(projectId: projectId, pageSize: limit, view: 'my', continuationToken: continuationToken);
  });
}

Future<bool> waitForMeshagentRoomConnectionReady(
  String projectId,
  String roomName, {
  Duration timeout = const Duration(seconds: 12),
  Duration retryInterval = const Duration(milliseconds: 600),
}) async {
  final client = getMeshagentClient();
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    try {
      await client.connectRoom(projectId: projectId, roomName: roomName);
      return true;
    } catch (_) {
      if (DateTime.now().isAfter(deadline)) {
        break;
      }

      await Future.delayed(retryInterval);
    }
  }

  return false;
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
