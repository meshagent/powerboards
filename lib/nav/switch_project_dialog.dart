import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:powerboards/meshagent/project.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SwitchProjectDialog extends StatelessWidget {
  const SwitchProjectDialog({
    super.key,
    required this.currentProjectId,
    required this.projects,
    required this.onSwitch,
    required this.onNewProject,
  });

  final String currentProjectId;
  final Resource<List<Project>> projects;
  final void Function(Project) onSwitch;
  final VoidCallback onNewProject;

  Widget _buildProjectItem(BuildContext context, Project project) {
    return ShadButton.ghost(
      mainAxisAlignment: MainAxisAlignment.start,
      trailing: project.id == currentProjectId ? const Icon(Icons.check, size: 16) : null,
      onPressed: project.id == currentProjectId
          ? null
          : () {
              Navigator.of(context).pop();
              onSwitch(project);
            },
      child: Text(project.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('Switch Project'),
      description: const Text('Select a project to switch to:'),
      actions: [
        ShadButton.outline(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ShadButton(
          leading: const Icon(LucideIcons.packagePlus),
          onPressed: () {
            Navigator.of(context).pop();
            onNewProject();
          },
          child: const Text('New Project'),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 300),
        child: SignalBuilder(
          builder: (context, _) {
            final items = projects.state.value;

            if (items == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items
                  .map((project) {
                    return _buildProjectItem(context, project);
                  })
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }
}
