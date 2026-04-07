import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/livekit/expand_participant_controller.dart';
import 'package:powerboards/livekit/room.dart';

const audioIconSize = 16.0;
const audioIconColor = Colors.white;
const _overlayElementShadows = [Shadow(color: Color(0xCC000000), blurRadius: 1.8, offset: Offset(0, 2))];
const textStyle = TextStyle(color: audioIconColor, fontSize: 11, fontWeight: .w500, shadows: _overlayElementShadows);
const _overlayPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
const _overlayBorderRadius = BorderRadius.all(Radius.circular(6));
const _unmutedOverlayColor = Colors.transparent;
const _mutedIconColor = Color(0xFFE84D5B);

bool _isMicrophoneEnabled(lk.Participant participant) {
  return participant.isMicrophoneEnabled();
}

class ParticipantOverlay extends StatefulWidget {
  const ParticipantOverlay({super.key, required this.participant, this.showName = true});

  final lk.Participant participant;
  final bool showName;

  @override
  State createState() => _ParticipantOverlayState();
}

class _ParticipantOverlayState extends State<ParticipantOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _microphoneDeviceAvailable = true;
  StreamSubscription<List<lk.MediaDevice>>? _deviceSubscription;

  @override
  void initState() {
    super.initState();

    const begin = 0.0;
    const end = 1.0;

    _animationController = AnimationController(
      value: widget.showName ? end : begin,
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    unawaited(_refreshMicrophoneAvailability());
    _deviceSubscription = lk.Hardware.instance.onDeviceChange.stream.listen(_updateMicrophoneAvailability);
  }

  @override
  void didUpdateWidget(covariant ParticipantOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showName != oldWidget.showName) {
      widget.showName ? _animationController.forward() : _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _animationController.dispose();

    super.dispose();
  }

  Future<void> _refreshMicrophoneAvailability() async {
    final devices = await lk.Hardware.instance.enumerateDevices();
    _updateMicrophoneAvailability(devices);
  }

  void _updateMicrophoneAvailability(List<lk.MediaDevice> devices) {
    final available = devices.any((device) => device.kind == "audioinput" && device.deviceId.isNotEmpty);
    if (!mounted || _microphoneDeviceAvailable == available) {
      return;
    }

    setState(() {
      _microphoneDeviceAvailable = available;
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomModel = VideoRoomModel.maybeOf(context);
    final pendingLocalMedia = roomModel?.pendingLocalMedia;

    return ListenableBuilder(
      listenable: Listenable.merge([widget.participant, if (pendingLocalMedia != null) pendingLocalMedia]),
      builder: (context, _) {
        final localParticipant = roomModel?.localParticipant;
        final isLocalParticipant =
            localParticipant != null &&
            (identical(localParticipant, widget.participant) ||
                localParticipant.sid == widget.participant.sid ||
                localParticipant.identity == widget.participant.identity);
        final microphonePending = isLocalParticipant && (pendingLocalMedia?.microphonePending ?? false);
        final microphoneUnavailable =
            isLocalParticipant && ((pendingLocalMedia?.microphoneUnavailable ?? false) || !_microphoneDeviceAvailable);
        final muted = !_isMicrophoneEnabled(widget.participant);
        final name = widget.participant.name;

        final expandController = Controller.ofType<ExpandParticipantController>(context);
        final expanded = expandController.isExpanded(widget.participant.identity);
        final iconColor = microphoneUnavailable ? _mutedIconColor : audioIconColor;

        return Container(
          decoration: BoxDecoration(borderRadius: _overlayBorderRadius, color: _unmutedOverlayColor),
          padding: _overlayPadding,
          child: Row(
            mainAxisSize: .min,
            mainAxisAlignment: .start,
            crossAxisAlignment: .center,
            children: [
              if (microphonePending)
                SizedBox(
                  width: audioIconSize,
                  height: audioIconSize,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(audioIconColor)),
                )
              else
                Icon(muted ? LucideIcons.micOff : LucideIcons.mic, color: iconColor, size: audioIconSize, shadows: _overlayElementShadows),

              if (name.isNotEmpty)
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Flexible(
                      child: SizedBox(
                        height: audioIconSize,
                        child: ClipRect(
                          child: Align(alignment: .centerLeft, widthFactor: _animation.value, child: child),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const .only(left: 1, right: 3),
                    child: Text(name, style: textStyle, overflow: .ellipsis),
                  ),
                ),

              Padding(
                padding: const .only(left: 2),
                child: ShadIconButton.ghost(
                  width: 20.0,
                  height: 20.0,
                  hoverBackgroundColor: Colors.transparent,
                  icon: Icon(
                    expanded ? LucideIcons.minimize2 : LucideIcons.expand,
                    color: audioIconColor,
                    size: 14,
                    shadows: _overlayElementShadows,
                  ),
                  onPressed: () {
                    expandController.toggle(widget.participant.identity);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
