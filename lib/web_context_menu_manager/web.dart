import 'dart:js_interop';
import 'package:web/web.dart' as html;
import 'package:flutter/widgets.dart';

import 'enable_web_context_menu.dart';

class WebContextMenuManager extends StatefulWidget {
  const WebContextMenuManager({super.key, required this.child});

  final Widget child;

  @override
  State createState() => _WebContextMenuManagerState();
}

class _WebContextMenuManagerState extends State<WebContextMenuManager> {
  late final JSFunction listener;

  void removeExistingCtxHandlers() {
    final fn = html.window['removeExistingCtxHandlers'] as JSFunction?;

    fn?.callAsFunction();
  }

  bool allowBrowserMenuForEvent(html.Event event) {
    final e = event as html.MouseEvent;
    final point = Offset(e.clientX.toDouble(), e.clientY.toDouble());

    for (final rect in EnableWebContextRegistry.rects) {
      if (rect.contains(point)) {
        return true;
      }
    }

    return false;
  }

  @override
  void initState() {
    super.initState();

    removeExistingCtxHandlers();

    listener = ((html.MouseEvent event) {
      if (!allowBrowserMenuForEvent(event)) {
        event.preventDefault();
      }
    }).toJS;

    html.document.addEventListener('contextmenu', listener, (html.AddEventListenerOptions(capture: true) as JSAny));
  }

  @override
  void dispose() {
    super.dispose();

    html.document.removeEventListener('contextmenu', listener, (html.EventListenerOptions(capture: true) as JSAny));
  }

  @override
  Widget build(context) => widget.child;
}
