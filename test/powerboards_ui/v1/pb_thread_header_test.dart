import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_thread_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';

void main() {
  Widget buildHarness({
    String agentName = 'voice',
    bool titleResolving = false,
    VoidCallback? onTitlePressed,
    VoidCallback? onOpenAllAgentsAndThreads,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 720,
          child: PbThreadHeader(
            title: 'Audio session',
            agentName: agentName,
            selectedThreadTitle: 'Audio session',
            titleResolving: titleResolving,
            onTitlePressed: onTitlePressed,
            onOpenAllAgentsAndThreads: onOpenAllAgentsAndThreads,
          ),
        ),
      ),
    );
  }

  Finder chevronIcon() {
    return find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'chevron-down');
  }

  testWidgets('thread title opens agents and threads without thread menu chrome', (tester) async {
    var openCount = 0;

    await tester.pumpWidget(buildHarness(onOpenAllAgentsAndThreads: () => openCount++));
    await tester.pump();

    expect(find.text('Audio session'), findsOneWidget);
    expect(find.text('Thread with'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Thread with Voice'), findsNothing);
    expect(chevronIcon(), findsNothing);

    await tester.tap(find.text('Audio session'));
    await tester.pumpAndSettle();

    expect(find.text('Filter...'), findsNothing);
    expect(find.text('New Thread'), findsNothing);
    expect(openCount, 1);
  });

  testWidgets('thread title falls back to title callback', (tester) async {
    var titlePressCount = 0;

    await tester.pumpWidget(buildHarness(onTitlePressed: () => titlePressCount++));
    await tester.pump();

    await tester.tap(find.text('Audio session'));
    await tester.pumpAndSettle();

    expect(titlePressCount, 1);
  });

  testWidgets('thread meta capitalizes multi-word agent display names', (tester) async {
    await tester.pumpWidget(buildHarness(agentName: 'research assistant'));
    await tester.pump();

    expect(find.text('Thread with'), findsOneWidget);
    expect(find.text('Research Assistant'), findsOneWidget);
    expect(find.text('research assistant'), findsNothing);
  });

  testWidgets('resolving thread title keeps title text in place', (tester) async {
    await tester.pumpWidget(buildHarness(titleResolving: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Audio session'), findsOneWidget);
    expect(find.text('Thread with'), findsOneWidget);
  });
}
