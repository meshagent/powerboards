import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoomEndedCard extends StatelessWidget {
  const RoomEndedCard({super.key, required this.onReconnect});

  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The room ended', style: TextStyle(fontSize: 18)),
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
