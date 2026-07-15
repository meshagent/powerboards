import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_comment_box.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';

void main() {
  testWidgets('comment box migrates idle, hover, and focus surfaces', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              child: PbCommentBox(controller: controller, focusNode: focusNode, placeholder: 'Ask Assistant...'),
            ),
          ),
        ),
      ),
    );

    BoxDecoration decoration() => tester.widget<Container>(find.byKey(const ValueKey('comment-box'))).decoration! as BoxDecoration;

    expect(decoration().boxShadow, PbShadows.card);
    expect((decoration().border! as Border).top.color, PbColors.borderSoft);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('comment-box'))));
    await tester.pump();

    expect(decoration().boxShadow, PbShadows.stateHover);

    await tester.tap(find.byKey(const ValueKey('comment-box-input')));
    await tester.pump();

    expect((decoration().border! as Border).top.color, PbColors.borderStateSelected);
    expect(decoration().boxShadow!.first.spreadRadius, 3);
    expect(decoration().boxShadow!.first.color, PbColors.borderStateSelected.withValues(alpha: 0.36));
  });
}
