import 'package:meshagent_flutter_auth/shared_profiles.dart';

import 'package:powerboards/meshagent/meshagent.dart';

export 'package:meshagent_flutter_auth/shared_profiles.dart';

Future<SharedProfile?> applySharedProfileConfigIfSupported({bool? supported, Future<SharedProfile?> Function()? loadActiveProfile}) async {
  return null;
}

Future<SharedProfile?> hydrateSharedProfileAuthIfSupported({bool? supported, Future<SharedProfile?> Function()? hydrateProfile}) async {
  return null;
}

Future<SharedProfile?> hydratePowerboardsAuthFromSharedProfile() async {
  return null;
}

Future<SharedProfile?> activateSharedProfileForPowerboards(String userId, {required MeshagentConfig baseConfig}) async {
  return null;
}

Future<void> syncPowerboardsAuthToSharedProfile({String? activeProject}) async {}

Future<void> syncPowerboardsAuthToSharedProfileSettingsFile({required Object file, String? activeProject}) async {}
