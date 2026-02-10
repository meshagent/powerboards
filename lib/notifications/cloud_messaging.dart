import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:powerboards/ui/powerboards_dialog.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';

class CloudMessaging extends StatefulWidget {
  const CloudMessaging({super.key, required this.navigatorKey, required this.child});

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<StatefulWidget> createState() {
    return CloudMessagingState();
  }
}

class CloudMessagingState extends State<CloudMessaging> {
  void _onMessageReceived(Map<String, dynamic> data) {
    debugPrint('Firebase message received: $data');
  }

  void _onMessageInteracted(Map<String, dynamic> data, BuildContext context) {
    // final controller = Controller.ofType<DialogController>(context);

    final url = data["url"];
    if (url != null) {
      try {
        Uri uri = Uri.parse(url);
        String pathAndQuery = uri.path + (uri.query.isNotEmpty ? "?${uri.query}" : "");

        if (!pathAndQuery.startsWith("/")) {
          throw const FormatException("Path must start with '/'");
        }

        widget.navigatorKey.currentContext?.go(pathAndQuery);
      } catch (e) {
        debugPrint('url error: $e');

        // InfoDialog dialog = InfoDialog(controller: controller, title: 'Error', content: const Text('Could not open content'));
        // controller.add(dialog);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogAnchor(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: FirebaseListener(
              onMessageReceived: _onMessageReceived,
              onMessageInteracted: (data) => _onMessageInteracted(data, context),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class FirebaseListener extends StatefulWidget {
  const FirebaseListener({super.key, this.onMessageReceived, this.onMessageInteracted});

  final Function(Map<String, dynamic>)? onMessageReceived;
  final Function(Map<String, dynamic>)? onMessageInteracted;

  @override
  FirebaseListenerState createState() => FirebaseListenerState();
}

class FirebaseListenerState extends State<FirebaseListener> {
  // static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  String? previousAccessToken;

  Future<void> _init() async {
    var settings = await FirebaseMessaging.instance.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _initToken();
      await _initMessages();
    }
  }

  Future<void> _initToken() async {
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(_handleToken);

    const maxRetries = 3;
    const Duration retryDelay = Duration(seconds: 3);
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        final token = await FirebaseMessaging.instance.getToken(vapidKey: const String.fromEnvironment("FIREBASE_VAPID_KEY"));
        _handleToken(token);
        return;
      } catch (err) {
        attempt++;
        // rethrow the error if we are at the max retry limit.
        if (attempt >= maxRetries) rethrow;
        debugPrint('An error occured while attempting to get the firebase token $err');
        await Future.delayed(retryDelay);
      }
    }
  }

  Future<void> _initMessages() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: false, sound: true);

    // handle any message arriving while app is in foreground
    _messageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleMessageReceived(message);
    });

    // handle any message interaction (ie notification tap)
    _messageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageInteracted);

    // get any message which caused the application to open from a terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessageInteracted(initialMessage);
    }
  }

  void _handleToken(String? token) {
    DeviceTokenManager().setDeviceToken(token);
    _register();
  }

  Future<void> _register() async {
    final token = DeviceTokenManager().getDeviceToken();
    if (token != null) {
      // final api = TimuApiProvider.of(context).api;

      // if (api.accessToken.isNotEmpty) {
      //   final name = await _getDeviceName();
      //   try {
      //     await api.registerDevice(name: name, token: token);
      //   } catch (err) {
      //     debugPrint("Failed to register for push notifications: $err");
      //   }
      // }
    }
  }

  /*
  Future<String> _getDeviceName() async {
    final info = await _deviceInfoPlugin.deviceInfo;
    return info.data["name"] ??
        info.data["display"] ??
        info.data["userAgent"] ??
        info.data["product"] ??
        info.data["device"] ??
        (kIsWeb ? "web" : "mobile");
  }
  */

  void _handleMessageReceived(RemoteMessage message) {
    widget.onMessageReceived?.call(message.data);
  }

  void _handleMessageInteracted(RemoteMessage message) {
    widget.onMessageInteracted?.call(message.data);
  }

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      if (kReleaseMode || const bool.fromEnvironment("FIREBASE_INITIALIZE")) {
        _init();
      }
    }
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageOpenedAppSub?.cancel();
    _messageSub?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class DeviceTokenManager {
  static final DeviceTokenManager _instance = DeviceTokenManager._internal();

  String? _deviceToken;

  factory DeviceTokenManager() {
    return _instance;
  }

  DeviceTokenManager._internal();

  void setDeviceToken(String? token) {
    _deviceToken = token;
  }

  String? getDeviceToken() {
    return _deviceToken;
  }
}
