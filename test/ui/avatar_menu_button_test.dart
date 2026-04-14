import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';

void main() {
  group('userAvatarInitialsFontSize', () {
    test('keeps the known shared avatar sizes aligned', () {
      expect(userAvatarInitialsFontSize(userAvatarMenuDiameter), 8.5);
      expect(userAvatarInitialsFontSize(userAvatarStandardDiameter), 11.0);
      expect(userAvatarInitialsFontSize(userAvatarHeaderDiameter), 13.0);
    });

    test('uses a gentler scale for larger custom header avatars', () {
      expect(userAvatarInitialsFontSize(48.0), 14.5);
      expect(userAvatarInitialsFontSize(48.0), lessThan(48.0 * 0.35));
    });
  });
}
