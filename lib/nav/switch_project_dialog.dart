import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:powerboards/meshagent/project.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

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

  List<Widget> _buildProjectItems(BuildContext context, List<Project> items) {
    final children = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final project = items[i];
      children.add(
        _ProjectListItem(
          key: ValueKey(project.id),
          name: project.name,
          selected: project.id == currentProjectId,
          onTap: project.id == currentProjectId
              ? null
              : () {
                  Navigator.of(context).pop();
                  onSwitch(project);
                },
        ),
      );

      if (i != items.length - 1) {
        children.add(const ShadSeparator.horizontal(margin: EdgeInsets.zero));
      }
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    return PowerboardsShadDialog.listPicker(
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
      child: Padding(
        padding: powerboardsDialogScrollableListPadding,
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
                    children: _buildProjectItems(context, items),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProjectListItem extends StatefulWidget {
  const _ProjectListItem({super.key, required this.name, required this.selected, required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ProjectListItem> createState() => _ProjectListItemState();
}

class _ProjectListItemState extends State<_ProjectListItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final fontWeight = widget.selected || _hovered ? FontWeight.w700 : FontWeight.w400;

    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(inherit: true, fontWeight: fontWeight, color: theme.colorScheme.foreground),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: widget.selected ? Icon(LucideIcons.check, size: 18, color: theme.colorScheme.foreground) : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
