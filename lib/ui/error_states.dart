import 'package:flutter/material.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NotFound extends StatelessWidget {
  const NotFound({super.key, required this.uri});
  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: "Back",
              child: ShadIconButton.ghost(
                icon: Icon(LucideIcons.arrowLeft),
                onPressed: () async {
                  context.go("/");
                },
              ),
            ),
            Expanded(
              child: Center(child: Text(textAlign: TextAlign.center, "Not Found $uri")),
            ),
          ],
        ),
      ),
    );
  }
}
