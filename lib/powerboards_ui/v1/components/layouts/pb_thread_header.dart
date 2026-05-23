import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../menus/pb_menu_anchor.dart';
import '../menus/pb_switcher_menu.dart';
import '../primitives/pb_svg_icon.dart';

class PbThreadHeader extends StatefulWidget {
  const PbThreadHeader({
    super.key,
    this.title = 'Launch planning',
    this.agentName = 'Assistant',
    this.threads = const ['Launch planning'],
    this.selectedThreadTitle,
    this.onThreadSelected,
    this.onCreateThread,
    this.roomPanelExpanded = true,
    this.onTitlePressed,
    this.onRoomPanelToggle,
    this.onOpenAllAgentsAndThreads,
  });

  final String title;
  final String agentName;
  final List<String> threads;
  final String? selectedThreadTitle;
  final ValueChanged<String>? onThreadSelected;
  final VoidCallback? onCreateThread;
  final bool roomPanelExpanded;
  final VoidCallback? onTitlePressed;
  final VoidCallback? onRoomPanelToggle;
  final VoidCallback? onOpenAllAgentsAndThreads;

  @override
  State<PbThreadHeader> createState() => _PbThreadHeaderState();
}

class _PbThreadHeaderState extends State<PbThreadHeader> {
  static const int _defaultVisibleThreadCount = 6;

  final TextEditingController _filterController = TextEditingController();
  bool _threadMenuOpen = false;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  String get _selectedThreadTitle => widget.selectedThreadTitle ?? widget.title;

  void _toggleThreadMenu() {
    setState(() => _threadMenuOpen = !_threadMenuOpen);
    widget.onTitlePressed?.call();
  }

  void _closeThreadMenu() {
    if (!_threadMenuOpen) {
      return;
    }

    setState(() => _threadMenuOpen = false);
  }

  void _setThreadFilter(String value) => setState(() {});

  void _clearThreadFilter() {
    _filterController.clear();
    setState(() {});
  }

  void _selectThread(String thread) {
    _filterController.clear();
    widget.onThreadSelected?.call(thread);
    setState(() => _threadMenuOpen = false);
  }

  void _createThread() {
    _filterController.clear();
    widget.onCreateThread?.call();
    setState(() => _threadMenuOpen = false);
  }

  Widget _buildThreadMenu() {
    final query = _filterController.text.trim().toLowerCase();
    final filtering = query.isNotEmpty;
    final filteredThreads = widget.threads.where((thread) => !filtering || thread.toLowerCase().contains(query)).toList();
    final visibleThreads = filtering ? filteredThreads : filteredThreads.take(_defaultVisibleThreadCount).toList();

    return PbSwitcherMenu(
      width: 240,
      filterController: _filterController,
      onFilterChanged: _setThreadFilter,
      items: [for (final thread in visibleThreads) PbSwitcherMenuItem(title: thread, selected: thread == _selectedThreadTitle)],
      emptyLabel: 'No matching threads',
      actionLabel: filtering ? 'Clear results' : 'New Thread',
      actionLeadingIconAssetName: 'plus',
      actionLeadingIconTurns: filtering ? -0.125 : 0,
      onActionPressed: filtering ? _clearThreadFilter : _createThread,
      onItemPressed: _selectThread,
    );
  }

  @override
  Widget build(BuildContext context) {
    final threadTitleButton = PbMenuAnchor(
      panel: _threadMenuOpen ? _buildThreadMenu() : null,
      gap: 10,
      triggerHeight: 38,
      onDismiss: _closeThreadMenu,
      child: _ThreadTitleButton(title: _selectedThreadTitle, selected: _threadMenuOpen, onPressed: _toggleThreadMenu),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(30, 27, 28, 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 560;
          final titleGroup = _ThreadTitleGroup(titleButton: threadTitleButton, agentName: widget.agentName, stacked: stacked);
          final actions = _ThreadHeaderActions(
            roomPanelExpanded: widget.roomPanelExpanded,
            onRoomPanelToggle: widget.onRoomPanelToggle,
            onOpenAllAgentsAndThreads: widget.onOpenAllAgentsAndThreads,
          );

          if (stacked) {
            return SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleGroup),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 38,
                    child: Align(alignment: Alignment.topRight, child: actions),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              Expanded(child: titleGroup),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ThreadTitleGroup extends StatelessWidget {
  const _ThreadTitleGroup({required this.titleButton, required this.agentName, required this.stacked});

  final Widget titleButton;
  final String agentName;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final meta = _ThreadMeta(agentName: agentName);

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [titleButton, const SizedBox(height: 6), meta],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: titleButton),
        const SizedBox(width: 20),
        Flexible(child: meta),
      ],
    );
  }
}

class _ThreadTitleButton extends StatefulWidget {
  const _ThreadTitleButton({required this.title, this.selected = false, this.onPressed});

  final String title;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<_ThreadTitleButton> createState() => _ThreadTitleButtonState();
}

class _ThreadTitleButtonState extends State<_ThreadTitleButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final lifted = _hovered && !_pressed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.ease,
          transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 38),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: PowerboardsTypography.h2),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: widget.selected ? -0.5 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: const PbSvgIcon(assetName: 'chevron-down', size: 15, color: PbColors.customBrandInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadMeta extends StatelessWidget {
  const _ThreadMeta({required this.agentName});

  final String agentName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Thread with $agentName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: PowerboardsTypography.meta.copyWith(color: PbColors.textMuted),
          ),
        ),
        const SizedBox(width: 7),
        const _ThreadAgentPill(),
      ],
    );
  }
}

class _ThreadAgentPill extends StatelessWidget {
  const _ThreadAgentPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: PbColors.surfaceAccentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PbColors.customStateSelectedBorder),
      ),
      child: Transform.translate(
        offset: const Offset(0, -1),
        child: Text(
          'Agent',
          style: PowerboardsTypography.badge.copyWith(color: PbColors.surfaceRailActive, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ThreadHeaderActions extends StatelessWidget {
  const _ThreadHeaderActions({required this.roomPanelExpanded, this.onRoomPanelToggle, this.onOpenAllAgentsAndThreads});

  final bool roomPanelExpanded;
  final VoidCallback? onRoomPanelToggle;
  final VoidCallback? onOpenAllAgentsAndThreads;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!roomPanelExpanded) _ThreadHeaderQuaternaryButton(label: 'All agents & threads', onPressed: onOpenAllAgentsAndThreads),
        if (!roomPanelExpanded) const SizedBox(width: 6),
        _ThreadPanelToggle(expanded: roomPanelExpanded, onPressed: onRoomPanelToggle),
      ],
    );
  }
}

class _ThreadHeaderQuaternaryButton extends StatefulWidget {
  const _ThreadHeaderQuaternaryButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_ThreadHeaderQuaternaryButton> createState() => _ThreadHeaderQuaternaryButtonState();
}

class _ThreadHeaderQuaternaryButtonState extends State<_ThreadHeaderQuaternaryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.ease,
          transform: Matrix4.translationValues(0, _hovered && !_pressed ? -1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 28),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: PowerboardsTypography.badge.copyWith(
              fontWeight: FontWeight.w800,
              color: _hovered ? Color.lerp(PbColors.surfaceRailActive, PbColors.customBlue, 0.18) : PbColors.surfaceRailActive,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadPanelToggle extends StatefulWidget {
  const _ThreadPanelToggle({required this.expanded, this.onPressed});

  final bool expanded;
  final VoidCallback? onPressed;

  @override
  State<_ThreadPanelToggle> createState() => _ThreadPanelToggleState();
}

class _ThreadPanelToggleState extends State<_ThreadPanelToggle> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _pressed ? 0.96 : 1,
              child: PbSvgIcon(
                assetName: widget.expanded ? 'panel-right-close' : 'panel-right-open',
                size: 18,
                color: PbColors.customBrandInk.withValues(alpha: active ? 1 : 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
