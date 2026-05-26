import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_thread_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';

void main() {
  Widget buildHarness({required bool threadMenuEnabled, String agentName = 'voice'}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 720,
          child: PbThreadHeader(
            title: 'Audio session',
            agentName: agentName,
            threads: const ['Planning'],
            selectedThreadTitle: 'Audio session',
            threadMenuEnabled: threadMenuEnabled,
          ),
        ),
      ),
    );
  }

  Finder chevronIcon() {
    return find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'chevron-down');
  }

  testWidgets('thread title hides chevron and menu when thread menu is disabled', (tester) async {
    await tester.pumpWidget(buildHarness(threadMenuEnabled: false));
    await tester.pump();

    expect(find.text('Audio session'), findsOneWidget);
    expect(find.text('with Voice'), findsOneWidget);
    expect(find.text('Thread with Voice'), findsNothing);
    expect(chevronIcon(), findsNothing);

    await tester.tap(find.text('Audio session'));
    await tester.pumpAndSettle();

    expect(find.text('Filter...'), findsNothing);
    expect(find.text('New Thread'), findsNothing);
  });

  testWidgets('thread title keeps chevron and menu when thread menu is enabled', (tester) async {
    await tester.pumpWidget(buildHarness(threadMenuEnabled: true));
    await tester.pump();

    expect(find.text('Thread with Voice'), findsOneWidget);
    expect(find.text('with Voice'), findsNothing);
    expect(chevronIcon(), findsOneWidget);

    await tester.tap(find.text('Audio session'));
    await tester.pumpAndSettle();

    expect(find.text('Filter...'), findsOneWidget);
    expect(find.text('New Thread'), findsOneWidget);
  });

  testWidgets('thread meta capitalizes multi-word agent display names', (tester) async {
    await tester.pumpWidget(buildHarness(threadMenuEnabled: true, agentName: 'research assistant'));
    await tester.pump();

    expect(find.text('Thread with Research Assistant'), findsOneWidget);
    expect(find.text('Thread with research assistant'), findsNothing);
  });
}
