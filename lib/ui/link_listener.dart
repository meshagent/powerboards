import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:powerboards/powerboards_router/powerboards_router.dart';

import 'package:app_links/app_links.dart';

final appLinks = AppLinks();

class LinksWatcher extends StatefulWidget {
  const LinksWatcher({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State createState() => _LinksWatcherState();
}

class _LinksWatcherState extends State<LinksWatcher> {
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) return;

    sub = appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri == null) return;

        final pathAndQuery = uri.path + (uri.query.isNotEmpty ? "?${uri.query}" : "");

        widget.navigatorKey.currentContext?.go(pathAndQuery);
      },
      onError: (err) {
        debugPrint('Error receiving URI: $err');
      },
    );
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
