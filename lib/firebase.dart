import 'package:flutter/foundation.dart';

export 'package:powerboards/firebase/options.dart';

const bool powerboardsFirebaseEnabled = kReleaseMode || bool.fromEnvironment("FIREBASE_INITIALIZE");

bool get powerboardsSupportsNativeFirebase {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => false,
  };
}
