import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoomEndedCard extends StatelessWidget {
  const RoomEndedCard({super.key, required this.onReconnect, required this.title, this.description});

  final VoidCallback onReconnect;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.h4, textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description!, style: theme.textTheme.muted, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onReconnect,
            child: Text('Reconnect', style: TextStyle(color: cs.primaryForeground)),
          ),
        ],
      ),
    );
  }
}
