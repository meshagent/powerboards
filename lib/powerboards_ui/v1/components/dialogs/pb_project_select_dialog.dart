import 'package:flutter/material.dart';

import 'pb_dialog_shell.dart';
import '../menus/pb_menu_filter_field.dart';
import '../menus/pb_menu_list.dart';
import '../menus/pb_menu_option.dart';
import '../primitives/pb_button.dart';

class PbProjectSelectDialog extends StatefulWidget {
  const PbProjectSelectDialog({
    super.key,
    required this.projects,
    required this.selectedProject,
    required this.filterController,
    required this.onFilterChanged,
    required this.onProjectSelected,
    required this.onCreateProjectPressed,
    required this.onClose,
  });

  final List<String> projects;
  final String selectedProject;
  final TextEditingController filterController;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onProjectSelected;
  final VoidCallback onCreateProjectPressed;
  final VoidCallback onClose;

  @override
  State<PbProjectSelectDialog> createState() => _PbProjectSelectDialogState();
}

class _PbProjectSelectDialogState extends State<PbProjectSelectDialog> {
  static const double _selectedRevealInset = 16;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollRegionKey = GlobalKey();
  final Map<String, GlobalKey> _projectKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProjects = widget.projects.where((project) {
      final query = widget.filterController.text.trim().toLowerCase();
      return query.isEmpty || project.toLowerCase().contains(query);
    }).toList();

    _scheduleSelectedProjectReveal(filteredProjects);

    return PbDialogShell(
      title: 'Switch Project',
      description: 'Select a project to switch to:',
      onClose: widget.onClose,
      minHeight: 600,
      expandBody: true,
      actions: [
        PbButton(label: 'Cancel', variant: PbButtonVariant.secondary, onPressed: widget.onClose),
        PbButton(label: 'New Project', variant: PbButtonVariant.primary, onPressed: widget.onCreateProjectPressed),
      ],
      child: Column(
        children: [
          PbMenuFilterField(controller: widget.filterController, onChanged: widget.onFilterChanged),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              key: _scrollRegionKey,
              controller: _scrollController,
              primary: false,
              padding: const EdgeInsets.only(right: 4),
              child: PbMenuList(
                children: filteredProjects.isEmpty
                    ? const [PbMenuOption(title: 'No matching projects', singleLine: true, state: PbMenuOptionVisualState.disabled)]
                    : [
                        for (final project in filteredProjects)
                          KeyedSubtree(
                            key: _keyForProject(project),
                            child: PbMenuOption(
                              title: project,
                              singleLine: true,
                              selected: project == widget.selectedProject,
                              selectedSurface: project == widget.selectedProject,
                              trailingIconAssetName: project == widget.selectedProject ? 'circle-check-big' : null,
                              onPressed: () => widget.onProjectSelected(project),
                            ),
                          ),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  GlobalKey _keyForProject(String project) {
    return _projectKeys.putIfAbsent(project, GlobalKey.new);
  }

  void _scheduleSelectedProjectReveal(List<String> visibleProjects) {
    if (!visibleProjects.contains(widget.selectedProject)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final context = _projectKeys[widget.selectedProject]?.currentContext;

      if (context == null) {
        return;
      }

      final scrollRegionContext = _scrollRegionKey.currentContext;
      final selectedBox = context.findRenderObject();
      final scrollRegionBox = scrollRegionContext?.findRenderObject();

      if (selectedBox is! RenderBox || scrollRegionBox is! RenderBox) {
        return;
      }

      final selectedOffset = selectedBox.localToGlobal(Offset.zero);
      final scrollRegionOffset = scrollRegionBox.localToGlobal(Offset.zero);
      final selectedTop = selectedOffset.dy;
      final selectedBottom = selectedTop + selectedBox.size.height;
      final topEdge = scrollRegionOffset.dy + _selectedRevealInset;
      final bottomEdge = scrollRegionOffset.dy + scrollRegionBox.size.height - _selectedRevealInset;

      if (selectedTop < topEdge) {
        _scrollController.jumpTo((_scrollController.offset + selectedTop - topEdge).clamp(0.0, _scrollController.position.maxScrollExtent));
        return;
      }

      if (selectedBottom > bottomEdge) {
        _scrollController.jumpTo(
          (_scrollController.offset + selectedBottom - bottomEdge).clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }
}
