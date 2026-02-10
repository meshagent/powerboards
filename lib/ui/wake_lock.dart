import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart';

class WakeLock extends StatefulWidget {
  const WakeLock({super.key, required this.child});

  final Widget child;

  @override
  WakeLockState createState() => WakeLockState();
}

class WakeLockState extends State<WakeLock> {
  late Timer _wakeLockTimer;

  @override
  void initState() {
    super.initState();
    _wakeLockTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        if (kReleaseMode) {
          await WakelockPlus.enable();
        }
      } catch (err) {
        debugPrint('Failed to enable wake lock: $err');
      }
    });
  }

  @override
  void dispose() {
    _wakeLockTimer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
