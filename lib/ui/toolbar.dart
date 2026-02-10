import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/theme/theme.dart';

enum ToolbarDirection { horizontal, vertical }

const _toolbarBorderColor = Color(0xffcccccc);

class Toolbar extends InheritedWidget {
  Toolbar({super.key, required this.direction, required List<Widget> children}) : super(child: _ToolbarContents(children));

  final ToolbarDirection direction;

  @override
  bool updateShouldNotify(covariant Toolbar oldWidget) {
    return oldWidget.direction != oldWidget.direction;
  }
}

List<Widget> _addSpacer(List<Widget> widgets) {
  final List<Widget> ret = [];

  for (final entry in widgets.asMap().entries) {
    final int i = entry.key;

    if (i > 0) {
      ret.add(const SizedBox(width: 8, height: 8));
    }
    ret.add(entry.value);
  }

  return ret;
}

class _ToolbarContents extends StatelessWidget {
  _ToolbarContents(List<Widget> childrens) : children = _addSpacer(childrens);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Toolbar toolbar = context.dependOnInheritedWidgetOfExactType<Toolbar>()!;

    if (toolbar.direction == ToolbarDirection.horizontal) {
      return Container(
        height: 64.0, // in logical pixels
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(color: _toolbarBorderColor, strokeAlign: BorderSide.strokeAlignOutside),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x19000000), blurRadius: 10, offset: Offset(0, 6))],
          color: const Color(0x00ffffff),
        ),
        child: Row(children: children),
      );
    } else {
      return Container(
        width: 64.0, // in logical pixels
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(color: _toolbarBorderColor, strokeAlign: BorderSide.strokeAlignOutside),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x19000000), blurRadius: 10, offset: Offset(0, 6))],
          color: const Color(0xffffffff),
        ),
        child: Column(children: children),
      );
    }
  }
}

/// Occasionally, we will need to render separators between the widgets, these
/// can be rendered using a ToolbarSeparator widget. The widget should not
/// contain any padding, but should respect the the current toolbar orientation
/// to know whether it should render according to the height or width
/// constraint. Use a LayoutBuilder to retrieve this constraint.
class ToolbarSeparator extends StatelessWidget {
  const ToolbarSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.hasBoundedWidth) {
          return const Divider(color: Color.fromRGBO(78, 74, 144, 1), height: 24, thickness: 1);
        } else {
          return const VerticalDivider(color: Color.fromRGBO(78, 74, 144, 1), width: 24, thickness: 1);
        }
      },
    );
  }
}

/// the ToolbarButton should also respect the
/// horizontal or vertical constraint provided by the toolbar depending on
/// the orientation.

/// The major difference between the buttons is simply
/// the background color and hover states of the buttons.

/// The content of
/// the button should be provided as a widget child, which could be an
/// icon, text, or another type of widget. The button should center its
/// contents, and have a minimum width that matches the constrained
/// dimension of the button so that buttons with a single icon or character
/// glyph are square.

/// The button should also have the proper amount of
/// internal padding such that if text is added to the button which causes
/// it to grow along the primary axis of the toolbar, the text has equal
/// padding between its top, left, right, and bottom edges.

class ToolbarButton extends StatelessWidget {
  const ToolbarButton({this.onPressed, this.onLongPress, this.child, super.key});

  final VoidCallback? onLongPress;
  final VoidCallback? onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onLongPress: onLongPress,
      onPressed: onPressed,
      style: ButtonStyle(
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0))),
        padding: WidgetStateProperty.all(const EdgeInsets.all(5)),
        minimumSize: WidgetStateProperty.all(const Size.square(32.0)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: child,
    );
  }
}

class ToolbarClickable extends StatefulWidget {
  const ToolbarClickable({
    super.key,
    this.active = false,
    this.primary = false,
    required this.tooltip,
    this.unconstrained = false,
    required this.child,
  });

  final String tooltip;
  final Widget child;
  final bool active;
  final bool primary;
  final bool unconstrained;

  @override
  State createState() => _ToolbarClickableState();
}

class _ToolbarClickableState extends State<ToolbarClickable> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    bool primary = widget.primary;
    final theme = Theme.of(context).iconButtonTheme.style;
    final hoverColor = (theme?.backgroundColor?.resolve({WidgetState.hovered}) ?? filledButtonColor.withAlpha(100));
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: primary && !widget.active ? Border.all(color: const Color.fromARGB(0xff, 0xAD, 0xB9, 0xC8)) : null,
        borderRadius: primary ? BorderRadius.circular(100) : BorderRadius.circular(2),
        color: widget.active
            ? widget.primary
                  ? Colors.black
                  : (theme?.foregroundColor?.resolve({}) ?? toolIconColor)
            : (hovered ? hoverColor : Colors.transparent),
      ),
      child: Tooltip(
        showDuration: Duration.zero,
        waitDuration: const Duration(seconds: 2),
        message: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() {
            hovered = true;
          }),
          onExit: (_) => setState(() {
            hovered = false;
          }),
          child: widget.child,
        ),
      ),
    );
  }
}

class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton(
    this.icon, {
    this.onPressed,
    super.key,
    this.active = false,
    this.primary = false,
    this.color,
    required this.tooltip,
    this.child,
  });

  final String tooltip;
  final void Function()? onPressed;
  final IconData? icon;
  final bool active;
  final Widget? child;
  final Color? color;

  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return ToolbarClickable(
      tooltip: tooltip,
      active: active,
      primary: primary,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) Icon(icon, size: primary ? 20 : 22, color: color ?? (active ? Colors.white : (colorScheme.primary))),
              if (child != null)
                DefaultTextStyle(
                  style: TextStyle(color: active ? Colors.white : (colorScheme.primary)),
                  child: child!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToolbarSimpleButton extends StatelessWidget {
  const ToolbarSimpleButton({
    this.onPressed,
    super.key,
    this.active = false,
    this.primary = false,
    this.color,
    required this.tooltip,
    required this.child,
  });

  final String tooltip;
  final void Function()? onPressed;
  final bool active;
  final Widget? child;
  final Color? color;

  final bool primary;

  @override
  Widget build(BuildContext context) {
    return ToolbarClickable(
      tooltip: tooltip,
      active: active,
      primary: primary,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DefaultTextStyle(
                style: TextStyle(color: active ? Colors.white : toolIconColor),
                child: child!,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToggleToolbarButton extends ToolbarButton {
  const ToggleToolbarButton({this.on = false, super.onPressed, super.onLongPress, super.child, super.key});

  final bool on;

  @override
  Widget build(BuildContext context) {
    if (on) {
      return FilledButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: FilledButton.styleFrom(
          elevation: 0,
          enableFeedback: false,
          surfaceTintColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          padding: const EdgeInsets.all(5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          minimumSize: const Size.square(32.0),
          textStyle: const TextStyle(color: Color(0xffffffff)),
          backgroundColor: const Color(0xff7752FF),
        ),
        child: child,
      );
    } else {
      return FilledButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: FilledButton.styleFrom(
          elevation: 0,
          enableFeedback: false,
          surfaceTintColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          padding: const EdgeInsets.all(5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          minimumSize: const Size.square(32.0),
          textStyle: const TextStyle(color: Color(0xffffffff)),
          backgroundColor: Colors.transparent,
        ),
        child: child,
      );
    }
  }
}

class EmphasizedToolbarButton extends ToolbarButton {
  const EmphasizedToolbarButton({super.onPressed, super.child, super.key});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFFED6464)),
        textStyle: WidgetStateProperty.all(const TextStyle(color: Color(0xffffffff))),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0))),
        padding: WidgetStateProperty.all(const EdgeInsets.all(5)),
        minimumSize: WidgetStateProperty.all(const Size.square(32.0)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: child,
    );
  }
}
