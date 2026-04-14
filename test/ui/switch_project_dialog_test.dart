import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/nav/switch_project_dialog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> _pumpSwitchProjectDialog(
  WidgetTester tester, {
  required Resource<List<Project>> projects,
  Size physicalSize = const Size(1280, 900),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = physicalSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        body: Center(
          child: SwitchProjectDialog(currentProjectId: 'project-0', projects: projects, onSwitch: (_) {}, onNewProject: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('desktop switch project dialog keeps the project list body capped and scrollable', (tester) async {
    final projects = Resource<List<Project>>(
      () async => List.generate(18, (index) => Project(id: 'project-$index', name: 'Project $index')),
    );
    addTearDown(projects.dispose);
    await projects.refresh();

    await _pumpSwitchProjectDialog(tester, projects: projects);

    final desktopListViewport = find.byWidgetPredicate((widget) {
      if (widget is! ConstrainedBox) {
        return false;
      }

      final constraints = widget.constraints;
      return constraints.maxWidth == 320 && constraints.maxHeight == 420;
    });

    expect(desktopListViewport, findsOneWidget);
    expect(tester.getSize(desktopListViewport).height, lessThanOrEqualTo(420.0));
  });
}
