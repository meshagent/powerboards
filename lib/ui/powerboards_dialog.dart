import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:powerboards/modal_controller.dart';
import 'package:powerboards/popover.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';

/// A widget that provides an anchor point for dialogs to be displayed in the widget tree.
///
/// The dialogs are displayed using a [Stack] and the child widget is the first
/// item on the stack.
///
/// Use the [DialogController] to display and hide dialogs on the screen.
/// A [DialogController] can be provided, but if unspecified, one will be created.
/// The [DialogController] will be returned in the child builder.
/// The [DialogController] will be also placed into the context and can be retrieved using [Controller.ofType].
///
/// [DialogAnchor.child] can be optionally specified instead of the builder.
///
///
/// Example #1
/// How to use [DialogAnchor] builder
///
/// ```
/// class MyButton extends StatelessWidget{
///   const MyButton({super.key});
///   @override
///   Widget build(BuildContext context){
///     return DialogAnchor(builder: (context, controller){
///       return TextButton(
///         onPressed: (){
///           // The controller is also in the context and can be retrieved using Controller.ofType<DialogController>(context);
///           // The InfoDialog will automatically remove itself on close.
///           InfoDialog dialog = InfoDialog(
///             controller: controller,
///             title: "Hello",
///           );
///           controller.add(dialog);
///         },
///         child: const Text("Press Me!"),
///       );
///     });
///   }
/// }
///
/// ```
///
/// Example #2
/// How to use [DialogAnchor] without the builder.
///
/// ```
/// class Buttons extends StatelessWidget{
///   const Main({super.key});
///   @override
///   Widget build(BuildContext context){
///     return DialogAnchor(child: ButtonList());
///   }
/// }
///
/// class ButtonList extends StatelessWidget{
///   const ButtonList({super.key});
///   @override
///   Widget build(BuildContext context){
///     return DialogAnchor(child: ListTile(
///       title: 'Click Me',
///       onTap: (){
///           final controller = Controller.ofType<DialogController>(context);
///           // The InfoDialog will automatically remove itself on close.
///           InfoDialog dialog = InfoDialog(
///             controller: controller,
///             title: "Hello",
///           );
///           controller.add(dialog);
///       },
///     ));
///   }
/// }
/// ```
///
///
/// Example #3
/// How to use your own controller
///
/// class MyButton extends StatefulWidget {
///   const MyButton({super.key});
///
///   @override
///   State\<StatefulWidget\> createState() => MyButtonState();
/// }
///
/// class MyButtonState extends State\<MyButton\> {
///   final controller = DialogController();
///
///   @override
///   Widget build(BuildContext context){
///     return DialogAnchor(
///       controller: controller,
///       child: TextButton(
///         onPressed: (){
///           // The InfoDialog will automatically remove itself on close.
///           InfoDialog dialog = InfoDialog(
///             controller: controller,
///             title: "Hello",
///           );
///           controller.add(dialog);
///         },
///         child: const Text("Press Me!"),
///       )
///     );
///   }
/// }
///
/// ```
class DialogAnchor extends StatefulWidget {
  const DialogAnchor({super.key, this.controller, this.builder, this.child});
  final Widget? child;
  final Widget Function(BuildContext, DialogController controller)? builder;
  final DialogController? controller;

  @override
  State createState() {
    return _DialogAnchorState();
  }
}

class _DialogAnchorState extends State<DialogAnchor> {
  DialogController? _controller;
  final DialogController defaultController = DialogController();

  @override
  Widget build(BuildContext context) {
    _controller = widget.controller ?? defaultController;
    // Put the controller in the context.
    return ControllerBuilder<DialogController>(
      controller: _controller!,
      builder: (context) {
        // There must be a child or a builder.
        assert(widget.child != null || widget.builder != null);
        Widget? child = widget.child;
        // If the widget.child is null, then call the builder to get the child.
        child ??= widget.builder?.call(context, _controller!);
        return Stack(children: [child!, ..._controller!.items]);
      },
    );
  }
}

/// Show and hide dialogs. To work properly, the controller must be attached to a [DialogAnchor].
/// The dialog widget will be displayed at the point in the widget tree where the [DialogAnchor] is.
class DialogController extends Controller {
  DialogController();
  final List<Widget> items = [];

  void add(Widget widget) {
    items.add(widget);
    notifyListeners();
  }

  void remove(Widget widget) {
    items.remove(widget);
    notifyListeners();
  }
}

class PowerboardsPopover extends StatefulWidget {
  const PowerboardsPopover({
    super.key,
    required this.context,
    required this.onDismiss,
    this.backdropColor = Colors.black26,
    required this.builder,
    this.direction = PopoverDirection.bottom,
    this.transition = PopoverTransition.scale,
    this.transitionDuration = const Duration(milliseconds: 200),
    this.radius = 8,
    this.shadow = const [BoxShadow(color: Color(0x1F000000), blurRadius: 5)],
    this.arrowWidth = 0,
    this.arrowHeight = 0,
    this.arrowDxOffset = 0,
    this.arrowDyOffset = 0,
    this.contentDyOffset = 0,
    this.contentDxOffset = 0,
    this.width,
    this.height,
    this.constraints,
  });

  final Function onDismiss;
  final Color? backdropColor;
  final Widget Function(BuildContext) builder;
  final PopoverDirection direction;
  final PopoverTransition transition;
  final Duration transitionDuration;
  final double radius;
  final List<BoxShadow> shadow;
  final double arrowWidth;
  final double arrowHeight;
  final double arrowDxOffset;
  final double arrowDyOffset;
  final double contentDyOffset;
  final double contentDxOffset;
  final double? width;
  final double? height;
  final BuildContext context;
  final BoxConstraints? constraints;

  @override
  State<StatefulWidget> createState() => _PowerboardsPopoverState();
}

class _PowerboardsPopoverState extends State<PowerboardsPopover> {
  late OverlayPortalController controller;

  @override
  void initState() {
    super.initState();
    controller = OverlayPortalController();
    controller.show();
  }

  @override
  void dispose() {
    super.dispose();
    if (controller.isShowing) {
      controller.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final popover = PopoverItem(
      backgroundColor: widget.backdropColor,
      direction: widget.direction,
      radius: widget.radius,
      shadow: widget.shadow,
      arrowHeight: widget.arrowHeight,
      arrowWidth: widget.arrowWidth,
      constraints: widget.constraints,
      arrowDxOffset: widget.arrowDxOffset,
      arrowDyOffset: widget.arrowDyOffset,
      contentDxOffset: widget.contentDxOffset,
      contentDyOffset: widget.contentDyOffset,
      transition: widget.transition,
      width: widget.width,
      height: widget.height,
      context: widget.context,
      bodyBuilder: widget.builder,
    );

    return OverlayPortal(
      controller: controller,
      overlayChildBuilder: (context) {
        return DismissibleBarrier(
          onDismiss: () {
            widget.onDismiss.call();
          },
          key: Key('popover-backdrop-${widget.key}'),
          barrierColor: widget.backdropColor!,
          // The GestureDetector prevents click-through when the user clicks on widgets in the dialog.
          child: GestureDetector(onTap: () {}, child: popover),
        );
      },
    );
  }
}

/// An AutoOverlayPortal with a dismissable backdrop. Use the builder to return the dialog content.
class PowerboardsDialog extends StatefulWidget {
  const PowerboardsDialog({
    super.key,
    required this.builder,
    this.onDismiss,
    this.onEscape,
    this.backdropColor = Colors.black26,
    this.autofocus = false,
    this.padding,
  });

  /// The color of the backdrop.
  final Color? backdropColor;

  /// Called when the backdrop is clicked.
  final void Function()? onDismiss;

  /// Called when the dialog has the focus and the ESC key is pressed.
  final void Function()? onEscape;

  /// autofocus should only be set when nothing in the dialog requests focus.
  /// Again, do not turn on autofocus if a child Widget in the dialog is requesting focus.
  final bool autofocus;

  final EdgeInsets? padding;

  final Widget Function(BuildContext) builder;

  @override
  State createState() => PowerboardsDialogState();
}

/*

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final width = min(constraints.maxWidth - 40.0, 530.0);
      final height =
          min(constraints.maxHeight - 80.0, membersLength * 60.0 + 250.0);

      return mix.Box(
          style: Style(
            $box.width(width),
            $box.height(height),
            $box.color(theme.foreground),
            $box.decoration(
              color: Colors.white,
              border: Border.all(
                color: theme.borderColor,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                const BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.23),
                  offset: Offset(0, 2),
                  blurRadius: 20,
                ),
              ],
            ),
          ),

*/
class _DialogStyle extends StatelessWidget {
  const _DialogStyle({this.padding, required this.child});

  final EdgeInsets? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    final padding = this.padding ?? (isMobile ? const EdgeInsets.fromLTRB(16, 16, 16, 16) : const EdgeInsets.fromLTRB(27, 27, 27, 27));

    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.dialogTheme.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.23), offset: Offset(0, 2), blurRadius: 20)],
      ),
      child: child,
    );
  }
}

class _DialogBackdrop extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Color color;

  const _DialogBackdrop({required this.child, required this.onDismiss, this.color = Colors.black26});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(color: color, child: child),
    );
  }
}

class PowerboardsDialogState extends State<PowerboardsDialog> {
  @override
  Widget build(BuildContext context) {
    //final mediaQuery = MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(textScale));

    final BuildContext overlayContext = Overlay.of(context).context;

    return AutoOverlayPortal(
      overlayChildBuilder: (context) {
        return GestureDetector(
          onTap: widget.onDismiss,
          child: _DialogBackdrop(
            color: widget.backdropColor!,
            onDismiss: () {
              return widget.onDismiss?.call();
            },
            child: FocusScope(
              onKeyEvent: (n, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.escape) {
                    if (widget.onEscape == null) {
                      return KeyEventResult.ignored;
                    }
                    widget.onEscape?.call();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Align(
                alignment: kIsWeb ? Alignment.center : Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(
                    // top safe area
                    top: MediaQuery.of(overlayContext).viewPadding.top,
                    // keyboard safety
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  // Ensure gestures do not pass through the dialog.
                  child: GestureDetector(
                    onTap: () {},
                    child: _DialogStyle(
                      padding: widget.padding,
                      child: widget.autofocus ? Focus(autofocus: true, child: widget.builder(context)) : widget.builder(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AutoOverlayPortal extends StatefulWidget {
  const AutoOverlayPortal({super.key, required this.overlayChildBuilder, this.child});

  final Widget Function(BuildContext) overlayChildBuilder;
  final Widget? child;

  @override
  State createState() => _AutoOverlayPortalState();
}

class _AutoOverlayPortalState<T> extends State<AutoOverlayPortal> {
  late OverlayPortalController controller;

  @override
  void initState() {
    super.initState();
    controller = OverlayPortalController();
    controller.show();
  }

  @override
  void dispose() {
    super.dispose();
    if (controller.isShowing) {
      controller.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(controller: controller, overlayChildBuilder: widget.overlayChildBuilder, child: widget.child);
  }
}
