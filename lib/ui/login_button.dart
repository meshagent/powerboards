import 'package:flutter/material.dart';
import 'package:meshagent/client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProviderButton extends StatelessWidget {
  final AuthProvider provider;
  final void Function(String provider) signIn;

  const ProviderButton({super.key, required this.provider, required this.signIn});

  void _onPressed() {
    signIn(provider.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;

    return ShadButton.outline(
      width: 240.0,
      height: 40.0,
      onPressed: _onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      mainAxisAlignment: MainAxisAlignment.start,
      gap: 12.0,
      leading: SizedBox(width: 22.0, height: 22.0, child: SvgPicture.string(provider.svgLogo)),
      child: Text(provider.label, style: tt.small.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
