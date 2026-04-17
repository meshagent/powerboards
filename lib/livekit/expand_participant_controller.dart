import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/powerboards_controller/powerboards_controller.dart';

class ExpandParticipantTarget {
  const ExpandParticipantTarget({required this.identity, required this.source});

  final String identity;
  final lk.TrackSource source;

  bool matches(String participantIdentity, lk.TrackSource participantSource) {
    return identity == participantIdentity && source == participantSource;
  }
}

class ExpandParticipantController extends Controller {
  ExpandParticipantTarget? _expandedTarget;

  void expand(String identity, lk.TrackSource source) {
    if (_expandedTarget?.matches(identity, source) == true) {
      return;
    }

    _expandedTarget = ExpandParticipantTarget(identity: identity, source: source);
    notifyListeners();
  }

  void expandCamera(String identity) {
    expand(identity, lk.TrackSource.camera);
  }

  void expandShare(String identity) {
    expand(identity, lk.TrackSource.screenShareVideo);
  }

  void collapse() {
    if (_expandedTarget == null) {
      return;
    }

    _expandedTarget = null;
    notifyListeners();
  }

  void toggle(String identity, lk.TrackSource source) {
    if (_expandedTarget?.matches(identity, source) == true) {
      collapse();
    } else {
      expand(identity, source);
    }
  }

  void toggleCamera(String identity) {
    toggle(identity, lk.TrackSource.camera);
  }

  void toggleShare(String identity) {
    toggle(identity, lk.TrackSource.screenShareVideo);
  }

  bool isExpanded(String identity, lk.TrackSource source) {
    return _expandedTarget?.matches(identity, source) == true;
  }

  bool isExpandedIdentity(String identity) {
    return _expandedTarget?.identity == identity;
  }

  ExpandParticipantTarget? get expandedTarget => _expandedTarget;

  bool get hasExpanded => _expandedTarget != null;
}
