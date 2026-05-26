import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../menus/pb_menu_filter_field.dart';
import '../menus/pb_menu_list.dart';
import '../menus/pb_menu_option.dart';
import '../primitives/pb_button.dart';
import '../primitives/pb_svg_icon.dart';

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
  static const double _overlayBlur = 14;
  static const double _overlayAlpha = 0.52;
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
    final viewport = MediaQuery.sizeOf(context);
    final dialogMaxHeight = math.min(700.0, viewport.height - 120);
    final filteredProjects = widget.projects.where((project) {
      final query = widget.filterController.text.trim().toLowerCase();
      return query.isEmpty || project.toLowerCase().contains(query);
    }).toList();

    _scheduleSelectedProjectReveal(filteredProjects);

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: _overlayBlur, sigmaY: _overlayBlur),
              child: Container(color: PbColors.surfaceRailActive.withValues(alpha: _overlayAlpha)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 425, maxHeight: dialogMaxHeight),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 600),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: PbColors.borderSoft),
                    gradient: const LinearGradient(
                      colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.08), blurRadius: 80, offset: Offset(0, 30))],
                  ),
                  child: Column(
                    children: [
                      _DialogHeader(onClose: widget.onClose),
                      const SizedBox(height: 24),
                      Expanded(
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
                                      ? const [
                                          PbMenuOption(
                                            title: 'No matching projects',
                                            singleLine: true,
                                            state: PbMenuOptionVisualState.disabled,
                                          ),
                                        ]
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
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: PbButton(label: 'Cancel', variant: PbButtonVariant.secondary, onPressed: widget.onClose),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PbButton(
                              label: 'New Project',
                              variant: PbButtonVariant.primary,
                              onPressed: widget.onCreateProjectPressed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Switch Project', style: PowerboardsTypography.h2),
              const SizedBox(height: 8),
              Text('Select a project to switch to:', style: PowerboardsTypography.meta.copyWith(color: PbColors.textMuted)),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(6, -6),
          child: _DialogCloseButton(onPressed: onClose),
        ),
      ],
    );
  }
}

class _DialogCloseButton extends StatefulWidget {
  const _DialogCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_DialogCloseButton> createState() => _DialogCloseButtonState();
}

class _DialogCloseButtonState extends State<_DialogCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.all(Radius.circular(10))),
          alignment: Alignment.center,
          child: Opacity(
            opacity: _hovered ? 1 : 0.3,
            child: PbSvgIcon(assetName: 'x', size: 18, color: PbColors.textMuted),
          ),
        ),
      ),
    );
  }
}
