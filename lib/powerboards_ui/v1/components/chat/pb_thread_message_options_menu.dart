import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import '../menus/pb_menu_anchor.dart';
import '../menus/pb_menu_card.dart';
import '../menus/pb_menu_list.dart';
import '../menus/pb_menu_option.dart';
import '../primitives/pb_svg_icon.dart';

class PbThreadMessageOptionsMenu extends StatefulWidget {
  const PbThreadMessageOptionsMenu({super.key, required this.onCopy, required this.onSaveCopyAs, required this.onMenuOpenChanged});

  final VoidCallback onCopy;
  final VoidCallback? onSaveCopyAs;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  State<PbThreadMessageOptionsMenu> createState() => _PbThreadMessageOptionsMenuState();
}

class _PbThreadMessageOptionsMenuState extends State<PbThreadMessageOptionsMenu> {
  bool _open = false;

  void _setOpen(bool open) {
    if (_open == open) {
      return;
    }

    setState(() => _open = open);
    widget.onMenuOpenChanged(open);
  }

  void _copyMessage() {
    _setOpen(false);
    widget.onCopy();
  }

  void _saveCopyAsMessage() {
    _setOpen(false);
    widget.onSaveCopyAs?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PbMenuAnchor(
      placement: PbMenuAnchorPlacement.bottomRight,
      gap: 8,
      triggerWidth: 30,
      triggerHeight: 30,
      onDismiss: () => _setOpen(false),
      panel: _open
          ? PbMenuCard(
              width: 220,
              child: PbMenuList(
                children: [
                  PbMenuOption(title: 'Copy', leadingIconAssetName: 'clipboard-copy', singleLine: true, onPressed: _copyMessage),
                  if (widget.onSaveCopyAs != null)
                    PbMenuOption(
                      title: 'Save a copy as...',
                      leadingIconAssetName: 'folder-symlink',
                      singleLine: true,
                      onPressed: _saveCopyAsMessage,
                    ),
                ],
              ),
            )
          : null,
      child: _PbThreadMessageActionButton(selected: _open, onPressed: () => _setOpen(!_open)),
    );
  }
}

class PbThreadAttachmentOptionsMenu extends StatefulWidget {
  const PbThreadAttachmentOptionsMenu({
    super.key,
    required this.mine,
    required this.onOpen,
    required this.onDownload,
    required this.onSaveCopyAs,
    required this.onMenuOpenChanged,
  });

  final bool mine;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onSaveCopyAs;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  State<PbThreadAttachmentOptionsMenu> createState() => _PbThreadAttachmentOptionsMenuState();
}

class _PbThreadAttachmentOptionsMenuState extends State<PbThreadAttachmentOptionsMenu> {
  bool _open = false;

  void _setOpen(bool open) {
    if (_open == open) {
      return;
    }

    setState(() => _open = open);
    widget.onMenuOpenChanged(open);
  }

  void _run(VoidCallback action) {
    _setOpen(false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return PbMenuAnchor(
      placement: widget.mine ? PbMenuAnchorPlacement.bottomRight : PbMenuAnchorPlacement.bottomLeft,
      gap: 8,
      triggerWidth: 30,
      triggerHeight: 30,
      onDismiss: () => _setOpen(false),
      panel: _open
          ? PbMenuCard(
              width: 220,
              child: PbMenuList(
                children: [
                  PbMenuOption(
                    title: 'Open',
                    leadingIconAssetName: 'arrow-up-right',
                    singleLine: true,
                    onPressed: () => _run(widget.onOpen),
                  ),
                  PbMenuOption(
                    title: 'Download',
                    leadingIconAssetName: 'arrow-down-to-line',
                    singleLine: true,
                    onPressed: () => _run(widget.onDownload),
                  ),
                  PbMenuOption(
                    title: 'Save a copy as...',
                    leadingIconAssetName: 'folder-symlink',
                    singleLine: true,
                    onPressed: () => _run(widget.onSaveCopyAs),
                  ),
                ],
              ),
            )
          : null,
      child: _PbThreadMessageActionButton(selected: _open, onPressed: () => _setOpen(!_open)),
    );
  }
}

class _PbThreadMessageActionButton extends StatefulWidget {
  const _PbThreadMessageActionButton({required this.selected, required this.onPressed});

  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_PbThreadMessageActionButton> createState() => _PbThreadMessageActionButtonState();
}

class _PbThreadMessageActionButtonState extends State<_PbThreadMessageActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _pressed;

    return Tooltip(
      message: 'More',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          child: AnimatedContainer(
            duration: active ? Duration.zero : PbMotion.state,
            curve: Curves.easeOut,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active
                  ? PbColors.surfaceStateSelected
                  : _hovered
                  ? PbColors.surfaceAccentSoft
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(PbRadii.small),
            ),
            alignment: Alignment.center,
            child: PbSvgIcon(
              assetName: 'ellipsis',
              size: 17,
              color: PbColors.customBrandInk.withValues(alpha: _hovered || active ? 0.62 : 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
