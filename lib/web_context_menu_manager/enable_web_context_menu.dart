import 'package:flutter/material.dart';

class Coordinates {
  final double latitude;
  final double longitude;

  Coordinates(this.latitude, this.longitude);
}

class EnableWebContextRegistry {
  static final _registry = <UniqueKey, Rect>{};

  static void register(UniqueKey id, Rect rect) {
    _registry[id] = rect;
  }

  static void unregister(UniqueKey id) {
    _registry.remove(id);
  }

  static Iterable<Rect> get rects => _registry.values;
}

class EnableWebContextMenu extends StatefulWidget {
  const EnableWebContextMenu({super.key, required this.child});

  final Widget child;

  @override
  State createState() => _EnableWebContextMenuState();
}

class _EnableWebContextMenuState extends State<EnableWebContextMenu> with WidgetsBindingObserver {
  final key = GlobalKey();
  final id = UniqueKey();

  void getPosition(BuildContext context) {
    if (!mounted) return;

    final ctx = key.currentContext;
    if (ctx == null) return;

    final ro = ctx.findRenderObject();
    if (ro is! RenderBox) return;
    if (!ro.hasSize) return;

    final position = ro.localToGlobal(Offset.zero);
    final size = ro.size;
    final rect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

    EnableWebContextRegistry.register(id, rect);
  }

  void scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) => getPosition(context));
  }

  @override
  void initState() {
    super.initState();

    scheduleUpdate();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    scheduleUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    EnableWebContextRegistry.unregister(id);
    super.dispose();
  }

  @override
  Widget build(context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (notification) {
        getPosition(context);

        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            scheduleUpdate();

            return false;
          },
          child: Container(key: key, child: widget.child),
        ),
      ),
    );
  }
}
