import 'package:flutter/material.dart';

import '../../models/pb_attachment_file_metadata.dart';
import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../menus/pb_menu_anchor.dart';
import '../menus/pb_menu_card.dart';
import '../menus/pb_menu_list.dart';
import '../menus/pb_menu_option.dart';
import '../primitives/pb_button.dart';
import '../primitives/pb_svg_icon.dart';

enum PbRoomPanelTab { agents, files }

enum PbAgentStatusTone { online, amber, gray, error }

const double _sidepaneInlinePadding = 22;
const double _sidepaneScrollTopPadding = 8;
const double _sidepaneListTopHoverClearance = 2;
const double _sidepaneScrollBottomPadding = 24;
const double _sidepaneDescriptionToListGap = 20;
const double _sidepaneListToActionsGap = 20;
const double _sidepaneActionsHeight = 36;
const double _sidepaneActionsToDividerGap = 30;
const double _sidepaneDescriptionHeight = 14 * 1.4;
const double _sidepaneDividerMaxHeightFactor = 0.5;
const int _agentListScrollThreshold = 3;
const double _agentCardMinHeight = 70;
const double _agentListGap = 10;

class PbRoomPanel extends StatefulWidget {
  const PbRoomPanel({
    super.key,
    this.initialTab = PbRoomPanelTab.agents,
    this.selectedTab,
    this.onTabSelected,
    this.onFilePreviewOpenChanged,
    this.onFilePreviewFullscreenChanged,
    this.agents,
    this.selectedAgentId,
    this.selectedAgentTitle,
    this.onAgentSelected,
    this.onAgentItemSelected,
    this.onManageAgents,
    this.attachments,
    required this.threads,
    this.threadItems,
    this.selectedThreadId,
    required this.selectedThreadTitle,
    required this.onThreadSelected,
    this.onThreadItemSelected,
    this.onThreadRename,
    this.onThreadDelete,
    required this.onCreateThread,
    this.filePreviewResizing = false,
  });

  final PbRoomPanelTab initialTab;
  final PbRoomPanelTab? selectedTab;
  final ValueChanged<PbRoomPanelTab>? onTabSelected;
  final ValueChanged<bool>? onFilePreviewOpenChanged;
  final ValueChanged<bool>? onFilePreviewFullscreenChanged;
  final List<PbAgentListItemData>? agents;
  final String? selectedAgentId;
  final String? selectedAgentTitle;
  final ValueChanged<String>? onAgentSelected;
  final ValueChanged<PbAgentListItemData>? onAgentItemSelected;
  final VoidCallback? onManageAgents;
  final List<PbAttachmentListItemData>? attachments;
  final List<String> threads;
  final List<PbThreadListItemData>? threadItems;
  final String? selectedThreadId;
  final String? selectedThreadTitle;
  final ValueChanged<String> onThreadSelected;
  final ValueChanged<PbThreadListItemData>? onThreadItemSelected;
  final ValueChanged<PbThreadListItemData>? onThreadRename;
  final ValueChanged<PbThreadListItemData>? onThreadDelete;
  final VoidCallback onCreateThread;
  final bool filePreviewResizing;

  @override
  State<PbRoomPanel> createState() => _PbRoomPanelState();
}

class _PbRoomPanelState extends State<PbRoomPanel> {
  late PbRoomPanelTab _selectedTab = widget.initialTab;
  bool _filePreviewOpen = false;
  bool _filePreviewFullscreen = false;
  PbAttachmentListItemData _previewFile = const PbAttachmentListItemData(
    title: 'File name.ext',
    subtitle: 'Type',
    fileType: PbAttachmentFileType.generic,
  );

  static const _agents = [
    PbAgentListItemData(title: 'Assistant', status: 'Connected', icon: 'bot', selected: true),
    PbAgentListItemData(title: 'Research', status: 'Connecting...', icon: 'search', statusTone: PbAgentStatusTone.amber),
    PbAgentListItemData(title: 'Builder', status: 'Not connected...', icon: 'pencil-ruler', statusTone: PbAgentStatusTone.gray),
    PbAgentListItemData(title: 'Coordinator', status: 'Connected', icon: 'messages-square'),
  ];

  static const _attachments = [
    PbAttachmentListItemData(title: 'File name.ext', subtitle: 'Type', fileType: PbAttachmentFileType.generic),
    PbAttachmentListItemData(title: 'May 12 notes', subtitle: 'Meeting note', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Q2 roadmap.pdf', subtitle: 'PDF', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Agent handoff.md', subtitle: 'Markdown', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Design review.mov', subtitle: 'Video', fileType: PbAttachmentFileType.video),
    PbAttachmentListItemData(title: 'Spec comments.txt', subtitle: 'Text', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Ops checklist.csv', subtitle: 'Spreadsheet', fileType: PbAttachmentFileType.spreadsheet),
    PbAttachmentListItemData(title: 'Launch screenshots.zip', subtitle: 'Archive', fileType: PbAttachmentFileType.archive),
    PbAttachmentListItemData(title: 'Stakeholder summary.docx', subtitle: 'Document', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Weekly sync.m4a', subtitle: 'Audio', fileType: PbAttachmentFileType.sound),
    PbAttachmentListItemData(title: 'Data export.json', subtitle: 'JSON', fileType: PbAttachmentFileType.code),
    PbAttachmentListItemData(title: 'Partner brief.key', subtitle: 'Presentation', fileType: PbAttachmentFileType.presentation),
    PbAttachmentListItemData(title: 'Budget model.xlsx', subtitle: 'Spreadsheet', fileType: PbAttachmentFileType.spreadsheet),
    PbAttachmentListItemData(title: 'API contract.yaml', subtitle: 'YAML', fileType: PbAttachmentFileType.code),
    PbAttachmentListItemData(title: 'Field notes.pages', subtitle: 'Document', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Board export.png', subtitle: 'Image', fileType: PbAttachmentFileType.image),
    PbAttachmentListItemData(title: 'Legal approval.pdf', subtitle: 'PDF', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Agent matrix.numbers', subtitle: 'Spreadsheet', fileType: PbAttachmentFileType.spreadsheet),
    PbAttachmentListItemData(title: 'QA pass checklist.md', subtitle: 'Markdown', fileType: PbAttachmentFileType.document),
    PbAttachmentListItemData(title: 'Transcript.srt', subtitle: 'Captions', fileType: PbAttachmentFileType.transcript),
    PbAttachmentListItemData(title: 'Training deck.pptx', subtitle: 'Presentation', fileType: PbAttachmentFileType.presentation),
    PbAttachmentListItemData(title: 'Release notes.rtf', subtitle: 'Rich text', fileType: PbAttachmentFileType.document),
  ];

  PbRoomPanelTab get _activeTab => widget.selectedTab ?? _selectedTab;

  @override
  void didUpdateWidget(covariant PbRoomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedTab != null && widget.selectedTab != oldWidget.selectedTab) {
      _selectedTab = widget.selectedTab!;
    }
  }

  void _selectTab(PbRoomPanelTab tab) {
    if (widget.selectedTab == null) {
      setState(() => _selectedTab = tab);
    }

    widget.onTabSelected?.call(tab);
  }

  void _openFilePreview(PbAttachmentListItemData file) {
    setState(() {
      _previewFile = file;
      _filePreviewOpen = true;
      _filePreviewFullscreen = false;
    });
    widget.onFilePreviewOpenChanged?.call(true);
    widget.onFilePreviewFullscreenChanged?.call(false);
  }

  void _setFilePreviewFullscreen(bool fullscreen) {
    setState(() => _filePreviewFullscreen = fullscreen);
    widget.onFilePreviewFullscreenChanged?.call(fullscreen);
  }

  void _closeFilePreview() {
    setState(() {
      _filePreviewOpen = false;
      _filePreviewFullscreen = false;
    });
    widget.onFilePreviewOpenChanged?.call(false);
    widget.onFilePreviewFullscreenChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: _filePreviewOpen ? 0 : 1,
          child: IgnorePointer(
            ignoring: _filePreviewOpen,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.fromLTRB(_sidepaneInlinePadding, 36, _sidepaneInlinePadding, 0),
              decoration: const BoxDecoration(
                color: PbColors.surfacePanelWash,
                border: Border(left: BorderSide(color: PbColors.borderSoft)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PbRoomTabs(selectedTab: _activeTab, onTabSelected: _selectTab),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _activeTab == PbRoomPanelTab.agents
                        ? _AgentsPanel(
                            agents: widget.agents ?? _agents,
                            threads: widget.threads,
                            threadItems: widget.threadItems,
                            selectedAgentId: widget.selectedAgentId,
                            selectedAgentTitle: widget.selectedAgentTitle,
                            onAgentSelected: widget.onAgentSelected,
                            onAgentItemSelected: widget.onAgentItemSelected,
                            onManageAgents: widget.onManageAgents,
                            selectedThreadId: widget.selectedThreadId,
                            selectedThreadTitle: widget.selectedThreadTitle,
                            onThreadSelected: widget.onThreadSelected,
                            onThreadItemSelected: widget.onThreadItemSelected,
                            onThreadRename: widget.onThreadRename,
                            onThreadDelete: widget.onThreadDelete,
                            onCreateThread: widget.onCreateThread,
                          )
                        : _FilesPanel(attachments: widget.attachments ?? _attachments, onPreviewFile: _openFilePreview),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_filePreviewOpen)
          Positioned.fill(
            child: PbFilePreviewPane(
              file: _previewFile,
              fullscreen: _filePreviewFullscreen,
              resizing: widget.filePreviewResizing,
              onToggleFullscreen: () => _setFilePreviewFullscreen(!_filePreviewFullscreen),
              onClose: _closeFilePreview,
            ),
          ),
      ],
    );
  }
}

class PbRoomTabs extends StatefulWidget {
  const PbRoomTabs({super.key, required this.selectedTab, required this.onTabSelected});

  final PbRoomPanelTab selectedTab;
  final ValueChanged<PbRoomPanelTab> onTabSelected;

  @override
  State<PbRoomTabs> createState() => _PbRoomTabsState();
}

class _PbRoomTabsState extends State<PbRoomTabs> {
  PbRoomPanelTab? _hoveredTab;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomLeft,
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: PbColors.borderSoft)),
            ),
          ),
          Row(
            children: [
              _RoomTab(
                label: 'Agents',
                selected: widget.selectedTab == PbRoomPanelTab.agents,
                hovered: _hoveredTab == PbRoomPanelTab.agents,
                selectedSuppressed: _hoveredTab != null && _hoveredTab != PbRoomPanelTab.agents,
                onHoverChanged: (hovered) => setState(() => _hoveredTab = hovered ? PbRoomPanelTab.agents : null),
                onPressed: () => widget.onTabSelected(PbRoomPanelTab.agents),
              ),
              const SizedBox(width: 24),
              _RoomTab(
                label: 'Files',
                selected: widget.selectedTab == PbRoomPanelTab.files,
                hovered: _hoveredTab == PbRoomPanelTab.files,
                selectedSuppressed: _hoveredTab != null && _hoveredTab != PbRoomPanelTab.files,
                onHoverChanged: (hovered) => setState(() => _hoveredTab = hovered ? PbRoomPanelTab.files : null),
                onPressed: () => widget.onTabSelected(PbRoomPanelTab.files),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomTab extends StatelessWidget {
  const _RoomTab({
    required this.label,
    required this.selected,
    required this.hovered,
    required this.selectedSuppressed,
    required this.onHoverChanged,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool hovered;
  final bool selectedSuppressed;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final showUnderline = hovered || (selected && !selectedSuppressed);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(label, style: PowerboardsTypography.label.copyWith(color: selected ? PbColors.textPrimary : PbColors.textMuted)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 3,
                transform: Matrix4.diagonal3Values(showUnderline ? 1 : 0.82, 1, 1),
                decoration: BoxDecoration(
                  color: showUnderline ? PbColors.customBrandInk : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentsPanel extends StatefulWidget {
  const _AgentsPanel({
    required this.agents,
    required this.threads,
    this.threadItems,
    this.selectedAgentId,
    this.selectedAgentTitle,
    this.onAgentSelected,
    this.onAgentItemSelected,
    this.onManageAgents,
    this.selectedThreadId,
    required this.selectedThreadTitle,
    required this.onThreadSelected,
    this.onThreadItemSelected,
    this.onThreadRename,
    this.onThreadDelete,
    required this.onCreateThread,
  });

  final List<PbAgentListItemData> agents;
  final List<String> threads;
  final List<PbThreadListItemData>? threadItems;
  final String? selectedAgentId;
  final String? selectedAgentTitle;
  final ValueChanged<String>? onAgentSelected;
  final ValueChanged<PbAgentListItemData>? onAgentItemSelected;
  final VoidCallback? onManageAgents;
  final String? selectedThreadId;
  final String? selectedThreadTitle;
  final ValueChanged<String> onThreadSelected;
  final ValueChanged<PbThreadListItemData>? onThreadItemSelected;
  final ValueChanged<PbThreadListItemData>? onThreadRename;
  final ValueChanged<PbThreadListItemData>? onThreadDelete;
  final VoidCallback onCreateThread;

  @override
  State<_AgentsPanel> createState() => _AgentsPanelState();
}

class _AgentsPanelState extends State<_AgentsPanel> {
  bool _agentsExpanded = true;
  late String _selectedAgentKey = _initialSelectedAgentKey();

  String _initialSelectedAgentKey() {
    final selectedId = widget.selectedAgentId;
    if (selectedId != null) {
      for (final agent in widget.agents) {
        if (agent.id == selectedId) {
          return agent.identity;
        }
      }
    }

    final selectedTitle = widget.selectedAgentTitle;
    if (selectedTitle != null) {
      for (final agent in widget.agents) {
        if (agent.title == selectedTitle) {
          return agent.identity;
        }
      }
    }

    if (widget.agents.isEmpty) {
      return '';
    }

    return widget.agents.firstWhere((agent) => agent.selected, orElse: () => widget.agents.first).identity;
  }

  @override
  void didUpdateWidget(covariant _AgentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selectedId = widget.selectedAgentId;
    if (selectedId != null) {
      for (final agent in widget.agents) {
        if (agent.id == selectedId && agent.identity != _selectedAgentKey) {
          _selectedAgentKey = agent.identity;
          break;
        }
      }
    } else {
      final selectedTitle = widget.selectedAgentTitle;
      if (selectedTitle != null) {
        for (final agent in widget.agents) {
          if (agent.title == selectedTitle) {
            if (agent.identity != _selectedAgentKey) {
              _selectedAgentKey = agent.identity;
            }
            break;
          }
        }
      }
    }

    if (!widget.agents.any((agent) => agent.identity == _selectedAgentKey) && widget.agents.isNotEmpty) {
      _selectedAgentKey = widget.agents.first.identity;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.agents.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedAgent = widget.agents.firstWhere((agent) => agent.identity == _selectedAgentKey, orElse: () => widget.agents.first);
    final visibleAgents = _agentsExpanded ? widget.agents : [selectedAgent];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxHeight < 520;
        final fixedSection = _AgentsFixedSection(
          agents: visibleAgents,
          selectedAgentKey: _selectedAgentKey,
          expanded: _agentsExpanded,
          canToggleExpanded: widget.agents.length > 1,
          panelHeight: constraints.maxHeight,
          compactLayout: compactLayout,
          onManageAgents: widget.onManageAgents,
          onAgentSelected: (agent) {
            setState(() => _selectedAgentKey = agent.identity);
            widget.onAgentSelected?.call(agent.title);
            widget.onAgentItemSelected?.call(agent);
          },
          onToggleExpanded: () => setState(() => _agentsExpanded = !_agentsExpanded),
        );
        final threadsSection = _ThreadsSection(
          threads: widget.threads,
          threadItems: widget.threadItems,
          selectedThreadId: widget.selectedThreadId,
          selectedThread: widget.selectedThreadTitle,
          compactLayout: compactLayout,
          onCreateThread: widget.onCreateThread,
          onThreadSelected: widget.onThreadSelected,
          onThreadItemSelected: widget.onThreadItemSelected,
          onThreadRename: widget.onThreadRename,
          onThreadDelete: widget.onThreadDelete,
        );

        if (compactLayout) {
          return ListView(padding: EdgeInsets.zero, children: [fixedSection, const SizedBox(height: 30), threadsSection]);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fixedSection,
            const SizedBox(height: 30),
            Expanded(child: threadsSection),
          ],
        );
      },
    );
  }
}

class _RoomPanelDescription extends StatelessWidget {
  const _RoomPanelDescription(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: PowerboardsTypography.meta.copyWith(color: PbColors.textMuted));
  }
}

class _AgentsFixedSection extends StatelessWidget {
  const _AgentsFixedSection({
    required this.agents,
    required this.selectedAgentKey,
    required this.expanded,
    required this.canToggleExpanded,
    required this.panelHeight,
    required this.compactLayout,
    this.onManageAgents,
    required this.onAgentSelected,
    required this.onToggleExpanded,
  });

  final List<PbAgentListItemData> agents;
  final String selectedAgentKey;
  final bool expanded;
  final bool canToggleExpanded;
  final double panelHeight;
  final bool compactLayout;
  final VoidCallback? onManageAgents;
  final ValueChanged<PbAgentListItemData> onAgentSelected;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RoomPanelDescription('Browse threads by selected agent.'),
        SizedBox(height: _sidepaneDescriptionToListGap + (compactLayout ? _sidepaneListTopHoverClearance : 0)),
        _AgentGroup(
          agents: agents,
          selectedAgentKey: selectedAgentKey,
          expanded: expanded,
          panelHeight: panelHeight,
          onAgentSelected: onAgentSelected,
        ),
        const SizedBox(height: _sidepaneListToActionsGap),
        _AgentActions(
          expanded: expanded,
          canToggleExpanded: canToggleExpanded,
          onManageAgents: onManageAgents,
          onToggleExpanded: onToggleExpanded,
        ),
        const SizedBox(height: _sidepaneActionsToDividerGap),
        const Divider(height: 1, thickness: 1, color: PbColors.borderSoft),
      ],
    );
  }
}

class _AgentGroup extends StatefulWidget {
  const _AgentGroup({
    required this.agents,
    required this.selectedAgentKey,
    required this.expanded,
    required this.panelHeight,
    required this.onAgentSelected,
  });

  final List<PbAgentListItemData> agents;
  final String selectedAgentKey;
  final bool expanded;
  final double panelHeight;
  final ValueChanged<PbAgentListItemData> onAgentSelected;

  @override
  State<_AgentGroup> createState() => _AgentGroupState();
}

class _AgentGroupState extends State<_AgentGroup> {
  static const double _selectedRevealInset = 12;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollRegionKey = GlobalKey();
  final Map<String, GlobalKey> _agentKeys = {};
  String? _lastRevealSignature;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.expanded) {
      _lastRevealSignature = null;
      return _AgentList(agents: widget.agents, selectedAgentKey: widget.selectedAgentKey, onAgentSelected: widget.onAgentSelected);
    }

    final contentHeight = _agentListHeight(widget.agents.length);
    final maxHeight = _agentListMaxHeight(widget.panelHeight);

    if (widget.agents.length <= _agentListScrollThreshold || contentHeight <= maxHeight) {
      _lastRevealSignature = null;
      return _AgentList(agents: widget.agents, selectedAgentKey: widget.selectedAgentKey, onAgentSelected: widget.onAgentSelected);
    }

    _scheduleSelectedAgentReveal();

    return SizedBox(
      height: maxHeight,
      child: _SidepaneScrollViewport.separated(
        controller: _scrollController,
        viewportKey: _scrollRegionKey,
        itemCount: widget.agents.length,
        gap: _agentListGap,
        expand: false,
        topPadding: _sidepaneListTopHoverClearance,
        itemBuilder: (context, index) {
          final agent = widget.agents[index];

          return KeyedSubtree(
            key: _keyForAgent(agent.identity),
            child: PbAgentCard(
              data: agent.copyWith(selected: agent.identity == widget.selectedAgentKey),
              onPressed: () => widget.onAgentSelected(agent),
            ),
          );
        },
      ),
    );
  }

  GlobalKey _keyForAgent(String title) {
    return _agentKeys.putIfAbsent(title, GlobalKey.new);
  }

  void _scheduleSelectedAgentReveal() {
    final selectedIndex = widget.agents.indexWhere((agent) => agent.identity == widget.selectedAgentKey);
    if (selectedIndex == -1) {
      _lastRevealSignature = null;
      return;
    }

    final revealSignature = '${widget.selectedAgentKey}:${widget.agents.length}:${widget.expanded}';
    if (_lastRevealSignature == revealSignature) {
      return;
    }
    _lastRevealSignature = revealSignature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      if (!_revealBuiltSelectedAgent(widget.selectedAgentKey)) {
        _jumpToEstimatedSelectedAgent(selectedIndex);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _revealBuiltSelectedAgent(widget.selectedAgentKey);
          }
        });
      }
    });
  }

  bool _revealBuiltSelectedAgent(String selectedKey) {
    final context = _agentKeys[selectedKey]?.currentContext;
    final scrollRegionContext = _scrollRegionKey.currentContext;

    if (context == null || scrollRegionContext == null) {
      return false;
    }

    final selectedBox = context.findRenderObject();
    final scrollRegionBox = scrollRegionContext.findRenderObject();

    if (selectedBox is! RenderBox || scrollRegionBox is! RenderBox) {
      return false;
    }

    final selectedOffset = selectedBox.localToGlobal(Offset.zero);
    final scrollRegionOffset = scrollRegionBox.localToGlobal(Offset.zero);
    final selectedTop = selectedOffset.dy;
    final selectedBottom = selectedTop + selectedBox.size.height;
    final topEdge = scrollRegionOffset.dy + _selectedRevealInset;
    final bottomEdge = scrollRegionOffset.dy + scrollRegionBox.size.height - _selectedRevealInset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    if (selectedTop < topEdge) {
      _scrollController.jumpTo((_scrollController.offset + selectedTop - topEdge).clamp(0, maxScrollExtent));
      return true;
    }

    if (selectedBottom > bottomEdge) {
      _scrollController.jumpTo((_scrollController.offset + selectedBottom - bottomEdge).clamp(0, maxScrollExtent));
    }

    return true;
  }

  void _jumpToEstimatedSelectedAgent(int selectedIndex) {
    final scrollRegionContext = _scrollRegionKey.currentContext;
    final scrollRegionBox = scrollRegionContext?.findRenderObject();
    if (scrollRegionBox is! RenderBox) {
      return;
    }

    final selectedTop = _sidepaneListTopHoverClearance + (selectedIndex * (_agentCardMinHeight + _agentListGap));
    final selectedBottom = selectedTop + _agentCardMinHeight;
    final visibleTop = _scrollController.offset + _selectedRevealInset;
    final visibleBottom = _scrollController.offset + scrollRegionBox.size.height - _selectedRevealInset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    if (selectedTop < visibleTop) {
      _scrollController.jumpTo((selectedTop - _selectedRevealInset).clamp(0, maxScrollExtent));
      return;
    }

    if (selectedBottom > visibleBottom) {
      _scrollController.jumpTo((selectedBottom - scrollRegionBox.size.height + _selectedRevealInset).clamp(0, maxScrollExtent));
    }
  }

  double _agentListHeight(int count) {
    if (count <= 0) {
      return 0;
    }

    return _sidepaneListTopHoverClearance + (_agentCardMinHeight * count) + (_agentListGap * (count - 1));
  }

  double _agentListMaxHeight(double panelHeight) {
    final dividerTarget = panelHeight * _sidepaneDividerMaxHeightFactor;
    const fixedHeightBeforeDivider =
        _sidepaneDescriptionHeight +
        _sidepaneDescriptionToListGap +
        _sidepaneListToActionsGap +
        _sidepaneActionsHeight +
        _sidepaneActionsToDividerGap;
    final minimumScrollableHeight = _agentListHeight(_agentListScrollThreshold);

    return (dividerTarget - fixedHeightBeforeDivider).clamp(minimumScrollableHeight, double.infinity);
  }
}

class _AgentList extends StatelessWidget {
  const _AgentList({required this.agents, required this.selectedAgentKey, required this.onAgentSelected});

  final List<PbAgentListItemData> agents;
  final String selectedAgentKey;
  final ValueChanged<PbAgentListItemData> onAgentSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: _sidepaneListTopHoverClearance),
        child: Column(
          children: [
            for (var i = 0; i < agents.length; i++) ...[
              PbAgentCard(
                data: agents[i].copyWith(selected: agents[i].identity == selectedAgentKey),
                onPressed: () => onAgentSelected(agents[i]),
              ),
              if (i != agents.length - 1) const SizedBox(height: _agentListGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentActions extends StatelessWidget {
  const _AgentActions({required this.expanded, required this.canToggleExpanded, this.onManageAgents, required this.onToggleExpanded});

  final bool expanded;
  final bool canToggleExpanded;
  final VoidCallback? onManageAgents;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        PbTertiaryButton.solid(label: 'Manage', onPressed: onManageAgents),
        if (canToggleExpanded) PbTertiaryButton(label: expanded ? 'Show less' : 'Show more', onPressed: onToggleExpanded),
      ],
    );
  }
}

class _ThreadsSection extends StatefulWidget {
  const _ThreadsSection({
    required this.threads,
    this.threadItems,
    this.selectedThreadId,
    required this.selectedThread,
    required this.compactLayout,
    required this.onCreateThread,
    required this.onThreadSelected,
    this.onThreadItemSelected,
    this.onThreadRename,
    this.onThreadDelete,
  });

  final List<String> threads;
  final List<PbThreadListItemData>? threadItems;
  final String? selectedThreadId;
  final String? selectedThread;
  final bool compactLayout;
  final VoidCallback onCreateThread;
  final ValueChanged<String> onThreadSelected;
  final ValueChanged<PbThreadListItemData>? onThreadItemSelected;
  final ValueChanged<PbThreadListItemData>? onThreadRename;
  final ValueChanged<PbThreadListItemData>? onThreadDelete;

  @override
  State<_ThreadsSection> createState() => _ThreadsSectionState();
}

class _ThreadsSectionState extends State<_ThreadsSection> {
  static const double _selectedRevealInset = 12;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollRegionKey = GlobalKey();
  final Map<String, GlobalKey> _threadKeys = {};
  String? _lastRevealSignature;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadItems = widget.threadItems ?? [for (final thread in widget.threads) PbThreadListItemData(id: thread, title: thread)];
    if (widget.compactLayout || widget.selectedThread == null) {
      _lastRevealSignature = null;
    } else {
      _scheduleSelectedThreadReveal(threadItems);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.compactLayout ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Text('Threads', style: PowerboardsTypography.label),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.only(bottom: 6), child: _newThreadChip()),
        if (widget.compactLayout)
          for (var i = 0; i < threadItems.length; i++) ...[
            _threadChip(threadItems[i]),
            if (i != threadItems.length - 1) const SizedBox(height: 8),
          ]
        else
          _SidepaneScrollViewport.separated(
            controller: _scrollController,
            viewportKey: _scrollRegionKey,
            itemCount: threadItems.length,
            gap: 8,
            itemBuilder: (context, index) {
              final thread = threadItems[index];

              return KeyedSubtree(key: _keyForThread(thread.id), child: _threadChip(thread));
            },
          ),
      ],
    );
  }

  Widget _newThreadChip() {
    return PbThreadChip(title: 'New Thread...', create: true, selected: widget.selectedThread == null, onPressed: widget.onCreateThread);
  }

  Widget _threadChip(PbThreadListItemData thread) {
    final selectedThreadId = widget.selectedThreadId;
    final selected = selectedThreadId == null ? thread.title == widget.selectedThread : thread.id == selectedThreadId;

    return PbThreadChip(
      title: thread.title,
      selected: selected,
      onPressed: () {
        widget.onThreadSelected(thread.title);
        widget.onThreadItemSelected?.call(thread);
      },
      onRename: widget.onThreadRename == null ? null : () => widget.onThreadRename!(thread),
      onDelete: widget.onThreadDelete == null ? null : () => widget.onThreadDelete!(thread),
    );
  }

  GlobalKey _keyForThread(String title) {
    return _threadKeys.putIfAbsent(title, GlobalKey.new);
  }

  void _scheduleSelectedThreadReveal(List<PbThreadListItemData> threads) {
    final selectedThreadId = widget.selectedThreadId;
    final selectedThread = selectedThreadId ?? widget.selectedThread;
    String? selectedKey = selectedThreadId;
    if (selectedKey == null) {
      for (final thread in threads) {
        if (thread.title == selectedThread) {
          selectedKey = thread.id;
          break;
        }
      }
    }
    if (selectedThread == null || selectedKey == null || !threads.any((thread) => thread.id == selectedKey)) {
      _lastRevealSignature = null;
      return;
    }

    final revealSignature = '$selectedKey:${threads.length}:${widget.compactLayout}';
    if (_lastRevealSignature == revealSignature) {
      return;
    }
    _lastRevealSignature = revealSignature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final context = _threadKeys[selectedKey]?.currentContext;
      final scrollRegionContext = _scrollRegionKey.currentContext;

      if (context == null || scrollRegionContext == null) {
        return;
      }

      final selectedBox = context.findRenderObject();
      final scrollRegionBox = scrollRegionContext.findRenderObject();

      if (selectedBox is! RenderBox || scrollRegionBox is! RenderBox) {
        return;
      }

      final selectedOffset = selectedBox.localToGlobal(Offset.zero);
      final scrollRegionOffset = scrollRegionBox.localToGlobal(Offset.zero);
      final selectedTop = selectedOffset.dy;
      final selectedBottom = selectedTop + selectedBox.size.height;
      final topEdge = scrollRegionOffset.dy + _selectedRevealInset;
      final bottomEdge = scrollRegionOffset.dy + scrollRegionBox.size.height - _selectedRevealInset;
      final maxScrollExtent = _scrollController.position.maxScrollExtent;

      if (selectedTop < topEdge) {
        _scrollController.jumpTo((_scrollController.offset + selectedTop - topEdge).clamp(0, maxScrollExtent));
        return;
      }

      if (selectedBottom > bottomEdge) {
        _scrollController.jumpTo((_scrollController.offset + selectedBottom - bottomEdge).clamp(0, maxScrollExtent));
      }
    });
  }
}

class PbAgentCard extends StatefulWidget {
  const PbAgentCard({super.key, required this.data, this.onPressed});

  final PbAgentListItemData data;
  final VoidCallback? onPressed;

  @override
  State<PbAgentCard> createState() => _PbAgentCardState();
}

class _PbAgentCardState extends State<PbAgentCard> {
  bool _hovered = false;
  bool _hoverSuppressed = false;
  bool _pressed = false;

  Color get _statusColor {
    return switch (widget.data.statusTone) {
      PbAgentStatusTone.online => PbColors.statusOnline,
      PbAgentStatusTone.amber => PbColors.customAmber,
      PbAgentStatusTone.gray => PbColors.customGray,
      PbAgentStatusTone.error => PbColors.alert,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered && !_hoverSuppressed;
    final lifted = hovered && !_pressed;
    final showSelectionAffordance = !widget.data.selected && (hovered || _pressed);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _hoverSuppressed = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          setState(() {
            _pressed = false;
            _hoverSuppressed = true;
          });
          widget.onPressed?.call();
        },
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.ease,
          transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 70),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: widget.data.selected || _pressed ? PbColors.customStateSelectedSurface : PbColors.surfacePanel,
            gradient: widget.data.selected || _pressed
                ? null
                : const LinearGradient(
                    colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.data.selected || _pressed ? PbColors.customStateSelectedBorder : PbColors.borderSoft),
            boxShadow: _pressed
                ? const [
                    BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.08), blurRadius: 2, offset: Offset(0, 1), blurStyle: BlurStyle.inner),
                  ]
                : lifted
                ? const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.12), blurRadius: 30, offset: Offset(0, 14))]
                : null,
          ),
          child: Row(
            children: [
              _SideIconFrame(assetName: widget.data.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(widget.data.title, style: PowerboardsTypography.button, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.5),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.data.status,
                            style: PowerboardsTypography.textXSmall.copyWith(fontWeight: FontWeight.w500, color: PbColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (widget.data.selected)
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: PbSvgIcon(assetName: 'circle-check-big', size: 20, color: PbColors.customBrandInk),
                  ),
                )
              else if (showSelectionAffordance)
                const _GhostIcon(assetName: 'circle', selectionAffordance: true)
              else
                const SizedBox(width: 38, height: 38),
            ],
          ),
        ),
      ),
    );
  }
}

class PbThreadChip extends StatefulWidget {
  const PbThreadChip({
    super.key,
    required this.title,
    this.selected = false,
    this.create = false,
    this.onPressed,
    this.onRename,
    this.onDelete,
  });

  final String title;
  final bool selected;
  final bool create;
  final VoidCallback? onPressed;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  State<PbThreadChip> createState() => _PbThreadChipState();
}

class _PbThreadChipState extends State<PbThreadChip> {
  bool _hovered = false;
  bool _hoverSuppressed = false;
  bool _pressed = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered && !_hoverSuppressed;
    final lifted = hovered && !_pressed;
    final showHoverShadow = lifted && !_menuOpen;
    final active = widget.selected || _pressed || _menuOpen;
    final selectedBackground = widget.selected || _pressed;
    final selectedBorder = selectedBackground && !_menuOpen;
    final hoverSurface = showHoverShadow;
    final hoverBackground = hoverSurface && !widget.selected;
    final menuOpenBackground = _menuOpen && !widget.selected;
    final showAction = (widget.create && !widget.selected) || _menuOpen || hovered || _pressed;
    final showSelectedMark = widget.selected && !_menuOpen && !hovered && !_pressed;
    final stateDuration = hovered || _pressed || _menuOpen ? const Duration(milliseconds: 160) : Duration.zero;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _hoverSuppressed = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          setState(() {
            _pressed = false;
            _hoverSuppressed = true;
          });
          widget.onPressed?.call();
        },
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : stateDuration,
          curve: Curves.ease,
          transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: showHoverShadow
                ? const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.12), blurRadius: 30, offset: Offset(0, 14))]
                : null,
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
            decoration: BoxDecoration(
              color: menuOpenBackground
                  ? PbColors.customMenuOpenSurface
                  : selectedBackground
                  ? PbColors.customStateSelectedSurface
                  : hoverBackground
                  ? PbColors.surfacePanel
                  : Colors.transparent,
              gradient: hoverBackground
                  ? const LinearGradient(
                      colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _menuOpen
                    ? Colors.transparent
                    : selectedBorder
                    ? PbColors.customStateSelectedBorder
                    : hoverSurface
                    ? PbColors.borderSoft
                    : Colors.transparent,
              ),
              boxShadow: _pressed
                  ? const [
                      BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.08), blurRadius: 2, offset: Offset(0, 1), blurStyle: BlurStyle.inner),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: PowerboardsTypography.button.copyWith(color: active ? PbColors.textPrimary : PbColors.textBody),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: showSelectedMark ? 1 : 0,
                        child: const PbSvgIcon(assetName: 'circle-check-big', size: 20, color: PbColors.customBrandInk),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: showAction ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !showAction,
                          child: widget.create
                              ? const _GhostIcon(assetName: 'plus', color: PbColors.textPrimary, opacity: 1)
                              : PbSidepaneItemMenu(
                                  onOpenChanged: (open) => setState(() => _menuOpen = open),
                                  panelBuilder: (closeMenu) =>
                                      PbThreadItemMenu(onRename: widget.onRename, onDelete: widget.onDelete, onDismiss: closeMenu),
                                ),
                        ),
                      ),
                    ],
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

class _FilesPanel extends StatelessWidget {
  const _FilesPanel({required this.attachments, required this.onPreviewFile});

  final List<PbAttachmentListItemData> attachments;
  final ValueChanged<PbAttachmentListItemData> onPreviewFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RoomPanelDescription('Browse attachments by selected agent.'),
        const SizedBox(height: 20),
        _AttachmentList(attachments: attachments, onPreviewFile: onPreviewFile),
      ],
    );
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({required this.attachments, required this.onPreviewFile});

  static const _emptyAttachment = PbAttachmentListItemData(
    title: 'No files attached',
    subtitle: 'Files from this agent will appear here.',
    fileType: PbAttachmentFileType.generic,
  );

  final List<PbAttachmentListItemData> attachments;
  final ValueChanged<PbAttachmentListItemData> onPreviewFile;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return _SidepaneScrollViewport.separated(
        itemCount: 1,
        gap: 10,
        topPadding: _sidepaneListTopHoverClearance,
        itemBuilder: (context, index) => const PbAttachmentCard(data: _emptyAttachment, emptyState: true),
      );
    }

    return _SidepaneScrollViewport.separated(
      itemCount: attachments.length,
      gap: 10,
      topPadding: _sidepaneListTopHoverClearance,
      itemBuilder: (context, index) => PbAttachmentCard(data: attachments[index], onPressed: () => onPreviewFile(attachments[index])),
    );
  }
}

class _SidepaneScrollViewport extends StatelessWidget {
  const _SidepaneScrollViewport.separated({
    required this.itemCount,
    required this.itemBuilder,
    required this.gap,
    this.controller,
    this.expand = true,
    this.topPadding = _sidepaneScrollTopPadding,
    this.viewportKey,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double gap;
  final ScrollController? controller;
  final bool expand;
  final double topPadding;
  final Key? viewportKey;

  @override
  Widget build(BuildContext context) {
    final viewport = LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth + (_sidepaneInlinePadding * 2);

        return OverflowBox(
          alignment: Alignment.center,
          minWidth: viewportWidth,
          maxWidth: viewportWidth,
          minHeight: constraints.maxHeight,
          maxHeight: constraints.maxHeight,
          child: SizedBox(
            key: viewportKey,
            width: viewportWidth,
            height: constraints.maxHeight,
            child: ListView.separated(
              controller: controller,
              clipBehavior: Clip.hardEdge,
              padding: EdgeInsets.fromLTRB(_sidepaneInlinePadding, topPadding, _sidepaneInlinePadding, _sidepaneScrollBottomPadding),
              itemCount: itemCount,
              separatorBuilder: (_, _) => SizedBox(height: gap),
              itemBuilder: itemBuilder,
            ),
          ),
        );
      },
    );

    return expand ? Expanded(child: viewport) : viewport;
  }
}

class PbAttachmentCard extends StatefulWidget {
  const PbAttachmentCard({super.key, required this.data, this.onPressed, this.emptyState = false});

  final PbAttachmentListItemData data;
  final VoidCallback? onPressed;
  final bool emptyState;

  @override
  State<PbAttachmentCard> createState() => _PbAttachmentCardState();
}

class _PbAttachmentCardState extends State<PbAttachmentCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final lifted = !widget.emptyState && _hovered && !_pressed && !_menuOpen;
    final showAction = !widget.emptyState && (_hovered || _pressed || _menuOpen);
    final iconAssetName = widget.emptyState ? 'file-text' : widget.data.iconAssetName;
    final iconColor = widget.emptyState ? PbColors.textSubtle : widget.data.iconColor;

    return MouseRegion(
      cursor: widget.emptyState ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: widget.emptyState ? null : (_) => setState(() => _hovered = true),
      onExit: widget.emptyState
          ? null
          : (_) => setState(() {
              _hovered = false;
              _pressed = false;
            }),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: widget.emptyState ? null : (_) => setState(() => _pressed = true),
        onPointerUp: widget.emptyState ? null : (_) => setState(() => _pressed = false),
        onPointerCancel: widget.emptyState ? null : (_) => setState(() => _pressed = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.emptyState ? null : widget.onPressed,
          child: Transform.translate(
            offset: Offset(0, lifted ? -1 : 0),
            child: AnimatedContainer(
              duration: _pressed ? Duration.zero : const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.fromLTRB(21, 11, 12, 11),
              decoration: BoxDecoration(
                color: widget.emptyState
                    ? null
                    : _menuOpen
                    ? PbColors.customMenuOpenSurface
                    : _pressed
                    ? PbColors.customStateSelectedSurface
                    : null,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.emptyState
                      ? PbColors.borderSoft.withValues(alpha: 0.92)
                      : _menuOpen
                      ? Colors.transparent
                      : _pressed
                      ? PbColors.customStateSelectedBorder
                      : PbColors.borderSoft,
                ),
                gradient: widget.emptyState
                    ? LinearGradient(
                        colors: [
                          Color.lerp(PbColors.surfacePanel, PbColors.surfacePanelSoft, 0.08)!,
                          PbColors.surfacePanelSoft.withValues(alpha: 0.96),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : _menuOpen || _pressed
                    ? null
                    : const LinearGradient(
                        colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                boxShadow: widget.emptyState
                    ? null
                    : _menuOpen
                    ? null
                    : _pressed
                    ? const [
                        BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.08), blurRadius: 2, offset: Offset(0, 1), blurStyle: BlurStyle.inner),
                      ]
                    : lifted
                    ? const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.12), blurRadius: 30, offset: Offset(0, 14))]
                    : null,
              ),
              child: Row(
                children: [
                  PbSvgIcon(assetName: iconAssetName, size: 28, color: iconColor),
                  const SizedBox(width: 23),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.data.title,
                          style: PowerboardsTypography.button.copyWith(color: widget.emptyState ? PbColors.textMuted : null),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4.5),
                        Text(
                          widget.data.subtitle,
                          style: PowerboardsTypography.textXSmall.copyWith(
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: widget.emptyState ? PbColors.textSubtle : PbColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!widget.emptyState) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: showAction ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !showAction,
                          child: PbSidepaneItemMenu(
                            onOpenChanged: (open) => setState(() => _menuOpen = open),
                            panelBuilder: (closeMenu) => PbFileItemMenu(onOpen: widget.onPressed, onDismiss: closeMenu),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PbFilePreviewPane extends StatelessWidget {
  const PbFilePreviewPane({
    super.key,
    required this.file,
    required this.fullscreen,
    this.resizing = false,
    this.onToggleFullscreen,
    this.onClose,
  });

  final PbAttachmentListItemData file;
  final bool fullscreen;
  final bool resizing;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: fullscreen ? EdgeInsets.zero : const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: const BoxDecoration(
        color: PbColors.surfacePanelWash,
        border: Border(left: BorderSide(color: PbColors.borderSoft)),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final toolbarState = _FilePreviewToolbarState.resolve(context, width: constraints.maxWidth, resizing: resizing);

              return Container(
                height: fullscreen ? 82 : null,
                padding: fullscreen ? const EdgeInsets.symmetric(horizontal: 28) : EdgeInsets.zero,
                decoration: fullscreen
                    ? const BoxDecoration(
                        border: Border(bottom: BorderSide(color: PbColors.borderSoft)),
                      )
                    : null,
                child: Row(
                  children: [
                    PbSvgIcon(assetName: file.iconAssetName, size: 24, color: file.iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        file.title,
                        style: fullscreen ? PowerboardsTypography.h4 : PowerboardsTypography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 7),
                    _FilePreviewToolbar(state: toolbarState, onAskAgent: () {}, onShare: () {}, onDownload: () {}),
                    _GhostIcon(assetName: fullscreen ? 'minimize-2' : 'maximize-2', size: 40, onPressed: onToggleFullscreen),
                    _GhostIcon(assetName: 'x', size: 40, onPressed: onClose),
                  ],
                ),
              );
            },
          ),
          if (!fullscreen) const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: fullscreen ? EdgeInsets.zero : null,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(fullscreen ? 0 : 14),
                border: fullscreen ? null : Border.all(color: PbColors.borderSoft),
                gradient: fullscreen
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFAFFFFFF), PbColors.surfacePanel],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                color: fullscreen ? PbColors.surfacePanelWash : null,
                boxShadow: fullscreen
                    ? null
                    : const [BoxShadow(color: Color.fromRGBO(255, 255, 255, 0.5), blurRadius: 0, offset: Offset(0, 1))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _FilePreviewToolbarStateId { full, downloadIcon, downloadMenu, shareIcon, shareMenu, allMenu }

enum _FilePreviewAction {
  askAgent('Ask agent', 'message-square-plus'),
  share('Share', 'share'),
  download('Download', 'arrow-down-to-line');

  const _FilePreviewAction(this.label, this.iconAssetName);

  final String label;
  final String iconAssetName;
}

class _FilePreviewToolbarState {
  const _FilePreviewToolbarState({required this.id, required this.iconOnly, required this.inMenu});

  static const _titleFitWidth = 176.0;
  static const _headerGap = 7.0;
  static const _toolbarGap = 6.0;
  static const _buttonInlinePadding = 16.0;
  static const _buttonIconSize = 18.0;
  static const _buttonIconGap = 10.0;
  static const _iconButtonSize = 40.0;

  static const full = _FilePreviewToolbarState(id: _FilePreviewToolbarStateId.full, iconOnly: {}, inMenu: {});
  static const downloadIcon = _FilePreviewToolbarState(
    id: _FilePreviewToolbarStateId.downloadIcon,
    iconOnly: {_FilePreviewAction.download},
    inMenu: {},
  );
  static const downloadMenu = _FilePreviewToolbarState(
    id: _FilePreviewToolbarStateId.downloadMenu,
    iconOnly: {},
    inMenu: {_FilePreviewAction.download},
  );
  static const shareIcon = _FilePreviewToolbarState(
    id: _FilePreviewToolbarStateId.shareIcon,
    iconOnly: {_FilePreviewAction.share},
    inMenu: {_FilePreviewAction.download},
  );
  static const shareMenu = _FilePreviewToolbarState(
    id: _FilePreviewToolbarStateId.shareMenu,
    iconOnly: {},
    inMenu: {_FilePreviewAction.download, _FilePreviewAction.share},
  );
  static const allMenu = _FilePreviewToolbarState(
    id: _FilePreviewToolbarStateId.allMenu,
    iconOnly: {},
    inMenu: {_FilePreviewAction.download, _FilePreviewAction.share, _FilePreviewAction.askAgent},
  );

  static const _displayStates = [full, downloadIcon, downloadMenu, shareIcon, shareMenu, allMenu];
  static const _stableStates = [full, downloadMenu, shareMenu, allMenu];

  final _FilePreviewToolbarStateId id;
  final Set<_FilePreviewAction> iconOnly;
  final Set<_FilePreviewAction> inMenu;

  bool isIconOnly(_FilePreviewAction action) => iconOnly.contains(action);
  bool isInMenu(_FilePreviewAction action) => inMenu.contains(action);

  static _FilePreviewToolbarState resolve(BuildContext context, {required double width, required bool resizing}) {
    final states = resizing ? _displayStates : _stableStates;

    for (final state in states) {
      if (_fits(context, width, state)) {
        return state;
      }
    }

    return allMenu;
  }

  static bool _fits(BuildContext context, double width, _FilePreviewToolbarState state) {
    final availableTitleWidth = width - _toolbarWidth(context, state) - _headerGap;
    return availableTitleWidth >= _titleFitWidth;
  }

  static double _toolbarWidth(BuildContext context, _FilePreviewToolbarState state) {
    final visibleWidths = <double>[
      for (final action in _FilePreviewAction.values)
        if (!state.isInMenu(action)) state.isIconOnly(action) ? _iconButtonSize : _buttonWidth(context, action.label),
      if (state.inMenu.isNotEmpty) _iconButtonSize,
      _iconButtonSize,
      _iconButtonSize,
    ];
    final gaps = (visibleWidths.length - 1).clamp(0, double.infinity) * _toolbarGap;

    return visibleWidths.fold<double>(0, (sum, width) => sum + width) + gaps;
  }

  static double _buttonWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: PowerboardsTypography.button),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();

    return (_buttonInlinePadding * 2) + _buttonIconSize + _buttonIconGap + painter.width;
  }
}

class _FilePreviewToolbar extends StatelessWidget {
  const _FilePreviewToolbar({required this.state, this.onAskAgent, this.onShare, this.onDownload});

  final _FilePreviewToolbarState state;
  final VoidCallback? onAskAgent;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;

  VoidCallback? _handlerFor(_FilePreviewAction action) {
    return switch (action) {
      _FilePreviewAction.askAgent => onAskAgent,
      _FilePreviewAction.share => onShare,
      _FilePreviewAction.download => onDownload,
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleActions = _FilePreviewAction.values.where((action) => !state.isInMenu(action)).toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in visibleActions) ...[
            _FilePreviewActionButton(
              key: ValueKey('${state.id.name}-${action.name}'),
              action: action,
              iconOnly: state.isIconOnly(action),
              onPressed: _handlerFor(action),
            ),
            const SizedBox(width: 6),
          ],
          if (state.inMenu.isNotEmpty) ...[
            PbSidepaneItemMenu(
              size: 40,
              panelBuilder: (closeMenu) => PbFilePreviewPaneOptionsMenu(
                showAskAgent: state.isInMenu(_FilePreviewAction.askAgent),
                showShare: state.isInMenu(_FilePreviewAction.share),
                showDownload: state.isInMenu(_FilePreviewAction.download),
                onDismiss: closeMenu,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _FilePreviewActionButton extends StatelessWidget {
  const _FilePreviewActionButton({super.key, required this.action, required this.iconOnly, this.onPressed});

  final _FilePreviewAction action;
  final bool iconOnly;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: PbButton(
        key: ValueKey(iconOnly),
        iconAssetName: action.iconAssetName,
        label: action.label,
        variant: PbButtonVariant.secondary,
        iconOnly: iconOnly,
        iconOnlySize: 40,
        height: 36,
        horizontalPadding: 16,
        iconGap: 10,
        onPressed: onPressed,
      ),
    );
  }
}

class _SideIconFrame extends StatelessWidget {
  const _SideIconFrame({required this.assetName});

  final String assetName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: PbColors.surfacePanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PbColors.borderSoft),
      ),
      alignment: Alignment.center,
      child: PbSvgIcon(assetName: assetName, size: 22, color: PbColors.customBrandInk),
    );
  }
}

typedef PbSidepaneMenuBuilder = Widget Function(VoidCallback closeMenu);

class PbSidepaneItemMenu extends StatefulWidget {
  const PbSidepaneItemMenu({super.key, required this.panelBuilder, this.size = 38, this.onOpenChanged});

  final PbSidepaneMenuBuilder panelBuilder;
  final double size;
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<PbSidepaneItemMenu> createState() => _PbSidepaneItemMenuState();
}

class _PbSidepaneItemMenuState extends State<PbSidepaneItemMenu> {
  bool _open = false;

  void _setOpen(bool open) {
    if (_open == open) {
      return;
    }

    setState(() => _open = open);
    widget.onOpenChanged?.call(open);
  }

  void _closeMenu() {
    if (!_open) {
      return;
    }

    _setOpen(false);
  }

  void _toggleMenu() => _setOpen(!_open);

  @override
  Widget build(BuildContext context) {
    return PbMenuAnchor(
      placement: PbMenuAnchorPlacement.bottomRight,
      gap: 2,
      onDismiss: _closeMenu,
      panel: _open ? PbMenuCard(width: 204, child: widget.panelBuilder(_closeMenu)) : null,
      child: _GhostIcon(assetName: 'ellipsis', size: widget.size, selected: _open, onPressed: _toggleMenu),
    );
  }
}

class PbAgentItemMenu extends StatelessWidget {
  const PbAgentItemMenu({super.key, this.onDetails, this.onShare, this.onUninstall, this.onDismiss});

  final VoidCallback? onDetails;
  final VoidCallback? onShare;
  final VoidCallback? onUninstall;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return PbMenuList(
      children: [
        PbMenuOption(
          title: 'Details',
          leadingIconAssetName: 'info',
          singleLine: true,
          onPressed: () => _runMenuAction(onDetails, onDismiss),
        ),
        PbMenuOption(title: 'Share', leadingIconAssetName: 'share', singleLine: true, onPressed: () => _runMenuAction(onShare, onDismiss)),
        PbMenuOption(
          title: 'Uninstall',
          leadingIconAssetName: 'circle-minus-alert',
          singleLine: true,
          alert: true,
          onPressed: () => _runMenuAction(onUninstall, onDismiss),
        ),
      ],
    );
  }
}

class PbThreadItemMenu extends StatelessWidget {
  const PbThreadItemMenu({super.key, this.onRename, this.onDelete, this.onDismiss});

  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return PbMenuList(
      children: [
        PbMenuOption(
          title: 'Rename',
          leadingIconAssetName: 'text-cursor',
          singleLine: true,
          onPressed: () => _runMenuAction(onRename, onDismiss),
        ),
        PbMenuOption(
          title: 'Delete',
          leadingIconAssetName: 'trash-alert',
          singleLine: true,
          alert: true,
          onPressed: () => _runMenuAction(onDelete, onDismiss),
        ),
      ],
    );
  }
}

class PbFileItemMenu extends StatelessWidget {
  const PbFileItemMenu({super.key, this.onOpen, this.onAskAgent, this.onShare, this.onDownload, this.onDismiss});

  final VoidCallback? onOpen;
  final VoidCallback? onAskAgent;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return PbMenuList(
      children: [
        PbMenuOption(
          title: 'Open',
          leadingIconAssetName: 'arrow-up-right',
          singleLine: true,
          onPressed: () => _runMenuAction(onOpen, onDismiss),
        ),
        PbMenuOption(
          title: 'Ask agent',
          leadingIconAssetName: 'message-square-plus',
          singleLine: true,
          onPressed: () => _runMenuAction(onAskAgent, onDismiss),
        ),
        PbMenuOption(title: 'Share', leadingIconAssetName: 'share', singleLine: true, onPressed: () => _runMenuAction(onShare, onDismiss)),
        PbMenuOption(
          title: 'Download',
          leadingIconAssetName: 'arrow-down-to-line',
          singleLine: true,
          onPressed: () => _runMenuAction(onDownload, onDismiss),
        ),
      ],
    );
  }
}

class PbFilePreviewPaneOptionsMenu extends StatelessWidget {
  const PbFilePreviewPaneOptionsMenu({
    super.key,
    this.showAskAgent = true,
    this.showShare = true,
    this.showDownload = true,
    this.onAskAgent,
    this.onShare,
    this.onDownload,
    this.onDismiss,
  });

  final bool showAskAgent;
  final bool showShare;
  final bool showDownload;
  final VoidCallback? onAskAgent;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return PbMenuList(
      children: [
        if (showAskAgent)
          PbMenuOption(
            title: 'Ask agent',
            leadingIconAssetName: 'message-square-plus',
            singleLine: true,
            onPressed: () => _runMenuAction(onAskAgent, onDismiss),
          ),
        if (showShare)
          PbMenuOption(
            title: 'Share',
            leadingIconAssetName: 'share',
            singleLine: true,
            onPressed: () => _runMenuAction(onShare, onDismiss),
          ),
        if (showDownload)
          PbMenuOption(
            title: 'Download',
            leadingIconAssetName: 'arrow-down-to-line',
            singleLine: true,
            onPressed: () => _runMenuAction(onDownload, onDismiss),
          ),
      ],
    );
  }
}

void _runMenuAction(VoidCallback? action, VoidCallback? dismiss) {
  action?.call();
  dismiss?.call();
}

class _GhostIcon extends StatefulWidget {
  const _GhostIcon({
    required this.assetName,
    this.size = 38,
    this.selected = false,
    this.selectionAffordance = false,
    this.color,
    this.opacity,
    this.onPressed,
  });

  final String assetName;
  final double size;
  final bool selected;
  final bool selectionAffordance;
  final Color? color;
  final double? opacity;
  final VoidCallback? onPressed;

  @override
  State<_GhostIcon> createState() => _GhostIconState();
}

class _GhostIconState extends State<_GhostIcon> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered || _pressed;
    final iconColor = widget.color ?? (active || widget.selectionAffordance ? PbColors.customBrandInk : PbColors.customBrandInk);
    final iconOpacity =
        widget.opacity ??
        (active
            ? 1.0
            : widget.selectionAffordance
            ? 0.5
            : 0.3);

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
          width: widget.size,
          height: widget.size,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _pressed ? 0.96 : 1,
              child: PbSvgIcon(
                assetName: widget.assetName,
                size: 18,
                color: iconColor.withValues(alpha: iconOpacity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PbAgentListItemData {
  const PbAgentListItemData({
    this.id,
    required this.title,
    required this.status,
    required this.icon,
    this.statusTone = PbAgentStatusTone.online,
    this.selected = false,
  });

  final String? id;
  final String title;
  final String status;
  final String icon;
  final PbAgentStatusTone statusTone;
  final bool selected;

  String get identity => id ?? title;

  PbAgentListItemData copyWith({String? id, String? title, String? status, String? icon, PbAgentStatusTone? statusTone, bool? selected}) {
    return PbAgentListItemData(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      statusTone: statusTone ?? this.statusTone,
      selected: selected ?? this.selected,
    );
  }
}

class PbThreadListItemData {
  const PbThreadListItemData({required this.id, required this.title});

  final String id;
  final String title;
}
