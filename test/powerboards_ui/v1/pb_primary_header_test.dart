import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_primary_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_people_here_menu.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';

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

  testWidgets('mobile-like primary header only renders the room switcher row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: PbPrimaryHeader(
              shellMobile: true,
              shellIconOnly: false,
              roomValue: 'Product',
              avatarInitials: 'DJ',
              onSharePressed: () {},
              onAvatarPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Room'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
    expect(find.text('DJ'), findsNothing);
  });

  testWidgets('desktop primary header shows who is here trigger and menu content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: PbPrimaryHeader(
              shellMobile: false,
              shellIconOnly: false,
              roomValue: 'Product',
              presenceMembers: [
                PbPresenceMember(displayName: 'Ava Chen', initials: 'AC'),
                PbPresenceMember(displayName: 'Jordan Lee', initials: 'JL'),
                PbPresenceMember(displayName: 'Marco Silva', initials: 'MS'),
                PbPresenceMember(displayName: 'Priya Patel', initials: 'PP'),
              ],
              presenceSelected: true,
              presenceMenu: PbPeopleHereMenu(
                members: [
                  PbPresenceMember(displayName: 'Ava Chen', initials: 'AC'),
                  PbPresenceMember(displayName: 'Jordan Lee', initials: 'JL'),
                  PbPresenceMember(displayName: 'Marco Silva', initials: 'MS'),
                  PbPresenceMember(displayName: 'Priya Patel', initials: 'PP'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+1'), findsOneWidget);
    expect(find.text('People here right now'), findsOneWidget);
    expect(find.text('Ava Chen'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('Marco Silva'), findsOneWidget);
    expect(find.text('Priya Patel'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('+1')).style,
      PowerboardsTypography.badge.copyWith(color: PbColors.surfaceRailActive, fontWeight: FontWeight.w800),
    );
  });
}
