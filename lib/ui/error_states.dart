import 'package:flutter/material.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/powerboards_back_icon_button.dart';

class NotFound extends StatelessWidget {
  const NotFound({super.key, required this.uri});
  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: powerboardsMobileScreenSafeAreaMinimum,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: powerboardsMobileShellHorizontalInset, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PowerboardsBackIconButton(onPressed: () => context.go("/")),
            Expanded(
              child: Center(child: Text(textAlign: TextAlign.center, "Not Found $uri")),
            ),
          ],
        ),
      ),
    );
  }
}
