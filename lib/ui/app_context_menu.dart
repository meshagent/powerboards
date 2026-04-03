import 'package:flutter/material.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/powerboards_menu_row.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppMenuEntry {
  const AppMenuEntry({
    required this.title,
    this.description,
    this.onPressed,
    this.icon,
    this.leading,
    this.selected = false,
    this.separatorBefore = false,
  });

  final String title;
  final String? description;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final bool selected;
  final bool separatorBefore;
}

class AppContextMenuButton extends StatefulWidget {
  const AppContextMenuButton({
    super.key,
    required this.entries,
    required this.childBuilder,
    this.anchor,
    this.boundaryContext,
    this.constraints = const BoxConstraints(minWidth: 320, maxWidth: 420),
    this.radius = 12,
    this.compact = false,
    this.maxMenuHeight,
    this.centerHorizontallyInBoundary = false,
  });

  final List<AppMenuEntry> entries;
  final Widget Function(BuildContext, ShadContextMenuController) childBuilder;
  final ShadAnchorBase? anchor;
  final BuildContext? boundaryContext;
  final BoxConstraints constraints;
  final double radius;
  final bool compact;
  final double? maxMenuHeight;
  final bool centerHorizontallyInBoundary;

  @override
  State<AppContextMenuButton> createState() => _AppContextMenuButtonState();
}

class _AppContextMenuButtonState extends State<AppContextMenuButton> {
  late final ShadContextMenuController controller = ShadContextMenuController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.compact ? _buildCompactItems(widget.entries) : _buildItems(widget.entries, radius: widget.radius);
    final menuContent = _buildMenuContent(items, maxMenuHeight: widget.maxMenuHeight);

    return AdaptiveShadContextMenu(
      controller: controller,
      anchor: widget.anchor,
      boundaryContext: widget.boundaryContext,
      constraints: widget.constraints,
      estimatedMenuWidth: _estimatedMenuWidth(widget.constraints),
      estimatedMenuHeight: _estimatedMenuHeight(widget.entries, compact: widget.compact, maxMenuHeight: widget.maxMenuHeight),
      centerHorizontallyInBoundary: widget.centerHorizontallyInBoundary,
      padding: widget.compact ? const EdgeInsets.symmetric(vertical: 4) : EdgeInsets.zero,
      decoration: widget.compact
          ? null
          : ShadDecoration(
              border: ShadBorder.all(color: const Color(0xFFE3E3E3), radius: BorderRadius.circular(widget.radius)),
            ),
      items: [menuContent],
      child: widget.childBuilder(context, controller),
    );
  }
}

double _estimatedMenuWidth(BoxConstraints constraints) {
  if (constraints.minWidth > 0) {
    return constraints.minWidth;
  }

  if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
    return constraints.maxWidth;
  }

  return 128;
}

double _estimatedMenuHeight(List<AppMenuEntry> entries, {required bool compact, double? maxMenuHeight}) {
  final entryCount = entries.length;
  if (entryCount <= 0) {
    return 0;
  }

  final extraSeparators = entries.where((entry) => entry.separatorBefore).length;

  final rawHeight = compact ? entryCount * 40.0 + extraSeparators * 13.0 : entryCount * 80.0 + (entryCount - 1) + extraSeparators * 13.0;

  if (maxMenuHeight == null) {
    return rawHeight;
  }

  return rawHeight.clamp(0.0, maxMenuHeight).toDouble();
}

Widget _buildMenuContent(List<Widget> items, {double? maxMenuHeight}) {
  Widget content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: items);

  if (maxMenuHeight == null) {
    return content;
  }

  return ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxMenuHeight),
    child: Scrollbar(thumbVisibility: true, child: SingleChildScrollView(child: content)),
  );
}

List<Widget> _buildCompactItems(List<AppMenuEntry> entries) {
  final out = <Widget>[];
  for (final e in entries) {
    if (e.separatorBefore && out.isNotEmpty) {
      out.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: ShadSeparator.horizontal(margin: EdgeInsets.zero),
        ),
      );
    }
    out.add(
      ShadContextMenuItem(
        height: 40,
        onPressed: e.onPressed,
        leading: e.leading ?? (e.icon != null ? Icon(e.icon, size: 16) : null),
        trailing: e.selected ? const Icon(LucideIcons.check, size: 16) : null,
        child: Text(e.title, overflow: TextOverflow.ellipsis),
      ),
    );
  }
  return out;
}

List<Widget> _buildItems(List<AppMenuEntry> entries, {required double radius}) {
  final out = <Widget>[];
  for (var i = 0; i < entries.length; i++) {
    if (entries[i].separatorBefore && out.isNotEmpty) {
      out.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: ShadSeparator.horizontal(margin: EdgeInsets.zero),
        ),
      );
    }
    out.add(_menuItem(entries[i], index: i, count: entries.length, radius: radius));
    if (i != entries.length - 1) {
      out.add(ShadSeparator.horizontal(margin: EdgeInsets.zero));
    }
  }
  return out;
}

Widget _menuItem(AppMenuEntry e, {required int index, required int count, required double radius}) {
  final r = Radius.circular(radius);
  final isFirst = index == 0;
  final isLast = index == count - 1;

  final itemRadius = BorderRadius.only(
    topLeft: isFirst ? r : Radius.zero,
    topRight: isFirst ? r : Radius.zero,
    bottomLeft: isLast ? r : Radius.zero,
    bottomRight: isLast ? r : Radius.zero,
  );

  final leadingWidget =
      e.leading ??
      (e.icon != null ? SizedBox(width: 32, height: 32, child: Icon(e.icon, size: 20)) : const SizedBox(width: 32, height: 32));

  return ShadContextMenuItem(
    padding: EdgeInsets.zero,
    height: powerboardsMenuRowHeight,
    onPressed: e.onPressed,
    decoration: ShadDecoration(border: ShadBorder.all(radius: itemRadius)),
    child: PowerboardsMenuRow(
      title: e.title,
      description: e.description,
      leading: leadingWidget,
      trailing: e.selected ? const Icon(LucideIcons.check, size: 21) : null,
    ),
  );
}
