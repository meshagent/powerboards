import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pb_attachment_file_metadata.dart';
import '../../theme/pb_colors.dart';
import '../files/pb_files_data.dart';
import '../files/pb_files_drop_target.dart';
import '../files/pb_files_header.dart';
import '../files/pb_files_layout_values.dart';
import '../files/pb_files_side_pane.dart';
import '../files/pb_files_table.dart';
import 'pb_room_panel.dart';
import 'pb_room_panel_mount.dart';

enum _FilesSortDirection { asc, desc }

class PbFilesPage extends StatefulWidget {
  const PbFilesPage({
    super.key,
    required this.roomPanelCollapsed,
    required this.onRoomPanelCollapsedChanged,
    required this.roomPanelWidth,
    required this.onRoomPanelWidthChanged,
    required this.initialPreviewFile,
    required this.initialPreviewOpen,
    required this.onPreviewFileChanged,
    required this.onPreviewOpenChanged,
    required this.filePreviewFullscreen,
    required this.onFilePreviewFullscreenChanged,
    this.onLinkedThreadPressed,
  });

  final bool roomPanelCollapsed;
  final ValueChanged<bool> onRoomPanelCollapsedChanged;
  final double roomPanelWidth;
  final ValueChanged<double> onRoomPanelWidthChanged;
  final PbFilesItemData? initialPreviewFile;
  final bool initialPreviewOpen;
  final ValueChanged<PbFilesItemData?> onPreviewFileChanged;
  final ValueChanged<bool> onPreviewOpenChanged;
  final bool filePreviewFullscreen;
  final ValueChanged<bool> onFilePreviewFullscreenChanged;
  final PbFilesLinkedThreadHandler? onLinkedThreadPressed;

  @override
  State<PbFilesPage> createState() => _PbFilesPageState();
}

class _PbFilesPageState extends State<PbFilesPage> {
  final OverlayPortalController _roomPanelOverlayController = OverlayPortalController();
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filesKeyboardFocusNode = FocusNode(debugLabel: 'Files keyboard navigation');

  final List<PbFilesItemData> _items = [..._initialFiles];
  final Set<String> _selectedIds = {};

  PbFilesSortKey _sortKey = PbFilesSortKey.updated;
  _FilesSortDirection _sortDirection = _FilesSortDirection.desc;
  String _currentPath = '';
  bool _roomPanelOverlayOpen = false;
  late bool _filePreviewOpen = widget.initialPreviewOpen;
  bool _collapseRoomPanelAfterPreviewClose = false;
  late PbFilesItemData? _previewFile = widget.initialPreviewFile ?? _initialFiles.first;
  String? _keyboardPreviewFileId;
  int _keyboardPreviewDirection = 0;
  bool _filesKeyboardBrowseArmed = false;
  int _processingSequence = 0;

  @override
  void dispose() {
    _filesKeyboardFocusNode.dispose();
    _filterController.dispose();
    super.dispose();
  }

  String get _filterQuery => _filterController.text.trim().toLowerCase();

  List<PbFilesItemData> get _visibleItems {
    final rows = _items.where((item) {
      if (item.parentPath != _currentPath) {
        return false;
      }

      final query = _filterQuery;
      if (query.isEmpty) {
        return true;
      }

      return item.filterText.contains(query);
    }).toList();

    rows.sort(_compareFiles);
    return rows;
  }

  List<PbFilesItemData> get _recentFiles {
    final files = _items.where((item) => item.kind == PbFilesItemKind.file).toList()
      ..sort((left, right) => right.updatedSort.compareTo(left.updatedSort));
    return files.take(8).toList();
  }

  int _compareFiles(PbFilesItemData left, PbFilesItemData right) {
    final result = switch (_sortKey) {
      PbFilesSortKey.updated => left.updatedSort.compareTo(right.updatedSort),
      PbFilesSortKey.name => left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      PbFilesSortKey.type => left.type.toLowerCase().compareTo(right.type.toLowerCase()),
      PbFilesSortKey.thread => _threadSort(left).compareTo(_threadSort(right)),
      PbFilesSortKey.creator => left.creator.toLowerCase().compareTo(right.creator.toLowerCase()),
    };

    return _sortDirection == _FilesSortDirection.desc ? -result : result;
  }

  String _threadSort(PbFilesItemData item) {
    final threads = item.linkedThreadTargets;
    if (threads.isEmpty) {
      return 'zzzz';
    }

    return threads.join(', ').toLowerCase();
  }

  void _setSort(PbFilesSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortDirection = _sortDirection == _FilesSortDirection.desc ? _FilesSortDirection.asc : _FilesSortDirection.desc;
      } else {
        _sortKey = key;
        _sortDirection = key == PbFilesSortKey.updated ? _FilesSortDirection.desc : _FilesSortDirection.asc;
      }
    });
  }

  void _setCurrentPath(String path, {bool keepPreview = true}) {
    setState(() {
      _currentPath = path;
      _selectedIds.clear();
      _keyboardPreviewFileId = null;
      _keyboardPreviewDirection = 0;
      _filesKeyboardBrowseArmed = false;

      if (!keepPreview) {
        _closePreview();
      }
    });
  }

  void _toggleRowSelection(String id) {
    setState(() {
      _keyboardPreviewFileId = null;
      _keyboardPreviewDirection = 0;
      _filesKeyboardBrowseArmed = false;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
        if (_previewFile?.id != id) {
          _closePreview();
        }
      }
    });
  }

  void _toggleVisibleSelection() {
    final visibleIds = _visibleItems.map((item) => item.id).toSet();
    final allSelected = visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains);

    setState(() {
      _keyboardPreviewFileId = null;
      _keyboardPreviewDirection = 0;
      _filesKeyboardBrowseArmed = false;
      if (allSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
        _closePreview();
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _keyboardPreviewFileId = null;
      _keyboardPreviewDirection = 0;
      _filesKeyboardBrowseArmed = false;
    });
  }

  void _openItem(PbFilesItemData item, {required bool responsivePanel, required bool mobilePanel}) {
    _filesKeyboardFocusNode.requestFocus();

    if (_selectedIds.isNotEmpty) {
      _toggleRowSelection(item.id);
      return;
    }

    if (item.kind == PbFilesItemKind.folder) {
      _setCurrentPath(item.folderPath, keepPreview: true);
      return;
    }

    if (!item.canPreview) {
      return;
    }

    final collapseRoomPanelAfterClose = !responsivePanel && widget.roomPanelCollapsed;

    setState(() {
      _selectedIds.clear();
      _keyboardPreviewFileId = null;
      _keyboardPreviewDirection = 0;
      _filesKeyboardBrowseArmed = true;
      _previewFile = item;
      _filePreviewOpen = true;
      _collapseRoomPanelAfterPreviewClose = collapseRoomPanelAfterClose;
      if (responsivePanel && !mobilePanel) {
        _roomPanelOverlayOpen = true;
      }
    });
    widget.onPreviewFileChanged(item);
    widget.onPreviewOpenChanged(true);
    widget.onRoomPanelCollapsedChanged(false);

    if (responsivePanel && mobilePanel) {
      widget.onFilePreviewFullscreenChanged(true);
    }
  }

  void _openPreviewFromSidepane(PbFilesItemData item) {
    setState(() {
      _selectedIds.clear();
      _keyboardPreviewFileId = null;
      _keyboardPreviewDirection = 0;
      _filesKeyboardBrowseArmed = false;
      _previewFile = item;
      _filePreviewOpen = true;
      _collapseRoomPanelAfterPreviewClose = false;
    });
    widget.onPreviewFileChanged(item);
    widget.onPreviewOpenChanged(true);
    widget.onRoomPanelCollapsedChanged(false);
  }

  void _closePreview() {
    _filePreviewOpen = false;
    _collapseRoomPanelAfterPreviewClose = false;
    _keyboardPreviewFileId = null;
    _keyboardPreviewDirection = 0;
    _filesKeyboardBrowseArmed = false;
    widget.onPreviewOpenChanged(false);
    widget.onFilePreviewFullscreenChanged(false);
  }

  void _clearKeyboardPreviewNavigation() {
    if (_keyboardPreviewFileId == null && !_filesKeyboardBrowseArmed) {
      return;
    }

    setState(() {
      _keyboardPreviewFileId = null;
      _keyboardPreviewDirection = 0;
      _filesKeyboardBrowseArmed = false;
    });
  }

  bool _isFilesKeyboardNavigationBlocked() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus == _filesKeyboardFocusNode) {
      return false;
    }

    final context = primaryFocus.context;
    return context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleFilesKeyEvent(KeyEvent event, {required bool responsivePanel, required bool mobilePanel}) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_keyboardPreviewFileId == null && !_filesKeyboardBrowseArmed) {
        return KeyEventResult.ignored;
      }

      _clearKeyboardPreviewNavigation();
      return KeyEventResult.handled;
    }

    if (key != LogicalKeyboardKey.arrowDown && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }

    if (_selectedIds.isNotEmpty ||
        !_filePreviewOpen ||
        _previewFile == null ||
        !_filesKeyboardBrowseArmed ||
        _isFilesKeyboardNavigationBlocked()) {
      return KeyEventResult.ignored;
    }

    final previewableRows = _visibleItems.where((item) => item.canPreview).toList(growable: false);
    final currentIndex = previewableRows.indexWhere((item) => item.id == _previewFile!.id);

    if (currentIndex < 0) {
      return KeyEventResult.ignored;
    }

    final direction = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final nextIndex = (currentIndex + direction).clamp(0, previewableRows.length - 1);

    if (nextIndex == currentIndex) {
      return KeyEventResult.handled;
    }

    _openPreviewFromKeyboard(previewableRows[nextIndex], responsivePanel: responsivePanel, mobilePanel: mobilePanel, direction: direction);
    return KeyEventResult.handled;
  }

  void _openPreviewFromKeyboard(PbFilesItemData item, {required bool responsivePanel, required bool mobilePanel, required int direction}) {
    final collapseRoomPanelAfterClose = !responsivePanel && widget.roomPanelCollapsed;

    setState(() {
      _selectedIds.clear();
      _previewFile = item;
      _keyboardPreviewFileId = item.id;
      _keyboardPreviewDirection = direction;
      _filesKeyboardBrowseArmed = true;
      _filePreviewOpen = true;
      _collapseRoomPanelAfterPreviewClose = collapseRoomPanelAfterClose;
      if (responsivePanel && !mobilePanel) {
        _roomPanelOverlayOpen = true;
      }
    });
    widget.onPreviewFileChanged(item);
    widget.onPreviewOpenChanged(true);
    widget.onRoomPanelCollapsedChanged(false);

    if (responsivePanel && mobilePanel) {
      widget.onFilePreviewFullscreenChanged(true);
    }
  }

  void _handlePreviewClose() {
    final collapseRoomPanel = _collapseRoomPanelAfterPreviewClose;
    setState(_closePreview);
    if (collapseRoomPanel) {
      widget.onRoomPanelCollapsedChanged(true);
    }
  }

  void _setFullscreen(bool fullscreen) {
    if (!fullscreen) {
      setState(() => _filePreviewOpen = _previewFile != null);
      widget.onPreviewOpenChanged(_previewFile != null);
    }

    widget.onFilePreviewFullscreenChanged(fullscreen);
  }

  void _toggleRoomPanel({required bool responsivePanel, required PbFilesResponsiveMode responsiveMode}) {
    if (responsivePanel) {
      setState(() => _roomPanelOverlayOpen = true);
      return;
    }

    widget.onRoomPanelCollapsedChanged(!widget.roomPanelCollapsed);
  }

  void _openRoomPanelOverlay() {
    setState(() => _roomPanelOverlayOpen = true);
  }

  void _closeRoomPanelOverlay() {
    _roomPanelOverlayController.hide();
    setState(() => _roomPanelOverlayOpen = false);
  }

  bool _isProcessingErrorTitle(String title) {
    return RegExp(r'\b(error|failed|fail)\b', caseSensitive: false).hasMatch(title);
  }

  PbFilesItemData _createProcessingRow({String? title, bool error = false}) {
    _processingSequence += 1;
    final rowTitle = title ?? (error ? 'Failed upload error.txt' : 'Uploading file $_processingSequence.pdf');
    final rowError = error || _isProcessingErrorTitle(rowTitle);

    return PbFilesItemData(
      id: 'processing-$_processingSequence',
      title: rowTitle,
      type: '',
      thread: '',
      creator: '',
      creatorInitials: '',
      updatedLabel: 'Now',
      updatedSort: 202605291200 + _processingSequence,
      parentPath: _currentPath,
      fileType: PbAttachmentFileType.generic,
      kind: rowError ? PbFilesItemKind.processingError : PbFilesItemKind.processing,
    );
  }

  void _addProcessingRow({bool error = false}) {
    setState(() {
      _items.add(_createProcessingRow(error: error));
    });
  }

  void _addDroppedProcessingRows(List<String> fileNames) {
    final names = fileNames.map((name) => name.trim()).where((name) => name.isNotEmpty).toList(growable: false);

    setState(() {
      for (final name in names.isEmpty ? const ['Uploading file'] : names) {
        _items.add(_createProcessingRow(title: name));
      }
    });
  }

  void _removeProcessingRow(PbFilesItemData item) {
    setState(() => _items.removeWhere((candidate) => candidate.id == item.id));
  }

  void _openLinkedThread(PbFilesItemData item, String thread) {
    widget.onLinkedThreadPressed?.call(item, thread);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filePreviewFullscreen && _filePreviewOpen) {
      return PbFilePreviewPane(
        file: (_previewFile ?? _initialFiles.first).toAttachmentData(),
        fullscreen: true,
        showInlineBorder: false,
        onToggleFullscreen: () => _setFullscreen(false),
        onClose: _handlePreviewClose,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsivePanel = constraints.maxWidth <= pbRoomPanelStackBreakpoint;
        final mobilePanel = constraints.maxWidth <= pbShellMobileBreakpoint;
        final responsiveMode = mobilePanel
            ? PbFilesResponsiveMode.mobile
            : responsivePanel
            ? PbFilesResponsiveMode.overlay
            : PbFilesResponsiveMode.docked;
        final roomPanelExpanded = responsivePanel ? false : !widget.roomPanelCollapsed;
        final mainPanel = PbFilesMainPanel(
          currentPath: _currentPath,
          folderLabelForPath: _folderLabelForPath,
          items: _visibleItems,
          selectedIds: _selectedIds,
          sortKey: _sortKey,
          sortDirectionDescending: _sortDirection == _FilesSortDirection.desc,
          filterController: _filterController,
          hasActiveFilter: _filterQuery.isNotEmpty,
          roomPanelExpanded: roomPanelExpanded,
          responsiveMode: responsiveMode,
          previewFileId: _filePreviewOpen ? _previewFile?.id : null,
          keyboardPreviewFileId: _keyboardPreviewFileId,
          keyboardPreviewDirection: _keyboardPreviewDirection,
          onBreadcrumbPressed: (path) => _setCurrentPath(path, keepPreview: true),
          onSortChanged: _setSort,
          onFilterChanged: (_) => setState(() {}),
          onToggleSelection: _toggleRowSelection,
          onToggleVisibleSelection: _toggleVisibleSelection,
          onClearSelection: _clearSelection,
          onDeleteSelection: () {},
          onDownloadSelection: () {},
          onCreateFolder: () {},
          onCreateTextFile: () {},
          onUpload: _addProcessingRow,
          onFilesDropped: _addDroppedProcessingRows,
          onOpenRecentFiles: _openRoomPanelOverlay,
          onRoomPanelToggle: () => _toggleRoomPanel(responsivePanel: responsivePanel, responsiveMode: responsiveMode),
          onItemPressed: (item) => _openItem(item, responsivePanel: responsivePanel, mobilePanel: mobilePanel),
          onBrowseFolder: (item) => _setCurrentPath(item.folderPath, keepPreview: true),
          onRemoveProcessingRow: _removeProcessingRow,
          onLinkedThreadPressed: _openLinkedThread,
        );
        final keyboardPanel = Focus(
          focusNode: _filesKeyboardFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) => _handleFilesKeyEvent(event, responsivePanel: responsivePanel, mobilePanel: mobilePanel),
          child: Listener(onPointerDown: (_) => _clearKeyboardPreviewNavigation(), child: mainPanel),
        );
        PbFilesSidePane sidePaneBuilder(BuildContext context, bool resizing) {
          return PbFilesSidePane(
            files: _recentFiles,
            previewFile: _filePreviewOpen ? _previewFile : null,
            fullscreen: widget.filePreviewFullscreen,
            resizing: resizing,
            borderOnTop: responsivePanel,
            responsiveOverlay: responsivePanel,
            responsiveOverlayMobile: mobilePanel,
            onPreviewFile: _openPreviewFromSidepane,
            onToggleFullscreen: () => _setFullscreen(true),
            onClosePreview: _handlePreviewClose,
          );
        }

        if (responsivePanel) {
          if (_roomPanelOverlayOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _roomPanelOverlayController.show();
              }
            });
          }

          return OverlayPortal(
            controller: _roomPanelOverlayController,
            overlayChildBuilder: (context) => Positioned.fill(
              child: sidePaneBuilder(context, false).asOverlayFrame(mobile: mobilePanel, onClose: _closeRoomPanelOverlay),
            ),
            child: ColoredBox(color: PbColors.surfacePanelWash, child: keyboardPanel),
          );
        }

        if (_roomPanelOverlayOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (_roomPanelOverlayController.isShowing) {
                _roomPanelOverlayController.hide();
              }
              setState(() => _roomPanelOverlayOpen = false);
            }
          });
        }

        return ColoredBox(
          color: PbColors.surfacePanelWash,
          child: PbRoomPanelMount(
            activeTab: PbRoomPanelTab.files,
            filePreviewOpen: _filePreviewOpen,
            filePreviewFullscreen: widget.filePreviewFullscreen,
            roomPanelCollapsed: widget.roomPanelCollapsed,
            panelWidth: widget.roomPanelWidth,
            onPanelWidthChanged: widget.onRoomPanelWidthChanged,
            threadPanel: keyboardPanel,
            roomPanelBuilder: sidePaneBuilder,
          ),
        );
      },
    );
  }

  String _folderLabelForPath(String path) {
    if (path.isEmpty) {
      return 'Files';
    }

    return _items
            .where((item) => item.kind == PbFilesItemKind.folder)
            .cast<PbFilesItemData?>()
            .firstWhere((item) => item?.folderPath == path, orElse: () => null)
            ?.title ??
        path.split('/').last;
  }
}

class PbFilesMainPanel extends StatelessWidget {
  const PbFilesMainPanel({
    super.key,
    required this.currentPath,
    required this.folderLabelForPath,
    required this.items,
    required this.selectedIds,
    required this.sortKey,
    required this.sortDirectionDescending,
    required this.filterController,
    required this.hasActiveFilter,
    required this.roomPanelExpanded,
    required this.responsiveMode,
    required this.previewFileId,
    required this.keyboardPreviewFileId,
    required this.keyboardPreviewDirection,
    required this.onBreadcrumbPressed,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.onToggleSelection,
    required this.onToggleVisibleSelection,
    required this.onClearSelection,
    required this.onDeleteSelection,
    required this.onDownloadSelection,
    required this.onCreateFolder,
    required this.onCreateTextFile,
    required this.onUpload,
    required this.onFilesDropped,
    required this.onOpenRecentFiles,
    required this.onRoomPanelToggle,
    required this.onItemPressed,
    required this.onBrowseFolder,
    required this.onRemoveProcessingRow,
    required this.onLinkedThreadPressed,
    this.showRoomPanelControls = true,
    this.enableDropTarget = true,
    this.onAskAgent,
    this.onShare,
    this.onDownload,
    this.onRename,
    this.onDelete,
  });

  final String currentPath;
  final String Function(String path) folderLabelForPath;
  final List<PbFilesItemData> items;
  final Set<String> selectedIds;
  final PbFilesSortKey sortKey;
  final bool sortDirectionDescending;
  final TextEditingController filterController;
  final bool hasActiveFilter;
  final bool roomPanelExpanded;
  final PbFilesResponsiveMode responsiveMode;
  final String? previewFileId;
  final String? keyboardPreviewFileId;
  final int keyboardPreviewDirection;
  final ValueChanged<String> onBreadcrumbPressed;
  final ValueChanged<PbFilesSortKey> onSortChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onToggleVisibleSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelection;
  final VoidCallback onDownloadSelection;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateTextFile;
  final VoidCallback onUpload;
  final ValueChanged<List<String>> onFilesDropped;
  final VoidCallback onOpenRecentFiles;
  final VoidCallback onRoomPanelToggle;
  final ValueChanged<PbFilesItemData> onItemPressed;
  final ValueChanged<PbFilesItemData> onBrowseFolder;
  final ValueChanged<PbFilesItemData> onRemoveProcessingRow;
  final PbFilesLinkedThreadHandler onLinkedThreadPressed;
  final bool showRoomPanelControls;
  final bool enableDropTarget;
  final ValueChanged<PbFilesItemData>? onAskAgent;
  final ValueChanged<PbFilesItemData>? onShare;
  final ValueChanged<PbFilesItemData>? onDownload;
  final ValueChanged<PbFilesItemData>? onRename;
  final ValueChanged<PbFilesItemData>? onDelete;

  bool get _hasSelection => selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final sidePadding = responsiveMode == PbFilesResponsiveMode.docked
        ? const PbFilesPanelPadding(left: 30, right: 28)
        : const PbFilesPanelPadding(left: 20, right: 20);
    final dropTargetTop = responsiveMode == PbFilesResponsiveMode.mobile ? 202.0 : 142.0;

    final panel = Container(
      color: PbColors.surfacePanelWash,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PbFilesHeader(
            currentPath: currentPath,
            folderLabelForPath: folderLabelForPath,
            roomPanelExpanded: roomPanelExpanded,
            padding: sidePadding,
            showRoomPanelControls: showRoomPanelControls,
            onBreadcrumbPressed: onBreadcrumbPressed,
            onOpenRecentFiles: onOpenRecentFiles,
            onRoomPanelToggle: onRoomPanelToggle,
          ),
          PbFilesToolbar(
            hasSelection: _hasSelection,
            selectedCount: selectedIds.length,
            filterController: filterController,
            responsiveMode: responsiveMode,
            padding: sidePadding,
            onFilterChanged: onFilterChanged,
            onCreateFolder: onCreateFolder,
            onCreateTextFile: onCreateTextFile,
            onUpload: onUpload,
            onClearSelection: onClearSelection,
            onDeleteSelection: onDeleteSelection,
            onDownloadSelection: onDownloadSelection,
          ),
          Expanded(
            child: PbFilesTable(
              padding: sidePadding,
              items: items,
              selectedIds: selectedIds,
              sortKey: sortKey,
              sortDirectionDescending: sortDirectionDescending,
              previewFileId: previewFileId,
              keyboardPreviewFileId: keyboardPreviewFileId,
              keyboardPreviewDirection: keyboardPreviewDirection,
              hasActiveFilter: hasActiveFilter,
              onSortChanged: onSortChanged,
              onToggleSelection: onToggleSelection,
              onToggleVisibleSelection: onToggleVisibleSelection,
              onItemPressed: onItemPressed,
              onBrowseFolder: onBrowseFolder,
              onRemoveProcessingRow: onRemoveProcessingRow,
              onLinkedThreadPressed: onLinkedThreadPressed,
              onAskAgent: onAskAgent,
              onShare: onShare,
              onDownload: onDownload,
              onRename: onRename,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );

    if (!enableDropTarget) {
      return panel;
    }

    return PbFilesDropTargetLayer(dropTargetTop: dropTargetTop, padding: sidePadding, onFilesDropped: onFilesDropped, child: panel);
  }
}

final _initialFiles = List<PbFilesItemData>.unmodifiable([
  PbFilesItemData.fromFileName(
    id: 'launch-brief-gdoc',
    title: 'Launch brief.gdoc',
    thread: 'Launch planning',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: '10:24 AM',
    updatedSort: 202605261024,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'may-12-notes',
    title: 'May 12 notes.md',
    thread: 'Kickoff meeting',
    creator: 'Mina Lee',
    creatorInitials: 'ML',
    updatedLabel: 'May 12',
    updatedSort: 202605120910,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'q2-roadmap',
    title: 'Q2 roadmap.pdf',
    thread: 'Launch planning',
    linkedThreads: ['Launch planning', 'Open questions'],
    creator: 'Alex Kim',
    creatorInitials: 'AK',
    updatedLabel: 'May 11',
    updatedSort: 202605111525,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'agent-handoff',
    title: 'Agent handoff.md',
    thread: 'Open questions',
    creator: 'Parsa Rohani',
    creatorInitials: 'PR',
    updatedLabel: 'May 9',
    updatedSort: 202605091750,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'design-review',
    title: 'Design review.mov',
    thread: '',
    creator: 'Taylor Morgan',
    creatorInitials: 'TM',
    updatedLabel: 'May 9',
    updatedSort: 202605091115,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'spec-comments',
    title: 'Spec comments.txt',
    thread: 'Research review',
    creator: 'Taylor Morgan',
    creatorInitials: 'TM',
    updatedLabel: 'May 8',
    updatedSort: 202605081655,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'ops-checklist',
    title: 'Ops checklist.csv',
    thread: 'Open questions',
    creator: 'Parsa Rohani',
    creatorInitials: 'PR',
    updatedLabel: 'May 8',
    updatedSort: 202605080930,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'launch-screenshots',
    title: 'Launch screenshots.zip',
    thread: 'Launch planning',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: 'May 7',
    updatedSort: 202605071820,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'customer-notes',
    title: 'Customer notes.gsheet',
    thread: 'Open questions',
    linkedThreads: ['Open questions', 'Launch planning'],
    creator: 'Parsa Rohani',
    creatorInitials: 'PR',
    updatedLabel: 'Yesterday',
    updatedSort: 202605251700,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'roadmap-options',
    title: 'Roadmap options.gslides',
    thread: 'Launch planning',
    creator: 'Alex Kim',
    creatorInitials: 'AK',
    updatedLabel: 'Yesterday',
    updatedSort: 202605251500,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'meeting-transcript',
    title: 'Meeting transcript - May 12',
    type: 'Transcript',
    thread: 'Kickoff meeting',
    creator: 'Mina Lee',
    creatorInitials: 'ML',
    updatedLabel: 'May 12',
    updatedSort: 202605121630,
    parentPath: '',
  ),
  PbFilesItemData.fromFileName(
    id: 'market-analysis',
    title: 'Market analysis.pdf',
    thread: 'Research review',
    creator: 'Taylor Morgan',
    creatorInitials: 'TM',
    updatedLabel: 'May 10',
    updatedSort: 202605101145,
    parentPath: '',
  ),
  PbFilesItemData(
    id: 'design-references',
    title: 'Design references',
    type: 'Folder',
    thread: '',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: 'May 8',
    updatedSort: 202605081420,
    parentPath: '',
    folderPath: 'design-references',
    fileType: PbAttachmentFileType.folder,
    kind: PbFilesItemKind.folder,
  ),
  PbFilesItemData(
    id: 'blank-folder',
    title: 'Blank folder',
    type: 'Folder',
    thread: '',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: 'May 8',
    updatedSort: 202605081410,
    parentPath: '',
    folderPath: 'blank-folder',
    fileType: PbAttachmentFileType.folder,
    kind: PbFilesItemKind.folder,
  ),
  PbFilesItemData(
    id: 'brand-direction',
    title: 'Brand direction',
    type: 'Folder',
    thread: '',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: 'May 8',
    updatedSort: 202605081345,
    parentPath: 'design-references',
    folderPath: 'design-references/brand-direction',
    fileType: PbAttachmentFileType.folder,
    kind: PbFilesItemKind.folder,
  ),
  PbFilesItemData(
    id: 'research-screenshots',
    title: 'Research screenshots',
    type: 'Folder',
    thread: '',
    creator: 'Taylor Morgan',
    creatorInitials: 'TM',
    updatedLabel: 'May 7',
    updatedSort: 202605071640,
    parentPath: 'design-references',
    folderPath: 'design-references/research-screenshots',
    fileType: PbAttachmentFileType.folder,
    kind: PbFilesItemKind.folder,
  ),
  PbFilesItemData.fromFileName(
    id: 'moodboard-notes',
    title: 'Moodboard notes.gdoc',
    thread: 'Launch planning',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: 'May 7',
    updatedSort: 202605071220,
    parentPath: 'design-references',
  ),
  PbFilesItemData.fromFileName(
    id: 'color-references',
    title: 'Color references.png',
    thread: 'Launch planning',
    creator: 'Alex Kim',
    creatorInitials: 'AK',
    updatedLabel: 'May 6',
    updatedSort: 202605061030,
    parentPath: 'design-references',
  ),
  PbFilesItemData(
    id: 'hero-references',
    title: 'Hero references',
    type: 'Folder',
    thread: '',
    creator: 'Alex Kim',
    creatorInitials: 'AK',
    updatedLabel: 'May 6',
    updatedSort: 202605060915,
    parentPath: 'design-references/brand-direction',
    folderPath: 'design-references/brand-direction/hero-references',
    fileType: PbAttachmentFileType.folder,
    kind: PbFilesItemKind.folder,
  ),
  PbFilesItemData.fromFileName(
    id: 'launch-moodboard',
    title: 'Launch moodboard.gslides',
    thread: 'Launch planning',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: 'May 5',
    updatedSort: 202605051410,
    parentPath: 'design-references/brand-direction',
  ),
  PbFilesItemData(
    id: 'competitor-captures',
    title: 'Competitor captures',
    type: 'Folder',
    thread: '',
    creator: 'Taylor Morgan',
    creatorInitials: 'TM',
    updatedLabel: 'May 6',
    updatedSort: 202605061505,
    parentPath: 'design-references/research-screenshots',
    folderPath: 'design-references/research-screenshots/competitor-captures',
    fileType: PbAttachmentFileType.folder,
    kind: PbFilesItemKind.folder,
  ),
  PbFilesItemData.fromFileName(
    id: 'discovery-call-screenshots',
    title: 'Discovery call screenshots.png',
    thread: 'Research review',
    creator: 'Taylor Morgan',
    creatorInitials: 'TM',
    updatedLabel: 'May 6',
    updatedSort: 202605061245,
    parentPath: 'design-references/research-screenshots',
  ),
  PbFilesItemData.fromFileName(
    id: 'homepage-hero-stills',
    title: 'Homepage hero stills.png',
    thread: 'Launch planning',
    creator: 'Alex Kim',
    creatorInitials: 'AK',
    updatedLabel: 'May 4',
    updatedSort: 202605040935,
    parentPath: 'design-references/brand-direction/hero-references',
  ),
  PbFilesItemData.fromFileName(
    id: 'pricing-page-captures',
    title: 'Pricing page captures.png',
    thread: 'Research review',
    creator: 'Taylor Morgan',
    creatorInitials: 'TM',
    updatedLabel: 'May 5',
    updatedSort: 202605051605,
    parentPath: 'design-references/research-screenshots/competitor-captures',
  ),
]);
