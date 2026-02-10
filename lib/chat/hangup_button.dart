import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:powerboards/nav/nav.dart';

import 'package:powerboards/livekit/room.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/ui/wake_lock.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HangupButton extends StatelessWidget {
  const HangupButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final room = VideoRoomModel.maybeOf(context)?.room;

    if (room == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        return switch (room.connectionState) {
          livekit.ConnectionState.connected => WakeLock(
            child: RoomToolbarButton(
              text: "Hangup",
              on: false,
              onColor: ShadTheme.of(context).colorScheme.foreground,
              onForeground: ShadTheme.of(context).colorScheme.background,
              offColor: Colors.red,
              offForeground: Colors.white,
              icon: LucideIcons.phone,
              onPressed: () {
                context.findAncestorStateOfType<VideoChatConnectionState>()!.hangup();
                final navController = Controller.ofType<NavController>(context);
                navController.showNav();
                if (onPressed != null) {
                  onPressed!();
                }
              },
            ),
          ),
          _ => RoomToolbarButton(
            text: "Connecting",
            on: false,
            onColor: ShadTheme.of(context).colorScheme.foreground,
            onForeground: ShadTheme.of(context).colorScheme.background,

            offColor: Colors.red,
            offForeground: Colors.white,
            icon: LucideIcons.phone,
            onPressed: onPressed,
          ),
        };
      },
    );
  }
}
