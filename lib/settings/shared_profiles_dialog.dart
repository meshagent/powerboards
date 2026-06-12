import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent_flutter_auth/shared_profile_switcher_dialog.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/shared_profiles.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

typedef PowerboardsSharedProfileActivator = Future<SharedProfile?> Function(String userId, {required MeshagentConfig baseConfig});
typedef PowerboardsSharedProfilesLoader = Future<SharedProfileSettingsSnapshot> Function();

Future<void> showPowerboardsSharedProfilesDialog(
  BuildContext context, {
  PowerboardsSharedProfilesLoader? loadProfiles,
  PowerboardsSharedProfileActivator? activateProfile,
}) {
  return showPowerboardsAlertDialog<void>(
    context: context,
    builder: (dialogContext) => SharedProfileSwitcherDialog(
      loadProfiles: loadProfiles ?? loadSharedProfileSettings,
      activateProfile: (profile) async {
        final preservedUiMode = powerboardsUiModeSignal.value;
        final activator = activateProfile ?? activateSharedProfileForPowerboards;
        await activator(profile.userId, baseConfig: MeshagentConfig.current!);
        setPowerboardsUiMode(preservedUiMode);
      },
      onProfileActivated: (profileContext, profile) {
        localStorage.removeItem("lastProjectId");
        profileContext.go("/");
      },
    ),
  );
}
