import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_agent_display.dart';

void main() {
  test('capitalizes each visible agent name word without changing the source value', () {
    expect(pbDisplayAgentName('assistant'), 'Assistant');
    expect(pbDisplayAgentName('voice agent'), 'Voice Agent');
    expect(pbDisplayAgentName('  QA assistant  '), 'QA Assistant');
  });
}
