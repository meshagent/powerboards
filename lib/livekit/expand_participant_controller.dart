import 'package:powerboards/powerboards_controller/powerboards_controller.dart';

class ExpandParticipantController extends Controller {
  String? _expandedIdentity;

  void expand(String identity) {
    if (_expandedIdentity == identity) {
      return;
    }

    _expandedIdentity = identity;
    notifyListeners();
  }

  void collapse() {
    if (_expandedIdentity == null) {
      return;
    }

    _expandedIdentity = null;
    notifyListeners();
  }

  void toggle(String identity) {
    if (_expandedIdentity == identity) {
      collapse();
    } else {
      expand(identity);
    }
  }

  bool isExpanded(String identity) {
    return _expandedIdentity == identity;
  }

  bool get hasExpanded => _expandedIdentity != null;
}
