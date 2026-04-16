import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:powerboards/meshagent/file_breadcrumb_layout.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const EdgeInsets powerboardsFileListRowPadding = EdgeInsets.fromLTRB(
  powerboardsMobileSecondaryRowLeadingInset,
  14,
  powerboardsMobileSecondaryRowTrailingInset,
  14,
);
const EdgeInsets powerboardsCompactFileListRowPadding = EdgeInsets.fromLTRB(
  powerboardsMobileSecondaryRowLeadingInset / 2,
  14,
  powerboardsMobileSecondaryRowTrailingInset / 2,
  14,
);
const double powerboardsFileListLeadingIconSize = 34.0;
const double powerboardsFileListLeadingGlyphSize = 24.0;
const double powerboardsFileListRowGap = 12.0;

TextStyle powerboardsFileListTitleStyle() {
  return powerboardsSecondaryTextStyle(color: shadForeground);
}

TextStyle powerboardsFileListMetadataStyle() {
  return powerboardsSecondaryTextStyle(color: shadMutedForeground);
}

IconData? powerboardsFileIconDataForEntry(StorageEntry entry) {
  if (entry.isFolder) return LucideIcons.folder;
  if (entry.name.endsWith('presentation')) return LucideIcons.presentation;
  if (entry.name.endsWith('document')) return LucideIcons.fileText;
  if (entry.name.endsWith('gallery')) return LucideIcons.image;

  return null;
}

Widget buildPowerboardsFileListIcon(BuildContext context, StorageEntry entry) {
  final iconData = powerboardsFileIconDataForEntry(entry);

  return SizedBox(
    width: powerboardsFileListLeadingIconSize,
    height: powerboardsFileListLeadingIconSize,
    child: iconData != null
        ? Center(
            child: Icon(
              iconData,
              size: powerboardsFileListLeadingGlyphSize,
              color: entry.isFolder ? ShadTheme.of(context).colorScheme.secondaryForeground : null,
            ),
          )
        : FileIcon(entry.name, size: powerboardsFileListLeadingIconSize),
  );
}

Widget buildPowerboardsFileBrowserTitleOnlyRow(BuildContext context, FileBrowserRowViewModel row) {
  return _buildPowerboardsFileBrowserTitleOnlyRow(context, row, padding: powerboardsFileListRowPadding);
}

Widget buildPowerboardsCompactFileBrowserTitleOnlyRow(BuildContext context, FileBrowserRowViewModel row) {
  return _buildPowerboardsFileBrowserTitleOnlyRow(context, row, padding: powerboardsCompactFileListRowPadding);
}

Widget _buildPowerboardsFileBrowserTitleOnlyRow(BuildContext context, FileBrowserRowViewModel row, {required EdgeInsets padding}) {
  final colorScheme = ShadTheme.of(context).colorScheme;
  final checkboxForeground = colorScheme.primaryForeground;
  final disabledFolder = row.entry.isFolder && !row.canActivate;
  final checkbox = row.canToggleSelection
      ? IgnorePointer(
          child: ShadCheckbox(
            decoration: ShadDecoration(border: ShadBorder.all(color: colorScheme.border)),
            value: row.selected,
            icon: row.selected ? Icon(LucideIcons.check, size: 14, weight: 3, color: checkboxForeground) : null,
            onChanged: (_) {},
          ),
        )
      : DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.muted,
            border: Border.all(color: colorScheme.muted),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const SizedBox(width: 16, height: 16),
        );

  final checkboxSlot = Opacity(
    opacity: row.canToggleSelection ? 1.0 : 0.9,
    child: SizedBox(width: 36, child: Center(child: checkbox)),
  );

  return Material(
    color: row.selected ? const Color(0xFFF2F1FF) : shadCard,
    child: InkWell(
      onTap: row.canActivate ? row.onPressed : null,
      child: Padding(
        padding: padding,
        child: Opacity(
          opacity: disabledFolder ? 0.5 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: row.canToggleSelection ? row.onToggleSelection : null,
                child: checkboxSlot,
              ),
              const SizedBox(width: 4),
              buildPowerboardsFileListIcon(context, row.entry),
              const SizedBox(width: powerboardsFileListRowGap),
              Expanded(
                child: Text(row.displayName, style: powerboardsFileListTitleStyle(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget buildPowerboardsFileListDivider(BuildContext context, int index) {
  return const Divider(height: 1, color: shadBorder);
}

Widget buildPowerboardsFileBrowserEmptyState(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text('Nothing to attach here', textAlign: TextAlign.center, style: powerboardsSectionTitleStyle()),
    ),
  );
}

Widget buildPowerboardsFileBrowserInsetHeader(BuildContext context, FileBrowserPathViewModel model, {double horizontalPadding = 24}) {
  return _PowerboardsFileBrowserInsetHeader(model: model, horizontalPadding: horizontalPadding);
}

class _PowerboardsFileBrowserInsetHeader extends StatefulWidget {
  const _PowerboardsFileBrowserInsetHeader({required this.model, required this.horizontalPadding});

  final FileBrowserPathViewModel model;
  final double horizontalPadding;

  @override
  State<_PowerboardsFileBrowserInsetHeader> createState() => _PowerboardsFileBrowserInsetHeaderState();
}

class _PowerboardsFileBrowserInsetHeaderState extends State<_PowerboardsFileBrowserInsetHeader> {
  final ShadContextMenuController _collapsedBreadcrumbMenuController = ShadContextMenuController();

  @override
  void dispose() {
    _collapsedBreadcrumbMenuController.dispose();
    super.dispose();
  }

  List<_PowerboardsHeaderSegment> _segments() {
    final rootLabel = widget.model.currentSelectionCount > 0 ? '${widget.model.currentSelectionCount} selected' : 'Browse';

    return [
      _PowerboardsHeaderSegment(label: rootLabel, onPressed: widget.model.onRootPressed, isRoot: true),
      for (final segment in widget.model.segments.indexed)
        _PowerboardsHeaderSegment(label: segment.$2, onPressed: () => widget.model.onSegmentPressed(segment.$1)),
    ];
  }

  TextStyle _rootLabelStyle(BuildContext context) {
    final theme = ShadTheme.of(context);
    return theme.textTheme.small.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary);
  }

  TextStyle _segmentLabelStyle() {
    return powerboardsSectionTitleStyle(color: shadMutedForeground);
  }

  double _measureLabelWidth(BuildContext context, String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  Widget _separator() {
    return const SizedBox(
      width: 20,
      child: Center(child: Icon(LucideIcons.chevronRight, size: 16, color: Color(0xffa5a5a5))),
    );
  }

  Widget _buildSegmentCrumb(_PowerboardsHeaderSegment segment) {
    final style = segment.isRoot ? _rootLabelStyle(context) : _segmentLabelStyle();
    return ShadButton.ghost(
      onPressed: segment.onPressed,
      child: Text(segment.label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildCurrentCrumb(_PowerboardsHeaderSegment segment) {
    final style = segment.isRoot ? _rootLabelStyle(context) : _segmentLabelStyle();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: segment.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(segment.label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _buildSelectionCountLabel() {
    final theme = ShadTheme.of(context);
    final controlHeight = theme.buttonSizesTheme.regular?.height ?? 40;

    return SizedBox(
      height: controlHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${widget.model.currentSelectionCount} selected',
            style: _rootLabelStyle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedMenu(List<_PowerboardsHeaderSegment> hiddenSegments) {
    return AdaptiveShadContextMenu(
      controller: _collapsedBreadcrumbMenuController,
      boundaryContext: context,
      verticalPosition: ShadMenuVerticalPosition.down,
      constraints: const BoxConstraints(minWidth: 200),
      estimatedMenuWidth: 200,
      estimatedMenuHeight: hiddenSegments.length * 40.0 + 8.0,
      items: hiddenSegments.reversed
          .map(
            (segment) => ShadContextMenuItem(
              height: 40,
              leading: Icon(segment.isRoot ? LucideIcons.files : LucideIcons.folder, size: 16),
              onPressed: segment.onPressed,
              child: Text(segment.isRoot ? 'Home' : segment.label),
            ),
          )
          .toList(growable: false),
      child: Tooltip(
        message: 'Browse collapsed path',
        child: ShadIconButton.ghost(icon: const Icon(LucideIcons.ellipsis, size: 18), onPressed: _collapsedBreadcrumbMenuController.toggle),
      ),
    );
  }

  Widget _buildBreadcrumbTrail(List<_PowerboardsHeaderSegment> segments) {
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(_separator());
      }
      children.add(_buildSegmentCrumb(segments[i]));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildCollapsedBreadcrumbTrail(List<_PowerboardsHeaderSegment> segments) {
    if (segments.length == 1) {
      return Row(children: [Expanded(child: _buildCurrentCrumb(segments.first))]);
    }

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(_separator());
      }

      if (i == segments.length - 1) {
        children.add(Expanded(child: _buildCurrentCrumb(segments[i])));
      } else {
        children.add(_buildSegmentCrumb(segments[i]));
      }
    }
    return Row(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final controlHeight = theme.buttonSizesTheme.regular?.height ?? 40;

    if (widget.model.currentSelectionCount > 0) {
      return Padding(
        padding: EdgeInsets.fromLTRB(widget.horizontalPadding, 10, widget.horizontalPadding, 8),
        child: _buildSelectionCountLabel(),
      );
    }

    final segments = _segments();
    final rootStyle = _rootLabelStyle(context);
    final segmentStyle = _segmentLabelStyle();

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.horizontalPadding, 10, widget.horizontalPadding, 8),
      child: SizedBox(
        height: controlHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const separatorWidth = 20.0;
            const crumbChromeWidth = 52.0;
            const collapseButtonWidth = 40.0;

            final segmentWidths = segments
                .map((segment) => _measureLabelWidth(context, segment.label, segment.isRoot ? rootStyle : segmentStyle) + crumbChromeWidth)
                .toList(growable: false);

            final layout = computeFileBreadcrumbLayout(
              segments: [for (final segment in segments) FileBreadcrumbSegment(label: segment.label, path: '')],
              segmentWidths: segmentWidths,
              maxWidth: constraints.maxWidth,
              separatorWidth: separatorWidth,
              collapseButtonWidth: collapseButtonWidth,
            );

            if (layout.isCollapsed) {
              final hidden = segments.take(layout.hiddenSegments.length).toList(growable: false);
              final visible = segments.skip(layout.hiddenSegments.length).toList(growable: false);
              return Row(
                children: [
                  _buildCollapsedMenu(hidden),
                  _separator(),
                  Expanded(child: _buildCollapsedBreadcrumbTrail(visible)),
                ],
              );
            }

            return _buildBreadcrumbTrail(segments);
          },
        ),
      ),
    );
  }
}

class _PowerboardsHeaderSegment {
  const _PowerboardsHeaderSegment({required this.label, required this.onPressed, this.isRoot = false});

  final String label;
  final VoidCallback onPressed;
  final bool isRoot;
}
