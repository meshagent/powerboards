import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/client.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/ui/error_states.dart';

class AdminOnly extends StatefulWidget {
  const AdminOnly({super.key, required this.projectId, required this.uri, required this.child});

  final String projectId;
  final Uri? uri;
  final Widget child;

  @override
  State<AdminOnly> createState() => _AdminOnlyState();
}

class _AdminOnlyState extends State<AdminOnly> {
  late final Resource<ProjectRole?> _role;

  @override
  void initState() {
    super.initState();

    _role = Resource<ProjectRole?>(() async {
      final client = getMeshagentClient();
      return await client.getProjectRole(widget.projectId);
    });
  }

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminOnly oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      _role.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final state = _role.state;

        if (!state.isReady) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.hasError && !state.isRefreshing) {
          return NotFound(uri: widget.uri);
        }

        final role = state.value;
        if (role != ProjectRole.admin) {
          return NotFound(uri: widget.uri);
        }

        return widget.child;
      },
    );
  }
}
