import 'dart:io';

import 'package:meshagent_flutter_auth/shared_profiles_io.dart' as shared;

import 'package:powerboards/meshagent/meshagent.dart';

export 'package:meshagent_flutter_auth/shared_profiles.dart';

Future<shared.SharedProfile?> applySharedProfileConfigIfSupported({
  bool? supported,
  Future<shared.SharedProfile?> Function()? loadActiveProfile,
}) async {
  if (!(supported ?? shared.isSharedProfilesSupported)) {
    return null;
  }

  final activeProfile = await (loadActiveProfile ?? shared.loadActiveSharedProfile)();
  final apiUrl = activeProfile?.apiUrl;
  if (apiUrl == null || apiUrl.isEmpty || MeshagentConfig.current == null) {
    return activeProfile;
  }

  MeshagentConfig.current = MeshagentConfig.current!.withApiUrlOverride(apiUrl);
  return activeProfile;
}

Future<shared.SharedProfile?> hydrateSharedProfileAuthIfSupported({
  bool? supported,
  Future<shared.SharedProfile?> Function()? hydrateProfile,
}) async {
  if (!(supported ?? shared.isSharedProfilesSupported)) {
    return null;
  }

  return (hydrateProfile ?? hydratePowerboardsAuthFromSharedProfile)();
}

Future<shared.SharedProfile?> hydratePowerboardsAuthFromSharedProfile() async {
  return shared.hydrateCurrentAuthFromActiveSharedProfile();
}

Future<shared.SharedProfile?> activateSharedProfileForPowerboards(String userId, {required MeshagentConfig baseConfig}) async {
  final selected = await shared.setActiveSharedProfileInFile(file: shared.sharedProfilesSettingsFile(), userId: userId);
  final apiUrl = selected.apiUrl;
  if (apiUrl != null && apiUrl.isNotEmpty) {
    MeshagentConfig.current = await baseConfig.withApiUrlOverride(apiUrl).withDeploymentConfig();
  }
  await hydratePowerboardsAuthFromSharedProfile();
  return selected;
}

Future<void> syncPowerboardsAuthToSharedProfile({String? activeProject}) async {
  if (!shared.isSharedProfilesSupported) {
    return;
  }

  await syncPowerboardsAuthToSharedProfileSettingsFile(file: shared.sharedProfilesSettingsFile(), activeProject: activeProject);
}

Future<void> syncPowerboardsAuthToSharedProfileSettingsFile({required File file, String? activeProject}) async {
  await shared.syncCurrentAuthToSharedProfileFile(
    file: file,
    apiUrl: MeshagentConfig.current?.serverUrl.toString(),
    activeProject: activeProject,
  );
}
