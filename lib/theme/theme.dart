import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:shadcn_ui/shadcn_ui.dart";

const textScale = kIsWeb ? 1.0 : 1.2;
const headerHeight = 60.0;
const shadBackground = Color(0xFFF5F5F7);
const shadForeground = Color(0xFF222222);
const shadCard = Color(0xFFFFFFFF);
const shadCardForeground = Color(0xFF222222);
const shadPopover = Color(0xFFFFFFFF);
const shadPopoverForeground = Color(0xFF222222);
const shadPrimary = Color(0xFF222222);
const shadPrimaryForeground = Color(0xFFFFFFFF);
const shadSecondary = Color(0xFFF6F6F6);
const shadSecondaryForeground = Color(0xFF383838);
const shadMuted = Color(0xFFEFEFEF);
const shadMutedForeground = Color(0xFF666666);
const shadAccent = Color(0xFFEFEFEF);
const shadAccentForeground = Color(0xFF222222);
const shadDestructive = Color(0xFFE5484D);
const shadDestructiveForeground = Color(0xFFFFFFFF);
const shadBorder = Color(0xFFE3E3E3);
const shadInput = Color(0xFFFFFFFF);
const shadRing = Color(0xFF222222);
const shadSelection = Color(0xFFE3E3E3);
const statusError = shadDestructive;

const shadDarkBackground = Color(0xFF101012);
const shadDarkForeground = Color(0xFFF5F5F5);
const shadDarkCard = Color(0xFF161619);
const shadDarkCardForeground = Color(0xFFFAFAFA);
const shadDarkPopover = Color(0xFF1A1B1D);
const shadDarkPopoverForeground = Color(0xFFFAFAFA);
const shadDarkPrimary = Color(0xFF9A86F3);
const shadDarkPrimaryForeground = Color(0xFFFFFFFF);
const shadDarkSecondary = Color(0xFF212124);
const shadDarkSecondaryForeground = Color(0xFFE6E6E6);
const shadDarkMuted = Color(0xFF2A2A2D);
const shadDarkMutedForeground = Color(0xFFBCBCBC);
const shadDarkAccent = Color(0xFF4B3DB8);
const shadDarkAccentForeground = Color(0xFFC1B6FF);
const shadDarkDestructive = Color(0xFFC44D50);
const shadDarkDestructiveForeground = Color(0xFFFFFFFF);
const shadDarkBorder = Color(0xFF3A3A3C);
const shadDarkInput = Color(0xFF1D1E20);
const shadDarkRing = Color(0xFF9A86F3);
const shadDarkSelection = Color(0xFF473A77);

ShadColorScheme powerboardsShadColorScheme() {
  return ShadColorScheme.fromName("neutral").copyWith(
    background: shadBackground,
    foreground: shadForeground,
    card: shadCard,
    cardForeground: shadCardForeground,
    popover: shadPopover,
    popoverForeground: shadPopoverForeground,
    primary: shadPrimary,
    primaryForeground: shadPrimaryForeground,
    secondary: shadSecondary,
    secondaryForeground: shadSecondaryForeground,
    muted: shadMuted,
    mutedForeground: shadMutedForeground,
    accent: shadAccent,
    accentForeground: shadAccentForeground,
    destructive: shadDestructive,
    destructiveForeground: shadDestructiveForeground,
    border: shadBorder,
    input: shadInput,
    ring: shadRing,
    selection: shadSelection,
  );
}

ShadColorScheme powerboardsShadDarkColorScheme() {
  return ShadColorScheme.fromName("neutral").copyWith(
    background: shadDarkBackground,
    foreground: shadDarkForeground,
    card: shadDarkCard,
    cardForeground: shadDarkCardForeground,
    popover: shadDarkPopover,
    popoverForeground: shadDarkPopoverForeground,
    primary: shadDarkPrimary,
    primaryForeground: shadDarkPrimaryForeground,
    secondary: shadDarkSecondary,
    secondaryForeground: shadDarkSecondaryForeground,
    muted: shadDarkMuted,
    mutedForeground: shadDarkMutedForeground,
    accent: shadDarkAccent,
    accentForeground: shadDarkAccentForeground,
    destructive: shadDarkDestructive,
    destructiveForeground: shadDarkDestructiveForeground,
    border: shadDarkBorder,
    input: shadDarkInput,
    ring: shadDarkRing,
    selection: shadDarkSelection,
  );
}

ShadTextTheme powerboardsShadTextTheme() {
  final base = ShadTextTheme.fromGoogleFont(GoogleFonts.inter);

  return base.copyWith(
    h1Large: base.h1Large.copyWith(color: shadForeground),
    h1: base.h1.copyWith(color: shadForeground),
    h2: base.h2.copyWith(color: shadForeground),
    h3: base.h3.copyWith(color: shadForeground),
    h4: base.h4.copyWith(color: shadForeground),
    large: base.large.copyWith(color: shadForeground),
    lead: base.lead.copyWith(color: shadSecondaryForeground),
    p: base.p.copyWith(color: shadForeground),
    list: base.list.copyWith(color: shadSecondaryForeground),
    table: base.table.copyWith(color: shadSecondaryForeground),
    blockquote: base.blockquote.copyWith(color: shadSecondaryForeground),
    small: base.small.copyWith(color: shadSecondaryForeground),
    muted: base.muted.copyWith(color: shadMutedForeground),
  );
}

const filledButtonColor = shadPrimary;
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
