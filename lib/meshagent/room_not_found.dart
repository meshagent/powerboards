import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';

class RoomNotFound extends StatelessWidget {
  const RoomNotFound({super.key});

  Widget _inner(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final projectId = localStorage.getItem("lastProjectId");

    return ShadCard(
      padding: const EdgeInsets.all(32.0),
      rowMainAxisAlignment: MainAxisAlignment.center,
      columnCrossAxisAlignment: CrossAxisAlignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16.0,
        children: [
          Text("Room Not Accessible", style: tt.h3),
          Text(
            "This room either doesn’t exist or you don’t have permissions to view it. "
            "Please check the link or contact the room owner for access.",
            textAlign: TextAlign.center,
          ),
          if (projectId != null)
            ShadButton(
              onPressed: () {
                context.go("/p/${fromUUID(projectId)}");
              },
              child: const Text("Go Back Home"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    if (isMobile) {
      return SafeArea(
        child: Padding(padding: const EdgeInsets.all(32.0), child: _inner(context)),
      );
    }

    return Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560.0), child: _inner(context)),
    );
  }
}
