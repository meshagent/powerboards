import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:powerboards/meshagent/project.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> showSwitchProjectDialog({
  required BuildContext context,
  required String currentProjectId,
  required Resource<List<Project>> projects,
  required void Function(Project) onSwitch,
  required VoidCallback onNewProject,
}) {
  projects.refresh();

  return showShadDialog<void>(
    context: context,
    builder: (context) =>
        SwitchProjectDialog(currentProjectId: currentProjectId, projects: projects, onSwitch: onSwitch, onNewProject: onNewProject),
  );
}

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
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
        child: SignalBuilder(
          builder: (context, _) {
            final items = projects.state.value;

            if (items == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: items
                      .map((project) {
                        return _buildProjectItem(context, project);
                      })
                      .toList(growable: false),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
