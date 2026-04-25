import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/keyboard_safe.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double powerboardsMobileOverlayHeaderExpandedHeight = headerHeight;
const double powerboardsMobileOverlayHeaderCollapsedHeight = 48.0;
const double powerboardsMobileOverlayContentEdgeGap = 12.0;
const double powerboardsMobileOverlaySecondaryRowLift = 10.0;
const Duration powerboardsMobileOverlayHeaderTransitionDuration = Duration(milliseconds: 280);

double powerboardsMobileOverlayBodyTopPadding(BuildContext context, double collapseProgress) {
  final expandedTopPadding =
      powerboardsMobileOverlayHeaderExpandedHeight + powerboardsMobileOverlayContentEdgeGap - powerboardsMobileOverlaySecondaryRowLift;
  const collapsedTopPadding = powerboardsMobileOverlayHeaderCollapsedHeight;
  return ui.lerpDouble(expandedTopPadding, collapsedTopPadding, collapseProgress)!;
}

class PowerboardsMobileOverlayScaffold extends StatefulWidget {
  const PowerboardsMobileOverlayScaffold({
    super.key,
    required this.leading,
    required this.titleBuilder,
    required this.trailingActions,
    required this.body,
    required this.backgroundColor,
    this.scrollIdentity,
    this.titleAlignment = Alignment.center,
    this.collapseBodyWithHeader = true,
    this.bodyTopPaddingOffset = 0,
    this.restoreChromeAtMaxScrollExtent = false,
    this.collapseBottomSafeAreaWithHeader = true,
  });

  final Widget leading;
  final Widget Function(BuildContext context, double collapseProgress) titleBuilder;
  final List<Widget> trailingActions;
  final Widget body;
  final Color backgroundColor;
  final Object? scrollIdentity;
  final Alignment titleAlignment;
  final bool collapseBodyWithHeader;
  final double bodyTopPaddingOffset;
  final bool restoreChromeAtMaxScrollExtent;
  final bool collapseBottomSafeAreaWithHeader;

  @override
  State<PowerboardsMobileOverlayScaffold> createState() => _PowerboardsMobileOverlayScaffoldState();
}

class _PowerboardsMobileOverlayScaffoldState extends State<PowerboardsMobileOverlayScaffold> with SingleTickerProviderStateMixin {
  static const double _scrollableExtentThreshold = 0.5;
  static const double _scrollMinRestoreThreshold = 12.0;
  static const double _scrollMinCollapseThreshold = 24.0;
  static const double _scrollMaxRestoreThreshold = 64.0;
  static const double _scrollMaxCollapseThreshold = 96.0;

  late final AnimationController _scrollStateController = AnimationController(
    vsync: this,
    duration: powerboardsMobileOverlayHeaderTransitionDuration,
    reverseDuration: powerboardsMobileOverlayHeaderTransitionDuration,
  );
  late final Animation<double> _scrollStateAnimation = CurvedAnimation(
    parent: _scrollStateController,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic,
  );
  bool _hasScrollableExtent = false;
  bool _scrollChromeCollapsed = false;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    _syncScrollChromeState(notification.metrics);

    return false;
  }

  void _syncScrollChromeState(ScrollMetrics metrics) {
    final nextHasScrollableExtent = metrics.maxScrollExtent > _scrollableExtentThreshold;
    if (_hasScrollableExtent != nextHasScrollableExtent) {
      _hasScrollableExtent = nextHasScrollableExtent;
    }

    final minThreshold = _scrollChromeCollapsed ? _scrollMinRestoreThreshold : _scrollMinCollapseThreshold;
    final maxThreshold = _scrollChromeCollapsed ? _scrollMaxRestoreThreshold : _scrollMaxCollapseThreshold;
    final nearMinScrollExtent = metrics.pixels <= metrics.minScrollExtent + minThreshold;
    final nearMaxScrollExtent = widget.restoreChromeAtMaxScrollExtent && metrics.pixels >= metrics.maxScrollExtent - maxThreshold;
    final shouldCollapse = nextHasScrollableExtent && !nearMinScrollExtent && !nearMaxScrollExtent;
    _setScrollCollapsed(shouldCollapse);
  }

  void _setScrollCollapsed(bool collapsed) {
    if (_scrollChromeCollapsed == collapsed) {
      return;
    }

    _scrollChromeCollapsed = collapsed;
    if (collapsed) {
      _scrollStateController.forward();
    } else {
      _scrollStateController.reverse();
    }
  }

  void _restoreChrome() {
    _scrollChromeCollapsed = false;
    _scrollStateController.reverse();
  }

  @override
  void didUpdateWidget(covariant PowerboardsMobileOverlayScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollIdentity != widget.scrollIdentity) {
      _hasScrollableExtent = false;
      _scrollChromeCollapsed = false;
      if (_scrollStateController.value != 0) {
        _scrollStateController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _scrollStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardSafe(
      child: ColoredBox(
        color: widget.backgroundColor,
        child: AnimatedBuilder(
          animation: _scrollStateAnimation,
          builder: (context, _) {
            final collapseProgress = _scrollStateAnimation.value;
            final bodyTopPadding =
                powerboardsMobileOverlayBodyTopPadding(context, widget.collapseBodyWithHeader ? collapseProgress : 0) +
                widget.bodyTopPaddingOffset;
            final effectiveSafeAreaMinimum = EdgeInsets.only(
              top: powerboardsMobileScreenTopInset,
              bottom: widget.collapseBottomSafeAreaWithHeader
                  ? ui.lerpDouble(powerboardsMobileScreenBottomInset, 0, collapseProgress)!
                  : powerboardsMobileScreenBottomInset,
            );

            return SafeArea(
              bottom: !widget.collapseBottomSafeAreaWithHeader || collapseProgress < 0.1,
              minimum: effectiveSafeAreaMinimum,
              child: PowerboardsMobileOverlayHeaderScope(
                collapseProgress: collapseProgress,
                onRestoreChrome: _restoreChrome,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(top: bodyTopPadding),
                        child: NotificationListener<ScrollNotification>(onNotification: _handleScrollNotification, child: widget.body),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Builder(
                        builder: (context) => PowerboardsMobileOverlayHeader(
                          leading: widget.leading,
                          title: widget.titleBuilder(context, collapseProgress),
                          trailingActions: widget.trailingActions,
                          backgroundColor: widget.backgroundColor,
                          collapseProgress: collapseProgress,
                          titleAlignment: widget.titleAlignment,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PowerboardsMobileOverlayHeaderScope extends InheritedWidget {
  const PowerboardsMobileOverlayHeaderScope({
    super.key,
    required this.collapseProgress,
    required this.onRestoreChrome,
    required super.child,
  });

  final double collapseProgress;
  final VoidCallback onRestoreChrome;

  static PowerboardsMobileOverlayHeaderScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PowerboardsMobileOverlayHeaderScope>();
  }

  @override
  bool updateShouldNotify(PowerboardsMobileOverlayHeaderScope oldWidget) {
    return oldWidget.collapseProgress != collapseProgress || oldWidget.onRestoreChrome != onRestoreChrome;
  }
}

class PowerboardsMobileOverlayHeader extends StatelessWidget {
  const PowerboardsMobileOverlayHeader({
    super.key,
    required this.leading,
    required this.title,
    required this.trailingActions,
    required this.backgroundColor,
    required this.collapseProgress,
    this.titleAlignment = Alignment.center,
    this.horizontalInset = powerboardsMobileShellHorizontalInset,
  });

  final Widget leading;
  final Widget title;
  final List<Widget> trailingActions;
  final Color backgroundColor;
  final double collapseProgress;
  final Alignment titleAlignment;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final titleCollapseAlignment = Alignment.lerp(titleAlignment, Alignment.center, Curves.easeOut.transform(collapseProgress))!;
    final collapseCurve = Curves.easeInOutCubic.transform(collapseProgress);
    final headerHeight = ui.lerpDouble(
      powerboardsMobileOverlayHeaderExpandedHeight,
      powerboardsMobileOverlayHeaderCollapsedHeight,
      collapseProgress,
    )!;
    final blur = ui.lerpDouble(10, 18, collapseCurve)!;
    final topFadeStop = ui.lerpDouble(0.001, 0.32, collapseCurve)!;
    final solidStop = ui.lerpDouble(0.82, 0.58, collapseCurve)!;
    final topColor = Color.lerp(backgroundColor, powerboardsMobileGlassColor(backgroundColor, tint: 0.92, alpha: 0.82), collapseCurve)!;
    final middleColor = Color.lerp(backgroundColor, powerboardsMobileGlassColor(backgroundColor, tint: 0.74, alpha: 0.62), collapseCurve)!;
    final edgeColor = Color.lerp(backgroundColor, backgroundColor.withValues(alpha: 0), collapseCurve)!;
    final actionVisibility = 1 - Curves.easeOut.transform(collapseProgress);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [backgroundColor, topColor, middleColor, edgeColor],
              stops: [0.0, topFadeStop, solidStop, 1.0],
            ),
          ),
          child: SizedBox(
            height: headerHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalInset),
              child: Row(
                spacing: 8,
                children: [
                  _PowerboardsAnimatedHeaderAction(visibility: actionVisibility, child: leading),
                  Expanded(
                    child: Align(
                      alignment: titleCollapseAlignment,
                      child: DefaultTextStyle.merge(overflow: TextOverflow.ellipsis, maxLines: 1, child: title),
                    ),
                  ),
                  for (final action in trailingActions) _PowerboardsAnimatedHeaderAction(visibility: actionVisibility, child: action),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PowerboardsMobileHeaderTrigger extends StatelessWidget {
  const PowerboardsMobileHeaderTrigger({
    super.key,
    required this.primaryText,
    required this.collapseProgress,
    this.secondaryText,
    this.onPressed,
    this.showChevron = false,
    this.textAlign = TextAlign.center,
  });

  final String primaryText;
  final double collapseProgress;
  final String? secondaryText;
  final VoidCallback? onPressed;
  final bool showChevron;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isCentered = textAlign == TextAlign.center;
    final collapseCurve = Curves.easeOut.transform(collapseProgress);
    final contentAlignment = Alignment.lerp(isCentered ? Alignment.center : Alignment.centerLeft, Alignment.center, collapseCurve)!;
    final effectiveTextAlign = collapseCurve > 0.01 ? TextAlign.center : textAlign;
    final secondaryVisibility = Curves.easeOut.transform(1 - collapseProgress);
    final secondaryHeight = secondaryText == null ? 0.0 : ui.lerpDouble(14, 0, collapseProgress)!;
    final secondaryGap = secondaryText == null ? 0.0 : ui.lerpDouble(5, 0, collapseProgress)!;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Align(
        alignment: contentAlignment,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (secondaryText != null)
              SizedBox(
                height: secondaryHeight,
                child: Align(
                  alignment: contentAlignment,
                  child: Opacity(
                    opacity: secondaryVisibility,
                    child: Transform.translate(
                      offset: Offset(0, -6 * collapseProgress),
                      child: Text(
                        secondaryText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: effectiveTextAlign,
                        style: powerboardsMobileHeaderSecondaryTextStyle(color: theme.colorScheme.mutedForeground.withValues(alpha: 0.82)),
                      ),
                    ),
                  ),
                ),
              ),
            if (secondaryText != null) SizedBox(height: secondaryGap),
            Align(
              alignment: contentAlignment,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      primaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: effectiveTextAlign,
                      style: powerboardsMobileHeaderPrimaryTextStyle(color: theme.colorScheme.foreground),
                    ),
                  ),
                  if (showChevron) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(LucideIcons.chevronDown, size: 14, color: theme.colorScheme.mutedForeground.withValues(alpha: 0.82)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onPressed == null) {
      return content;
    }

    return _PowerboardsPressedOpacityButton(onPressed: onPressed!, child: content);
  }
}

class _PowerboardsPressedOpacityButton extends StatefulWidget {
  const _PowerboardsPressedOpacityButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_PowerboardsPressedOpacityButton> createState() => _PowerboardsPressedOpacityButtonState();
}

class _PowerboardsPressedOpacityButtonState extends State<_PowerboardsPressedOpacityButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }

    setState(() {
      _pressed = pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      opacity: _pressed ? powerboardsPressedOpacity : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onHighlightChanged: _setPressed,
          onTap: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}

class _PowerboardsAnimatedHeaderAction extends StatelessWidget {
  const _PowerboardsAnimatedHeaderAction({required this.visibility, required this.child});

  final double visibility;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: visibility < 0.1,
      child: ClipRect(
        child: Align(
          widthFactor: visibility,
          child: Opacity(
            opacity: visibility,
            child: Transform.translate(offset: Offset(0, -8 * (1 - visibility)), child: child),
          ),
        ),
      ),
    );
  }
}
