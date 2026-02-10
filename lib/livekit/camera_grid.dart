import 'dart:math';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'audio_stats.dart';
import 'participant_track.dart';
import 'room.dart';

List<int> _layoutCameras(List<TrackPublication?> cameras, double width, double height) {
  int N = cameras.length;
  List<int> bestLayout = [];
  double minWaste = double.infinity;

  // Loop over possible grid configurations
  for (int rows = 1; rows <= N; rows++) {
    // Calculate the number of columns needed for the current row configuration
    int cols = (N + rows - 1) ~/ rows; // Equivalent to ceil(N / rows)

    // Calculate the maximum camera width and height for the current configuration
    double aspectRatioWaste = 0;

    // Calculate total height for this row configuration, adjusting for each camera's aspect ratio
    for (int i = 0; i < N; i++) {
      final cam = cameras[i];

      final dims = cam == null ? const VideoDimensions(640, 480) : cam.dimensions;

      if (dims == null) {
      } else {
        double cameraAspectRatio = dims.width.toDouble() / dims.height.toDouble();

        // Calculate the ideal aspect ratio for the grid layout
        double gridAspectRatio = (width / cols) / (height / rows);

        // Add up aspect ratio waste for each camera
        aspectRatioWaste += (cameraAspectRatio - gridAspectRatio).abs();
      }
    }

    // Calculate how much space is wasted in this configuration
    double totalWaste = aspectRatioWaste;

    // If this layout is better than the previous one, update the best layout
    if (totalWaste < minWaste || bestLayout.isEmpty) {
      minWaste = totalWaste;
      bestLayout = [rows, cols];
    }
  }

  return bestLayout;
}

Widget cameraGridBuilder(
  BuildContext context,
  List<Participant> participants, {
  double spacing = 0.0,
  bool showNames = true,
  bool showAllVideos = false,
  int rowsDesired = 0,
  int columnsDesired = 0,
  bool tryFill = true,
  background = Colors.black,
  Widget Function(BuildContext context, Participant participant, VideoTrack? track, Widget child)? frameBuilder,
}) {
  final wrap = frameBuilder ?? (ctx, p, track, c) => c;

  final tracks = <Widget>[];
  final trackParticipants = <Participant>[];
  final trackSources = <VideoTrack?>[];
  final trackPublications = <TrackPublication?>[];
  final room = VideoRoomModel.maybeOf(context)?.room;

  if (room == null) {
    return const SizedBox.shrink();
  }

  final hasShare = participants.any(
    (p) => p.videoTrackPublications.any((t) => t.source == TrackSource.screenShareVideo && !t.muted && t.track != null),
  );
  TrackSource filterSource = hasShare ? TrackSource.screenShareVideo : TrackSource.camera;

  for (var p in participants) {
    var added = false;
    for (var t in p.videoTrackPublications) {
      if (t.kind == TrackType.VIDEO && !t.muted) {
        var track = t.track;
        if (track is VideoTrack && (track.source == filterSource || showAllVideos)) {
          added = true;
          trackParticipants.add(p);
          trackSources.add(track);
          trackPublications.add(t);
          tracks.add(
            IgnorePointer(
              child: VideoTrackRenderer(track, fit: t.source == TrackSource.screenShareVideo ? VideoViewFit.contain : VideoViewFit.cover),
            ),
          );
          break;
        }
      }
    }

    if (!hasShare && !added) {
      trackParticipants.add(p);
      trackSources.add(null);
      trackPublications.add(null);
      tracks.add(
        Container(
          color: Colors.grey,
          alignment: Alignment.center,
          child: p.identity.contains(".agent") ? AudioStats(room: room, participant: p) : const SizedBox(),

          // TimuObjectBuilder(
          //     url: '/api/graph/core:user/${p.identity}',
          //     builder: (context, user) => ProfileAvatar(profile: user as User, size: 100),
          // ),
        ),
      );
    }
  }

  final slots = tracks.length;
  if (slots == 0) {
    return Container(color: background);
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      if (rowsDesired == 0 && columnsDesired == 0) {
        final layout = _layoutCameras(trackPublications, constraints.maxWidth, constraints.maxHeight);
        List<Widget> cams = [];

        final rows = layout[0];
        final cols = layout[1];

        double w = constraints.maxWidth / cols;
        double h = constraints.maxHeight / rows;
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            final i = r * cols + c;

            if (i >= trackParticipants.length) {
              break;
            }
            final participant = trackParticipants[i];
            final source = trackSources[i];
            final track = tracks[i];

            cams.add(
              Positioned(
                left: c * w + spacing * c,
                top: r * h + spacing * r,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: wrap(context, participant, source, ParticipantTrack(showName: showNames, track: track, participant: participant)),
                ),
              ),
            );
          }
        }
        return Stack(children: cams);
      }

      var cams = <Widget>[];
      var x = 0.0;
      var y = 0.0;

      var slots = tracks.length;
      if (slots == 0) {
        return Container(color: background, width: constraints.biggest.width, height: constraints.biggest.width);
      }

      final objectWidth = constraints.biggest.width;
      final objectHeight = constraints.biggest.height;

      if (rowsDesired > 0 ||
          columnsDesired > 0 ||
          min(objectWidth / objectHeight, objectHeight / objectWidth) > .5 ||
          slots < 4 && tryFill) {
        int rows;
        int cols;

        if (objectWidth < objectHeight) {
          rows = (rowsDesired > 0 ? rowsDesired : (columnsDesired > 0 ? slots / columnsDesired : (sqrt(slots)).ceil())).toInt();
          cols = columnsDesired > 0 ? columnsDesired : (slots / (rows)).ceil();
        } else {
          cols = (columnsDesired > 0 ? columnsDesired : (rowsDesired > 0 ? slots / rowsDesired : (sqrt(slots)).ceil())).toInt();
          rows = rowsDesired > 0 ? rowsDesired : (slots / (cols)).ceil();
        }

        final w = objectWidth / cols + 1 - spacing * (cols - 1) / (cols);
        final h = objectHeight / rows - spacing * (rows - 1) / rows;

        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            int i = c + r * cols;
            if (i >= tracks.length) {
              continue;
            }
            final participant = trackParticipants[i];
            final track = tracks[i];
            final source = trackSources[i];

            cams.add(
              Positioned(
                left: c * w + spacing * c,
                top: r * h + spacing * r,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: wrap(context, participant, source, ParticipantTrack(showName: showNames, track: track, participant: participant)),
                ),
              ),
            );
          }
        }
      } else {
        final totalSpace = objectWidth * objectHeight;
        var rowUsedSpace = totalSpace;
        var rows = 1.0;
        var vertRows = false;

        for (var i = 1.0; i < 10; i += 0.1) {
          final itemSize = objectHeight / i;

          final usedSpace = itemSize * itemSize * max(slots, 1);

          final localSpace = usedSpace; //itemSize * itemSize * Math.ceil(slots/i) * i;

          // How much space is wasted? Use the layout that wastes the least.
          if (itemSize * (slots / (i).floor()).ceil() <= objectWidth &&
              itemSize * (i).floor() <= objectHeight &&
              localSpace <= totalSpace &&
              totalSpace - localSpace < rowUsedSpace) {
            rows = i;
            rowUsedSpace = totalSpace - localSpace;
            vertRows = true;
          }
        }

        for (var i = 1.0; i < 10; i += 0.1) {
          final itemSize = objectWidth / i;

          var usedSpace = itemSize * itemSize * max(slots, 1);
          var localSpace = usedSpace; //itemSize * itemSize * Math.ceil(slots/i) * i;

          // How much space is wasted? Use the layout that wastes the least.
          if (itemSize * (slots / (i).floor()).ceil() <= objectHeight &&
              itemSize * (i).floor() <= objectWidth &&
              localSpace <= totalSpace &&
              totalSpace - localSpace < rowUsedSpace) {
            rows = i;
            rowUsedSpace = totalSpace - localSpace;
            vertRows = false;
          }
        }

        if (vertRows) {
          final itemSize = (objectHeight - (spacing * rows * 1)) / rows;

          for (var i = 0; i < tracks.length; i++) {
            final track = tracks[i];
            final participant = trackParticipants[i];
            final source = trackSources[i];

            cams.add(
              Positioned(
                left: x,
                top: y,
                child: SizedBox(
                  width: itemSize,
                  height: itemSize,
                  child: wrap(context, participant, source, ParticipantTrack(showName: showNames, track: track, participant: participant)),
                ),
              ),
            );

            x += itemSize + spacing;

            if (x + itemSize > objectWidth) {
              x = spacing;
              y += itemSize + spacing;
            }
          } //);

          while (y < objectHeight) {
            x += itemSize + spacing;
            if (x + itemSize > objectWidth) {
              x = spacing;
              y += itemSize + spacing;
            }
          }
        } else {
          final itemSize = (objectWidth - (spacing * rows * 1)) / rows;

          for (var i = 0; i < tracks.length; i++) {
            final track = tracks[i];
            final participant = trackParticipants[i];
            final source = trackSources[i];

            cams.add(
              Positioned(
                left: x,
                top: y,
                child: SizedBox(
                  width: itemSize,
                  height: itemSize,
                  child: wrap(context, participant, source, ParticipantTrack(showName: showNames, track: track, participant: participant)),
                ),
              ),
            );

            y += itemSize + spacing;

            if (y + itemSize > objectHeight) {
              y = spacing;
              x += itemSize + spacing;
            }
          } //);

          while (x < objectWidth) {
            y += itemSize + spacing;
            if (y + itemSize > objectHeight) {
              y = spacing;
              x += itemSize + spacing;
            }
          }
        }
      }
      return Stack(children: cams);
    },
  );
}
