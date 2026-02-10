import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:siri_wave/siri_wave.dart';
import 'package:webrtc_interface/webrtc_interface.dart' as webrtc;

import 'package:powerboards/theme/hues.dart';
import 'package:powerboards/theme/theme.dart';

class AudioStats extends StatefulWidget {
  const AudioStats({super.key, required this.room, required this.participant, this.alignment = Alignment.center});

  final Room room;
  final Participant participant;
  final Alignment alignment;

  @override
  State createState() => _AudioStatsState();
}

class _AudioStatsState extends State<AudioStats> {
  late Timer timer;
  double audioLevel = 0;
  List<webrtc.StatsReport>? statsReport;

  bool thinking = true;
  bool listening = false;
  bool hasReceivedLevels = false;
  late IOS7SiriWaveformController controller;

  @override
  void initState() {
    super.initState();

    controller = IOS7SiriWaveformController();
    controller.amplitude = 1.0;
    controller.color = agentBackgroundColor;

    timer = Timer.periodic(const Duration(milliseconds: 1000 ~/ 30), onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onParticipantUpdated();
      });
    });

    widget.participant.addListener(onParticipantUpdated);
  }

  @override
  void dispose() {
    super.dispose();

    widget.participant.removeListener(onParticipantUpdated);
    timer.cancel();
  }

  void onParticipantUpdated() {
    if (mounted) {
      setState(() {
        thinking = widget.participant.attributes["lk.agent.state"] == "thinking";
        listening = widget.participant.attributes["listening"] == "true";

        if (!widget.participant.isSpeaking) {
          controller.amplitude = .2;
          controller.speed = 0.05;
          controller.frequency = 1;
          controller.color = darken(listening ? Colors.lightBlue : agentBackgroundColor, 25);
        } else {
          controller.amplitude = audioLevel;
          controller.frequency = 6;
          controller.speed = 0.2;
          controller.color = Colors.white;
        }
      });
    }
  }

  void onTick(Timer t) async {
    final track = widget.participant.audioTrackPublications.where((x) => !x.muted).firstOrNull?.track;

    final receiver = (track as AudioTrack?)?.receiver;

    final stats = await receiver?.getStats();

    if (stats != null) {
      statsReport = stats;
      for (var stat in stats) {
        if (stat.type == "inbound-rtp") {
          final levels = stat.values["audioLevel"];
          if (levels != null) {
            if (mounted) {
              setState(() {
                if (!thinking) {
                  audioLevel = (levels as num).toDouble();
                  controller.amplitude = audioLevel;
                }
                hasReceivedLevels = true;
              });
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: agentBackgroundColor),
      child: Stack(
        children: [
          Align(
            alignment: widget.alignment,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 90,
                  child: Opacity(
                    opacity: hasReceivedLevels ? 1 : 0.1,
                    child: SiriWaveform.ios7(controller: controller),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
