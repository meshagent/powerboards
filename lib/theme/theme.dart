import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

const textScale = kIsWeb ? 1.0 : 1.2;
const headerHeight = 60.0;
const filledButtonColor = Color(0xFF7752FF);
const agentBackgroundColor = Colors.grey;
const toolIconColor = Color(0xFF47484A);
const disabledToolIconColor = Color(0xFFAAAAAA);

String timeAgo(DateTime d) {
  Duration diff = DateTime.now().difference(d);
  String ago;
  if (diff.inDays > 365) {
    ago = "${(diff.inDays / 365).floor()} ${(diff.inDays / 365).floor() == 1 ? "year" : "years"}";
  } else if (diff.inDays > 30) {
    ago = "${(diff.inDays / 30).floor()} ${(diff.inDays / 30).floor() == 1 ? "month" : "months"}";
  } else if (diff.inDays > 7) {
    ago = "${(diff.inDays / 7).floor()} ${(diff.inDays / 7).floor() == 1 ? "week" : "weeks"}";
  } else if (diff.inDays > 0) {
    ago = "${diff.inDays} ${diff.inDays == 1 ? "day" : "days"}";
  } else if (diff.inHours > 0) {
    ago = "${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"}";
  } else if (diff.inMinutes > 0) {
    ago = "${diff.inMinutes} ${diff.inMinutes == 1 ? "minute" : "minutes"}";
  } else if (diff.inDays < -365) {
    ago = "${(diff.inDays / 365).floor().abs()} ${(diff.inDays / 365).floor() == -1 ? "year" : "years"}";
  } else if (diff.inDays < -30) {
    ago = "${(diff.inDays / 30).floor().abs()} ${(diff.inDays / 30).floor() == -1 ? "month" : "months"}";
  } else if (diff.inDays < -7) {
    ago = "${(diff.inDays / 7).floor().abs()} ${(diff.inDays / 7).floor() == -1 ? "week" : "weeks"}";
  } else if (diff.inDays < 0) {
    ago = "${diff.inDays.abs()} ${diff.inDays == -1 ? "day" : "days"}";
  } else if (diff.inHours < 0) {
    ago = "${diff.inHours.abs()} ${diff.inHours == -1 ? "hour" : "hours"}";
  } else if (diff.inMinutes < 0) {
    ago = "${diff.inMinutes.abs()} ${diff.inMinutes == -1 ? "minute" : "minutes"}";
  } else {
    return "just now";
  }
  if (diff.inSeconds < 0) {
    return "in $ago";
  } else {
    return "$ago ago";
  }
}

final menuItemButtonStyle = ButtonStyle(
  textStyle: WidgetStatePropertyAll<TextStyle>(GoogleFonts.inter(fontSize: 14, color: Colors.black, letterSpacing: 0.4)),

  elevation: const WidgetStatePropertyAll(20),
);

class PowerboardsMenuStyle extends MenuStyle {
  PowerboardsMenuStyle({AlignmentGeometry? alignment})
    : super(
        shape: WidgetStateProperty.all<OutlinedBorder>(
          const RoundedRectangleBorder(
            side: BorderSide(color: Color(0xFFC8C8C8)),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
        surfaceTintColor: WidgetStateProperty.all<Color>(Colors.white),
        alignment: alignment ??= Alignment.bottomLeft,
      );
}

MenuStyle createMenuStyle() {
  return PowerboardsMenuStyle();
}

abstract class PowerboardsMenuItem extends StatefulWidget {
  const PowerboardsMenuItem({super.key});
}

class PowerboardsMenuButton extends StatefulWidget {
  const PowerboardsMenuButton({
    super.key,
    this.position,
    this.onOpen,
    this.onClose,
    this.style,
    required this.button,
    required this.itemBuilder,
  });

  final void Function()? onClose;
  final void Function()? onOpen;
  final Offset? position;
  final MenuStyle? style;
  final Widget button;
  final List<Widget> Function(BuildContext context) itemBuilder;

  @override
  State<StatefulWidget> createState() => _PowerboardsMenuButtonState();
}

class _PowerboardsMenuButtonState extends State<PowerboardsMenuButton> {
  List<Widget> items = [];

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: widget.style ?? createMenuStyle(),
      menuChildren: items,
      onOpen: widget.onOpen,
      onClose: widget.onClose,
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return MouseRegion(
          cursor: items.isEmpty ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (controller.isOpen) {
                controller.close();
              } else {
                items.clear();
                items.addAll(widget.itemBuilder(context));
                controller.open(position: widget.position);
              }
            },
            child: widget.button,
          ),
        );
      },
    );
  }
}

class PowerboardsMenuItemButton extends MenuItemButton implements PowerboardsMenuItem {
  PowerboardsMenuItemButton({super.key, super.onPressed, this.icon, int rotate = 0, bool iconOnRight = false, required Widget child})
    : super(
        style: menuItemButtonStyle,
        child: IgnorePointer(
          ignoring: onPressed == null,
          child: icon != null
              ? Row(
                  children: [
                    Expanded(child: child),
                    const SizedBox(width: 13),
                    RotatedBox(quarterTurns: rotate, child: Icon(icon, size: 19)),
                  ],
                )
              : child,
        ),
      );

  final IconData? icon;
}
