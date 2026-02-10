import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';

class LogoutCard extends StatelessWidget {
  const LogoutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      title: const Text('You are signed out'),
      description: const Text('Thank you for using MeshAgent'),
      padding: const EdgeInsets.all(20),
      rowMainAxisAlignment: MainAxisAlignment.center,
      rowCrossAxisAlignment: CrossAxisAlignment.center,
      columnMainAxisAlignment: MainAxisAlignment.center,
      columnCrossAxisAlignment: CrossAxisAlignment.center,
      child: Column(
        spacing: 10,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10),
          Text('You will need to sign back in to access your account.'),
          ShadButton(
            onPressed: () {
              context.go('/');
            },
            child: Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
