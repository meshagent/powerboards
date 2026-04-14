import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

bool powerboardsUsesSystemAdaptiveTextSelectionToolbar() {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };
}

Widget powerboardsAdaptiveInputContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
  if (powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return AdaptiveTextSelectionToolbar.editableText(editableTextState: editableTextState);
  }

  return ShadInputState.defaultContextMenuBuilder(context, editableTextState);
}

TapRegionCallback? powerboardsAdaptiveInputOnPressedOutside() {
  if (!powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return null;
  }

  return (_) => FocusManager.instance.primaryFocus?.unfocus();
}
