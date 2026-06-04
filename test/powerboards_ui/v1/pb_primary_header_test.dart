import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_primary_header.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';

void main() {
  testWidgets('desktop primary header honors workspace topbar height token', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: PbPrimaryHeader(shellMobile: false, shellIconOnly: false, roomValue: 'Product'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(PbPrimaryHeader)).height, greaterThanOrEqualTo(PbSizes.workspaceTopbarHeight));
  });
}
