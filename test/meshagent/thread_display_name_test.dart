import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/thread_display_name.dart';

void main() {
  test('thread file display name omits the .thread extension', () {
    expect(threadFileDisplayNameFromPath('/threads/release-plan.thread'), 'Release Plan');
  });

  test('thread file display name strips the extension from explicit display names', () {
    expect(threadFileDisplayNameFromPath('/threads/release-plan.thread', threadDisplayName: 'Release Plan.thread'), 'Release Plan');
  });

  test('thread file names derived from display names restore the .thread extension once', () {
    expect(threadFileNameFromDisplayName('Release Plan'), 'Release Plan.thread');
    expect(threadFileNameFromDisplayName('Release Plan.thread'), 'Release Plan.thread');
  });
}
