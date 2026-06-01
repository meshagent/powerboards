import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import '../../theme/pb_typography.dart';
import '../layouts/pb_thread_header.dart';
import '../menus/pb_menu_anchor.dart';
import '../menus/pb_menu_card.dart';
import '../menus/pb_menu_filter_field.dart';
import '../menus/pb_menu_list.dart';
import '../menus/pb_menu_option.dart';
import '../primitives/pb_button.dart';
import '../primitives/pb_svg_icon.dart';
import 'pb_files_layout_values.dart';

class PbFilesHeader extends StatelessWidget {
  const PbFilesHeader({
    super.key,
    required this.currentPath,
    required this.folderLabelForPath,
    required this.roomPanelExpanded,
    required this.padding,
    this.showRoomPanelControls = true,
    required this.onBreadcrumbPressed,
    required this.onOpenRecentFiles,
    required this.onRoomPanelToggle,
  });

  final String currentPath;
  final String Function(String path) folderLabelForPath;
  final bool roomPanelExpanded;
  final PbFilesPanelPadding padding;
  final bool showRoomPanelControls;
  final ValueChanged<String> onBreadcrumbPressed;
  final VoidCallback onOpenRecentFiles;
  final VoidCallback onRoomPanelToggle;

  @override
  Widget build(BuildContext context) {
    final crumbs = _crumbs();

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: EdgeInsets.fromLTRB(padding.left, 19, padding.right, 19),
      child: Row(
        children: [
          Expanded(
            child: _FilesBreadcrumb(crumbs: crumbs, onPressed: onBreadcrumbPressed),
          ),
          if (showRoomPanelControls) const SizedBox(width: 24),
          if (showRoomPanelControls)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!roomPanelExpanded) PbThreadHeaderQuaternaryButton(label: 'Recently updated files', onPressed: onOpenRecentFiles),
                if (!roomPanelExpanded) const SizedBox(width: 6),
                PbThreadPanelToggle(expanded: roomPanelExpanded, onPressed: onRoomPanelToggle),
              ],
            ),
        ],
      ),
    );
  }

  List<_FilesCrumb> _crumbs() {
    if (currentPath.isEmpty) {
      return const [_FilesCrumb(label: 'Files', path: '')];
    }

    final parts = currentPath.split('/');
    var path = '';
    return [
      const _FilesCrumb(label: 'Files', path: ''),
      for (final part in parts) _FilesCrumb(label: folderLabelForPath(path = path.isEmpty ? part : '$path/$part'), path: path),
    ];
  }
}

class PbFilesToolbar extends StatelessWidget {
  const PbFilesToolbar({
    super.key,
    required this.hasSelection,
    required this.selectedCount,
    required this.filterController,
    required this.responsiveMode,
    required this.padding,
    required this.onFilterChanged,
    required this.onCreateFolder,
    required this.onCreateTextFile,
    required this.onUpload,
    required this.onClearSelection,
    required this.onDeleteSelection,
    required this.onDownloadSelection,
  });

  final bool hasSelection;
  final int selectedCount;
  final TextEditingController filterController;
  final PbFilesResponsiveMode responsiveMode;
  final PbFilesPanelPadding padding;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateTextFile;
  final VoidCallback onUpload;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelection;
  final VoidCallback onDownloadSelection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobileActions = responsiveMode == PbFilesResponsiveMode.mobile;
        final iconActions = constraints.maxWidth < 620 && !mobileActions;
        final createActions = _FilesCreateActions(
          iconActions: iconActions,
          fullWidth: mobileActions,
          onCreateFolder: onCreateFolder,
          onCreateTextFile: onCreateTextFile,
          onUpload: onUpload,
        );
        final filterField = PbMenuFilterField(
          placeholder: 'Filter...',
          height: PbSizes.buttonTertiaryHeight,
          margin: EdgeInsets.zero,
          controller: filterController,
          onChanged: onFilterChanged,
        );

        return Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 28),
          child: Transform.translate(
            offset: const Offset(0, -8),
            child: mobileActions
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasSelection)
                        _FilesSelectionActions(
                          selectedCount: selectedCount,
                          stretch: true,
                          showCount: false,
                          onDeleteSelection: onDeleteSelection,
                          onClearSelection: onClearSelection,
                          onDownloadSelection: onDownloadSelection,
                        )
                      else
                        createActions,
                      const SizedBox(height: 10),
                      if (hasSelection) _FilesSelectionCountRow(selectedCount: selectedCount) else filterField,
                    ],
                  )
                : Row(
                    children: [
                      if (hasSelection)
                        _FilesSelectionActions(
                          selectedCount: selectedCount,
                          onDeleteSelection: onDeleteSelection,
                          onClearSelection: onClearSelection,
                          onDownloadSelection: onDownloadSelection,
                        )
                      else
                        createActions,
                      const SizedBox(width: 10),
                      if (!hasSelection)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 220, maxWidth: 320), child: filterField),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _FilesCrumb {
  const _FilesCrumb({required this.label, required this.path});

  final String label;
  final String path;
}

double _menuWidthForLabels(
  BuildContext context,
  Iterable<String> labels, {
  double min = 220,
  double max = 420,
  TextStyle? style,
  double chrome = 96,
}) {
  final textStyle = style ?? PowerboardsTypography.labelSmall;
  final textDirection = Directionality.of(context);
  final longest = labels.fold<double>(0, (width, label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();

    return math.max(width, painter.width);
  });

  return (longest + chrome).clamp(min, max).toDouble();
}

class _FilesBreadcrumb extends StatefulWidget {
  const _FilesBreadcrumb({required this.crumbs, required this.onPressed});

  final List<_FilesCrumb> crumbs;
  final ValueChanged<String> onPressed;

  @override
  State<_FilesBreadcrumb> createState() => _FilesBreadcrumbState();
}

class _FilesBreadcrumbState extends State<_FilesBreadcrumb> {
  static const _layoutSlack = 2.0;

  bool _overflowOpen = false;

  void _closeOverflow() {
    if (_overflowOpen) {
      setState(() => _overflowOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crumbs = widget.crumbs;
        final current = crumbs.last;
        final layout = _resolveLayout(context, constraints.maxWidth, crumbs);

        return Row(
          children: [
            if (layout.hidden.isNotEmpty) ...[
              _FilesBreadcrumbOverflowButton(
                crumbs: layout.hidden,
                open: _overflowOpen,
                onOpenChanged: (open) => setState(() => _overflowOpen = open),
                onPressed: (path) {
                  _closeOverflow();
                  widget.onPressed(path);
                },
              ),
              const _FilesBreadcrumbSeparator(),
            ],
            for (final crumb in layout.visibleAncestors) ...[
              _FilesBreadcrumbButton(crumb: crumb, current: false, onPressed: widget.onPressed),
              const _FilesBreadcrumbSeparator(),
            ],
            _FilesBreadcrumbButton(crumb: current, current: true, onPressed: widget.onPressed),
          ],
        );
      },
    );
  }

  _FilesBreadcrumbLayout _resolveLayout(BuildContext context, double availableWidth, List<_FilesCrumb> crumbs) {
    if (crumbs.length <= 1 || availableWidth <= 0) {
      return const _FilesBreadcrumbLayout();
    }

    final current = crumbs.last;
    final visibleAncestors = crumbs.take(crumbs.length - 1).toList();
    if (_breadcrumbWidth(context, current: current, visibleAncestors: visibleAncestors, hiddenAncestors: const []) <= availableWidth) {
      return _FilesBreadcrumbLayout(visibleAncestors: visibleAncestors);
    }

    final hidden = <_FilesCrumb>[];
    while (visibleAncestors.isNotEmpty &&
        _breadcrumbWidth(context, current: current, visibleAncestors: visibleAncestors, hiddenAncestors: hidden) > availableWidth) {
      hidden.add(visibleAncestors.removeAt(0));
    }

    return _FilesBreadcrumbLayout(hidden: hidden, visibleAncestors: visibleAncestors);
  }

  double _breadcrumbWidth(
    BuildContext context, {
    required _FilesCrumb current,
    required List<_FilesCrumb> visibleAncestors,
    required List<_FilesCrumb> hiddenAncestors,
  }) {
    final separatorWidth = (visibleAncestors.length + (hiddenAncestors.isEmpty ? 0 : 1)) * 34;
    final overflowWidth = hiddenAncestors.isEmpty ? 0.0 : 28.0;
    final visibleWidth = visibleAncestors.fold<double>(0, (width, crumb) => width + _measureBreadcrumbLabel(context, crumb.label));

    return overflowWidth + separatorWidth + visibleWidth + _measureBreadcrumbLabel(context, current.label);
  }

  double _measureBreadcrumbLabel(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: PowerboardsTypography.h2),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return painter.width.ceilToDouble() + _layoutSlack;
  }
}

class _FilesBreadcrumbLayout {
  const _FilesBreadcrumbLayout({this.hidden = const [], this.visibleAncestors = const []});

  final List<_FilesCrumb> hidden;
  final List<_FilesCrumb> visibleAncestors;
}

class _FilesBreadcrumbOverflowButton extends StatelessWidget {
  const _FilesBreadcrumbOverflowButton({required this.crumbs, required this.open, required this.onOpenChanged, required this.onPressed});

  final List<_FilesCrumb> crumbs;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    final width = _menuWidthForLabels(context, crumbs.map((crumb) => crumb.label), min: 220, max: 420);

    return PbMenuAnchor(
      placement: PbMenuAnchorPlacement.bottomLeft,
      gap: 6,
      triggerHeight: 28,
      onDismiss: () => onOpenChanged(false),
      panel: open
          ? PbMenuCard(
              width: width,
              child: PbMenuList(
                children: [
                  for (final crumb in crumbs.reversed)
                    PbMenuOption(
                      title: crumb.label,
                      leadingIconAssetName: 'folder',
                      singleLine: true,
                      onPressed: () => onPressed(crumb.path),
                    ),
                ],
              ),
            )
          : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onOpenChanged(!open),
          child: const SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: PbSvgIcon(assetName: 'ellipsis', size: 18, color: PbColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilesBreadcrumbButton extends StatelessWidget {
  const _FilesBreadcrumbButton({required this.crumb, required this.current, required this.onPressed});

  final _FilesCrumb crumb;
  final bool current;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: current ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: current ? null : () => onPressed(crumb.path),
        child: Text(
          crumb.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: PowerboardsTypography.h2.copyWith(color: current ? PbColors.textPrimary : PbColors.textMuted),
        ),
      ),
    );
  }
}

class _FilesBreadcrumbSeparator extends StatelessWidget {
  const _FilesBreadcrumbSeparator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 34,
      child: Center(
        child: PbSvgIcon(assetName: 'chevron-right', size: 18, color: PbColors.textSubtle),
      ),
    );
  }
}

class _FilesCreateActions extends StatefulWidget {
  const _FilesCreateActions({
    required this.iconActions,
    required this.fullWidth,
    required this.onCreateFolder,
    required this.onCreateTextFile,
    required this.onUpload,
  });

  final bool iconActions;
  final bool fullWidth;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateTextFile;
  final VoidCallback onUpload;

  @override
  State<_FilesCreateActions> createState() => _FilesCreateActionsState();
}

class _FilesCreateActionsState extends State<_FilesCreateActions> {
  bool _createOpen = false;

  void _closeCreateMenu() {
    if (_createOpen) {
      setState(() => _createOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createButton = PbMenuAnchor(
      placement: PbMenuAnchorPlacement.bottomLeft,
      gap: 6,
      triggerHeight: PbSizes.buttonTertiaryHeight,
      onDismiss: _closeCreateMenu,
      panel: _createOpen
          ? PbMenuCard(
              width: 220,
              child: PbMenuList(
                children: [
                  PbMenuOption(
                    title: 'New folder',
                    leadingIconAssetName: 'folder-plus',
                    singleLine: true,
                    onPressed: () {
                      _closeCreateMenu();
                      widget.onCreateFolder();
                    },
                  ),
                  PbMenuOption(
                    title: 'New text file',
                    leadingIconAssetName: 'file-plus-corner',
                    singleLine: true,
                    onPressed: () {
                      _closeCreateMenu();
                      widget.onCreateTextFile();
                    },
                  ),
                ],
              ),
            )
          : null,
      child: _FilesToolbarButton(
        label: 'Create',
        iconAssetName: 'plus',
        iconOnly: widget.iconActions,
        fullWidth: widget.fullWidth,
        width: widget.fullWidth ? null : (widget.iconActions ? 48 : 132),
        contentOffset: widget.iconActions ? Offset.zero : const Offset(-3, 0),
        selected: _createOpen,
        onPressed: () => setState(() => _createOpen = !_createOpen),
      ),
    );
    final uploadButton = _FilesToolbarButton(
      label: 'Upload',
      iconAssetName: 'arrow-up-from-line',
      iconOnly: widget.iconActions,
      fullWidth: widget.fullWidth,
      width: widget.fullWidth ? null : (widget.iconActions ? 48 : 132),
      onPressed: widget.onUpload,
    );

    return Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.fullWidth) Expanded(child: createButton) else createButton,
        const SizedBox(width: 10),
        if (widget.fullWidth) Expanded(child: uploadButton) else uploadButton,
      ],
    );
  }
}

class _FilesSelectionActions extends StatelessWidget {
  const _FilesSelectionActions({
    required this.selectedCount,
    required this.onDeleteSelection,
    required this.onClearSelection,
    required this.onDownloadSelection,
    this.stretch = false,
    this.showCount = true,
  });

  final int selectedCount;
  final VoidCallback onDeleteSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onDownloadSelection;
  final bool stretch;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final deleteButton = _FilesToolbarButton(
      label: 'Delete',
      iconAssetName: 'trash-2',
      alert: true,
      fullWidth: stretch,
      onPressed: onDeleteSelection,
    );
    final clearButton = _FilesToolbarButton(
      label: 'Clear selection',
      iconAssetName: 'circle-x',
      fullWidth: stretch,
      onPressed: onClearSelection,
    );
    final downloadButton = _FilesToolbarButton(
      label: 'Download',
      iconAssetName: 'arrow-down-to-line',
      fullWidth: stretch,
      onPressed: onDownloadSelection,
    );
    final buttons = Row(
      mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (stretch) Expanded(child: deleteButton) else deleteButton,
        const SizedBox(width: 10),
        if (stretch) Expanded(child: clearButton) else clearButton,
        const SizedBox(width: 10),
        if (stretch) Expanded(child: downloadButton) else downloadButton,
        if (showCount) ...[const SizedBox(width: 18), Flexible(child: _FilesSelectionCountText(selectedCount: selectedCount))],
      ],
    );

    return stretch ? buttons : Flexible(child: buttons);
  }
}

class _FilesSelectionCountRow extends StatelessWidget {
  const _FilesSelectionCountRow({required this.selectedCount});

  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PbSizes.buttonTertiaryHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _FilesSelectionCountText(selectedCount: selectedCount),
      ),
    );
  }
}

class _FilesSelectionCountText extends StatelessWidget {
  const _FilesSelectionCountText({required this.selectedCount});

  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$selectedCount selected',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textPrimary),
    );
  }
}

class _FilesToolbarButton extends StatefulWidget {
  const _FilesToolbarButton({
    required this.label,
    this.iconAssetName,
    this.iconOnly = false,
    this.fullWidth = false,
    this.width,
    this.contentOffset = Offset.zero,
    this.alert = false,
    this.selected = false,
    this.onPressed,
  });

  final String label;
  final String? iconAssetName;
  final bool iconOnly;
  final bool fullWidth;
  final double? width;
  final Offset contentOffset;
  final bool alert;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<_FilesToolbarButton> createState() => _FilesToolbarButtonState();
}

class _FilesToolbarButtonState extends State<_FilesToolbarButton> {
  @override
  Widget build(BuildContext context) {
    if (widget.alert) {
      return _FilesAlertToolbarButton(
        label: widget.label,
        iconAssetName: widget.iconAssetName,
        fullWidth: widget.fullWidth,
        onPressed: widget.onPressed,
      );
    }

    final button = PbButton(
      iconAssetName: widget.iconAssetName,
      label: widget.label,
      variant: PbButtonVariant.primary,
      iconOnly: widget.iconOnly,
      iconOnlySize: PbSizes.buttonTertiaryHeight,
      height: widget.fullWidth ? 44 : PbSizes.buttonTertiaryHeight,
      horizontalPadding: widget.fullWidth ? 14 : 16,
      iconSize: 18,
      iconGap: 8,
      contentOffset: widget.contentOffset,
      onPressed: widget.onPressed,
    );

    return SizedBox(width: widget.width, child: button);
  }
}

class _FilesAlertToolbarButton extends StatefulWidget {
  const _FilesAlertToolbarButton({required this.label, this.iconAssetName, this.fullWidth = false, this.onPressed});

  final String label;
  final String? iconAssetName;
  final bool fullWidth;
  final VoidCallback? onPressed;

  @override
  State<_FilesAlertToolbarButton> createState() => _FilesAlertToolbarButtonState();
}

class _FilesAlertToolbarButtonState extends State<_FilesAlertToolbarButton> {
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
        child: Transform.translate(
          offset: Offset(0, active && !_pressed ? -1 : 0),
          child: AnimatedContainer(
            duration: PbMotion.state,
            height: widget.fullWidth ? 44 : PbSizes.buttonTertiaryHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: PbColors.customRose,
              borderRadius: BorderRadius.circular(PbRadii.small),
              border: Border.all(color: PbColors.customRose),
              boxShadow: _pressed
                  ? PbShadows.statePressedInset
                  : active
                  ? PbShadows.stateHover
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.iconAssetName != null) PbSvgIcon(assetName: widget.iconAssetName!, size: 18, color: PbColors.textInverse),
                if (widget.iconAssetName != null) const SizedBox(width: 8),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PowerboardsTypography.button.copyWith(color: PbColors.textInverse),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
