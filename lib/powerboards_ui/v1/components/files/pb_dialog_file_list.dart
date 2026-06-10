import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_svg_icon.dart';

class PbDialogFileListItemData {
  const PbDialogFileListItemData({
    required this.id,
    required this.title,
    required this.iconAssetName,
    required this.iconColor,
    this.depth = 1,
    this.enabled = true,
    this.selectionEnabled = true,
  });

  final String id;
  final String title;
  final String iconAssetName;
  final Color iconColor;
  final int depth;
  final bool enabled;
  final bool selectionEnabled;
}

class PbDialogFileList extends StatefulWidget {
  const PbDialogFileList.unframed({
    super.key,
    required this.items,
    this.selectedIds = const {},
    this.showCheckboxes = false,
    this.onToggleSelection,
    this.onItemPressed,
  });

  final List<PbDialogFileListItemData> items;
  final Set<String> selectedIds;
  final bool showCheckboxes;
  final ValueChanged<String>? onToggleSelection;
  final ValueChanged<PbDialogFileListItemData>? onItemPressed;

  @override
  State<PbDialogFileList> createState() => _PbDialogFileListState();
}

class _PbDialogFileListState extends State<PbDialogFileList> {
  String? _hoveredId;
  String? _pressedId;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      primary: false,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final selected = widget.selectedIds.contains(item.id);
        final nextItem = index < widget.items.length - 1 ? widget.items[index + 1] : null;
        final previousSelected = index > 0 && widget.selectedIds.contains(widget.items[index - 1].id);
        final nextSelected = nextItem != null && widget.selectedIds.contains(nextItem.id);
        final nextInteractive =
            nextItem != null &&
            ((widget.onItemPressed != null && nextItem.enabled) || (widget.onToggleSelection != null && nextItem.selectionEnabled));
        final beforeActiveRow =
            nextSelected || (nextItem != null && _pressedId == nextItem.id) || (_hoveredId == nextItem?.id && nextInteractive);

        return _PbDialogFileListRow(
          item: item,
          selected: selected,
          pressed: _pressedId == item.id,
          hovered: _hoveredId == item.id,
          showCheckbox: widget.showCheckboxes,
          previousSelected: previousSelected,
          nextSelected: nextSelected,
          beforeActiveRow: beforeActiveRow,
          last: index == widget.items.length - 1,
          onHoverChanged: (isHovered) => setState(() {
            if (isHovered) {
              _hoveredId = item.id;
            } else if (_hoveredId == item.id) {
              _hoveredId = null;
            }
          }),
          onPressedChanged: (isPressed) => setState(() {
            if (isPressed) {
              _pressedId = item.id;
            } else if (_pressedId == item.id) {
              _pressedId = null;
            }
          }),
          onPressed: widget.onItemPressed == null || !item.enabled ? null : () => widget.onItemPressed!(item),
          checkboxEnabled: widget.showCheckboxes && item.selectionEnabled && widget.onToggleSelection != null,
          onToggleSelection: widget.onToggleSelection == null || !item.selectionEnabled ? null : () => widget.onToggleSelection!(item.id),
        );
      },
    );
  }
}

class _PbDialogFileListRow extends StatelessWidget {
  const _PbDialogFileListRow({
    required this.item,
    required this.selected,
    required this.pressed,
    required this.hovered,
    required this.showCheckbox,
    required this.previousSelected,
    required this.nextSelected,
    required this.beforeActiveRow,
    required this.last,
    required this.onHoverChanged,
    required this.onPressedChanged,
    required this.onPressed,
    required this.checkboxEnabled,
    required this.onToggleSelection,
  });

  final PbDialogFileListItemData item;
  final bool selected;
  final bool pressed;
  final bool hovered;
  final bool showCheckbox;
  final bool previousSelected;
  final bool nextSelected;
  final bool beforeActiveRow;
  final bool last;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<bool> onPressedChanged;
  final VoidCallback? onPressed;
  final bool checkboxEnabled;
  final VoidCallback? onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final interactive = onPressed != null || onToggleSelection != null;
    final stateful = selected || pressed;
    final effectiveHovered = hovered && interactive;
    final hideDivider = last || stateful || effectiveHovered || beforeActiveRow;

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: interactive ? (_) => onHoverChanged(true) : null,
      onExit: (_) {
        onHoverChanged(false);
        onPressedChanged(false);
      },
      child: Listener(
        onPointerDown: interactive ? (_) => onPressedChanged(true) : null,
        onPointerUp: interactive ? (_) => onPressedChanged(false) : null,
        onPointerCancel: interactive ? (_) => onPressedChanged(false) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed ?? onToggleSelection,
          child: Container(
            key: ValueKey('pb-dialog-file-list-row-${item.id}'),
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected || pressed ? PbColors.customStateSelectedSurface : null,
              gradient: effectiveHovered && !stateful
                  ? const LinearGradient(
                      colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              borderRadius: _selectionRadius(),
              border: Border.all(
                color: pressed || selected
                    ? PbColors.customStateSelectedBorder
                    : effectiveHovered
                    ? PbColors.borderSoft
                    : Colors.transparent,
              ),
              boxShadow: effectiveHovered && !stateful
                  ? PbShadows.stateHover
                  : pressed
                  ? PbShadows.statePressedInset
                  : null,
            ),
            foregroundDecoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: hideDivider ? Colors.transparent : PbColors.borderFaint)),
            ),
            child: Row(
              children: [
                if (showCheckbox) ...[
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: _DialogFileSelectionCheckbox(
                        checked: selected,
                        enabled: checkboxEnabled,
                        onPressed: onToggleSelection ?? () {},
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                SizedBox(width: ((item.depth - 1).clamp(0, 6)) * 18.0),
                PbSvgIcon(assetName: item.iconAssetName, size: 26, color: item.iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: PowerboardsTypography.button),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius _selectionRadius() {
    if (!selected) {
      return BorderRadius.circular((hovered && (onPressed != null || onToggleSelection != null)) || pressed ? 10 : 0);
    }
    if (!previousSelected && !nextSelected) {
      return BorderRadius.circular(10);
    }
    if (!previousSelected && nextSelected) {
      return const BorderRadius.vertical(top: Radius.circular(10));
    }
    if (previousSelected && !nextSelected) {
      return const BorderRadius.vertical(bottom: Radius.circular(10));
    }
    return BorderRadius.zero;
  }
}

class _DialogFileSelectionCheckbox extends StatelessWidget {
  const _DialogFileSelectionCheckbox({required this.checked, required this.enabled, required this.onPressed});

  final bool checked;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: PbMotion.state,
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: checked ? PbColors.customBrandInk : PbColors.surfacePanel,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: checked ? PbColors.customBrandInk : PbColors.borderSoft),
        ),
        alignment: Alignment.center,
        child: checked ? const PbSvgIcon(assetName: 'circle-check-big', size: 13, color: Colors.white) : null,
      ),
    );
  }
}
