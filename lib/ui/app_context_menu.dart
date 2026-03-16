import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppMenuEntry {
  const AppMenuEntry({required this.title, this.description, this.onPressed, this.icon, this.leading, this.selected = false});

  final String title;
  final String? description;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final bool selected;
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
  });

  final List<AppMenuEntry> entries;
  final Widget Function(BuildContext, ShadContextMenuController) childBuilder;
  final ShadAnchorBase? anchor;
  final BuildContext? boundaryContext;
  final BoxConstraints constraints;
  final double radius;
  final bool compact;

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
    return AdaptiveShadContextMenu(
      controller: controller,
      anchor: widget.anchor,
      boundaryContext: widget.boundaryContext,
      constraints: widget.constraints,
      estimatedMenuWidth: _estimatedMenuWidth(widget.constraints),
      estimatedMenuHeight: _estimatedMenuHeight(widget.entries.length, compact: widget.compact),
      padding: widget.compact ? const EdgeInsets.symmetric(vertical: 4) : EdgeInsets.zero,
      decoration: widget.compact
          ? null
          : ShadDecoration(
              border: ShadBorder.all(color: const Color(0xFFE3E3E3), radius: BorderRadius.circular(widget.radius)),
            ),
      items: widget.compact ? _buildCompactItems(widget.entries) : _buildItems(widget.entries, radius: widget.radius),
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

double _estimatedMenuHeight(int entryCount, {required bool compact}) {
  if (entryCount <= 0) {
    return 0;
  }

  if (compact) {
    return entryCount * 40.0;
  }

  final separatorCount = entryCount - 1;
  return entryCount * 80.0 + separatorCount;
}

List<Widget> _buildCompactItems(List<AppMenuEntry> entries) {
  return entries
      .map(
        (e) => ShadContextMenuItem(
          height: 40,
          onPressed: e.onPressed,
          leading: e.leading ?? (e.icon != null ? Icon(e.icon, size: 16) : null),
          trailing: e.selected ? const Icon(LucideIcons.check, size: 16) : null,
          child: Text(e.title, overflow: TextOverflow.ellipsis),
        ),
      )
      .toList(growable: false);
}

List<Widget> _buildItems(List<AppMenuEntry> entries, {required double radius}) {
  final out = <Widget>[];
  for (var i = 0; i < entries.length; i++) {
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

  return ShadContextMenuItem.inset(
    padding: EdgeInsets.zero,
    leadingPadding: const .only(right: 14),
    insetPadding: const .symmetric(horizontal: 14, vertical: 0),
    height: 80,
    onPressed: e.onPressed,
    decoration: ShadDecoration(border: ShadBorder.all(radius: itemRadius)),
    leading: leadingWidget,
    trailing: e.selected ? const Icon(LucideIcons.check, size: 21) : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: e.description == null
          ? [
              Text(
                e.title,
                style: GoogleFonts.inter(fontSize: 16, height: 1.2, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ]
          : [
              Text(
                e.title,
                style: GoogleFonts.inter(fontSize: 16, height: 1.2, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                e.description!,
                style: GoogleFonts.inter(fontSize: 14, height: 1.2, fontWeight: FontWeight.w500, color: const Color(0xFF666666)),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
    ),
  );
}
