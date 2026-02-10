import 'package:flutter/material.dart';

class RoomEndedCard extends StatelessWidget {
  const RoomEndedCard({super.key, required this.onReconnect});

  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        // color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The room ended', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onReconnect,
            child: const Text('Reconnect', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
