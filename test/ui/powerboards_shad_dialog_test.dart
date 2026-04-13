import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/widgets/multi_select_autocomplete.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> _pumpDialog(WidgetTester tester, Widget dialog, {double bottomInset = 0, bool resizeToAvoidBottomInset = true}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);

  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: Align(alignment: Alignment.bottomCenter, child: dialog),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder _flowDialogSurface() {
  return find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) {
      return false;
    }

    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.borderRadius == const BorderRadius.vertical(top: Radius.circular(28));
  });
}

double _distanceFromCenter(double value, double center) => (value - center).abs();

class _InviteStepHost extends StatefulWidget {
  const _InviteStepHost({required this.focusNode});

  final FocusNode focusNode;

  @override
  State<_InviteStepHost> createState() => _InviteStepHostState();
}

class _InviteStepHostState extends State<_InviteStepHost> {
  bool _showInviteStep = false;

  @override
  Widget build(BuildContext context) {
    if (_showInviteStep) {
      return _InviteStepForm(focusNode: widget.focusNode);
    }

    return PowerboardsShadDialog.task(
      title: const Text('Permissions'),
      description: const Text('Adjust room access.'),
      actions: [
        ShadButton(
          onPressed: () {
            setState(() {
              _showInviteStep = true;
            });
          },
          child: const Text('Add user'),
        ),
      ],
      child: const SizedBox(height: 60, child: Text('Permissions body')),
    );
  }
}

class _InviteStepForm extends StatefulWidget {
  const _InviteStepForm({required this.focusNode});

  final FocusNode focusNode;

  @override
  State<_InviteStepForm> createState() => _InviteStepFormState();
}

class _InviteStepFormState extends State<_InviteStepForm> {
  static const int _focusAttempts = 12;
  int _focusRequestId = 0;

  @override
  void initState() {
    super.initState();
    _requestFocus();
  }

  void _requestFocus() {
    final requestId = ++_focusRequestId;
    _requestFocusUntilFocused(requestId, remainingAttempts: _focusAttempts);
  }

  Future<void> _requestFocusUntilFocused(int requestId, {required int remainingAttempts}) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || requestId != _focusRequestId || widget.focusNode.hasFocus) {
      return;
    }

    widget.focusNode.requestFocus();
    if (widget.focusNode.hasFocus || remainingAttempts <= 1) {
      return;
    }

    _requestFocusUntilFocused(requestId, remainingAttempts: remainingAttempts - 1);
  }

  @override
  Widget build(BuildContext context) {
    return PowerboardsShadDialog.formTask(
      title: const Text('Invite user'),
      description: const Text('Invite someone by email to join this room.'),
      actions: [
        ShadButton.outline(onPressed: () {}, child: const Text('Back')),
        ShadButton(onPressed: () {}, child: const Text('Save')),
      ],
      child: SizedBox(
        height: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadInput(focusNode: widget.focusNode, placeholder: const Text('Type an email')),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('mobile flow dialog can be dismissed with a downward swipe', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ShadButton(
                onPressed: () {
                  showPowerboardsFlowDialog<void>(
                    context: context,
                    builder: (_) => PowerboardsShadDialog.task(
                      title: const Text('Swipe me'),
                      description: const Text('Drag down to dismiss.'),
                      actions: [ShadButton(onPressed: () {}, child: const Text('Done'))],
                      child: const SizedBox(height: 40, child: Text('Body')),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsOneWidget);

    await tester.fling(_flowDialogSurface(), const Offset(0, 520), 1800);
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsNothing);
  });

  testWidgets('mobile flow dialog uses a compact floor and actions stay anchored near the bottom', (tester) async {
    const dialogKey = ValueKey('flow-dialog');

    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        key: dialogKey,
        title: const Text('Permissions'),
        description: const Text('Adjust room access.'),
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Cancel')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: const SizedBox(height: 40, child: Text('Short body')),
      ),
    );

    final dialogFinder = _flowDialogSurface();
    final dialogSize = tester.getSize(dialogFinder);
    final dialogBottom = tester.getBottomLeft(dialogFinder).dy;
    final cancelRect = tester.getRect(find.widgetWithText(ShadButton, 'Cancel'));
    final saveRect = tester.getRect(find.widgetWithText(ShadButton, 'Save'));
    final saveBottom = tester.getBottomLeft(find.widgetWithText(ShadButton, 'Save')).dy;

    expect(dialogSize.height, greaterThan(300));
    expect(dialogSize.height, lessThan(420));
    expect(dialogBottom - saveBottom, lessThan(110));
    expect((saveRect.top - cancelRect.top).abs(), lessThan(1));
    expect(saveRect.left, greaterThan(cancelRect.left));
  });

  testWidgets('mobile flow dialog centers sparse content inside the compact shell', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.listPicker(
        title: const Text('Agents & Services'),
        description: const Text('No agents installed yet.'),
        actions: [ShadButton(onPressed: () {}, child: const Text('Install'))],
        child: const SizedBox(height: 48, child: Center(child: Text('Empty state'))),
      ),
    );

    final dialogFinder = _flowDialogSurface();
    final dialogRect = tester.getRect(dialogFinder);
    final emptyStateRect = tester.getRect(find.text('Empty state'));
    final contentAreaCenterY = (dialogRect.top + dialogRect.bottom) / 2;
    final emptyStateCenterY = emptyStateRect.center.dy;
    final scrollView = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));

    expect(dialogRect.height, greaterThan(280));
    expect(dialogRect.height, lessThan(390));
    expect(_distanceFromCenter(emptyStateCenterY, contentAreaCenterY), lessThan(80));
    expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('mobile form flow dialog uses a full-height shell with footer actions anchored at the bottom', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.formTask(
        title: const Text('Invite user'),
        description: const Text('Invite someone by email to join this room.'),
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Back')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: const SizedBox(height: 140, child: Text('Form body')),
      ),
      resizeToAvoidBottomInset: false,
    );

    final dialogFinder = _flowDialogSurface();
    final dialogHeight = tester.getSize(dialogFinder).height;
    final dialogBottom = tester.getBottomLeft(dialogFinder).dy;
    final saveBottom = tester.getBottomLeft(find.widgetWithText(ShadButton, 'Save')).dy;

    expect(dialogHeight, greaterThan(700));
    expect(dialogBottom - saveBottom, lessThan(110));
  });

  testWidgets('mobile form flow dialog does not lift above the keyboard inset', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.formTask(
        title: const Text('Invite user'),
        description: const Text('Invite someone by email to join this room.'),
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Back')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: const SizedBox(height: 140, child: Text('Form body')),
      ),
      bottomInset: 320,
      resizeToAvoidBottomInset: false,
    );

    final dialogBottom = tester.getBottomLeft(_flowDialogSurface()).dy;

    expect(dialogBottom, greaterThan(820));
  });

  testWidgets('mobile full-height form flow does not duplicate a focusable input for measurement', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.formTask(
        title: const Text('Invite user'),
        description: const Text('Invite someone by email to join this room.'),
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Back')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: const SizedBox(
          height: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [ShadInput(autofocus: true, placeholder: Text('Type an email'))],
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
    );

    expect(find.byType(EditableText, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile flow dialog step switch can focus the invite field', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) => Scaffold(
            resizeToAvoidBottomInset: false,
            body: Center(
              child: ShadButton(
                onPressed: () {
                  showPowerboardsFlowDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _InviteStepHost(focusNode: focusNode),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ShadButton, 'Add user'));
    await tester.pumpAndSettle();

    expect(find.text('Invite user'), findsOneWidget);
    expect(focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile compact alert dialog shows a horizontal secondary-then-primary action row', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.compactAlert(
        title: const Text('Secret requested'),
        description: const Text('Provide a secret value.'),
        actions: [
          ShadButton.secondary(onPressed: () {}, child: const Text('Cancel')),
          ShadButton(onPressed: () {}, child: const Text('Provide')),
        ],
        child: const SizedBox(height: 40, child: Text('Body')),
      ),
    );

    final provideRect = tester.getRect(find.widgetWithText(ShadButton, 'Provide'));
    final cancelRect = tester.getRect(find.widgetWithText(ShadButton, 'Cancel'));

    expect((provideRect.top - cancelRect.top).abs(), lessThan(1));
    expect(provideRect.left, greaterThan(cancelRect.left));
  });

  testWidgets('mobile alert dialog shows a horizontal secondary-then-primary action row', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.alert(
        title: const Text('Secret requested'),
        description: const Text('Provide a secret value.'),
        actions: [
          ShadButton.secondary(onPressed: () {}, child: const Text('Cancel')),
          ShadButton(onPressed: () {}, child: const Text('Provide')),
        ],
        child: const SizedBox(height: 40, child: Text('Body')),
      ),
    );

    final provideRect = tester.getRect(find.widgetWithText(ShadButton, 'Provide'));
    final cancelRect = tester.getRect(find.widgetWithText(ShadButton, 'Cancel'));

    expect((provideRect.top - cancelRect.top).abs(), lessThan(1));
    expect(provideRect.left, greaterThan(cancelRect.left));
  });

  testWidgets('mobile flow dialog caps growth and scrolls inside the body for long content', (tester) async {
    const dialogKey = ValueKey('scrolling-flow-dialog');

    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        key: dialogKey,
        title: const Text('Long content'),
        description: const Text('A longer flow dialog body should scroll.'),
        actions: [ShadButton(onPressed: () {}, child: const Text('Done'))],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(40, (index) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Item $index'))),
        ),
      ),
    );

    final dialogFinder = _flowDialogSurface();
    final dialogHeight = tester.getSize(dialogFinder).height;
    final dialogBottom = tester.getBottomLeft(dialogFinder).dy;
    final item39Finder = find.text('Item 39');
    final item39TopBeforeScroll = tester.getTopLeft(item39Finder).dy;

    expect(dialogHeight, greaterThan(700));
    expect(dialogHeight, lessThanOrEqualTo(799));
    expect(item39TopBeforeScroll, greaterThan(dialogBottom));

    await tester.drag(find.text('Item 0'), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(item39Finder).dy, lessThan(dialogBottom));
  });

  testWidgets('mobile flow dialog lifts above the keyboard inset', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        title: const Text('Invite user'),
        description: const Text('Invite someone by email to join this room.'),
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Back')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: const SizedBox(height: 140, child: Text('Form body')),
      ),
      bottomInset: 320,
    );

    final dialogBottom = tester.getBottomLeft(_flowDialogSurface()).dy;

    expect(dialogBottom, lessThan(844 - 280));
  });

  testWidgets('mobile fill flow dialog renders expanded body content without measurement fallback errors', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        title: const Text('Invite user'),
        description: const Text('Invite someone by email to join this room.'),
        mobileFlowBodyBehavior: PowerboardsDialogMobileFlowBodyBehavior.fill,
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Back')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Text('Enter email address'),
            SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: Text('Suggestions'))),
          ],
        ),
      ),
    );

    expect(find.text('Invite user'), findsOneWidget);
    expect(find.text('Enter email address'), findsOneWidget);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile flow dialog input keeps focus when tapped', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        title: const Text('Invite user'),
        description: const Text('Invite someone by email to join this room.'),
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Back')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: SizedBox(
          height: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadInput(focusNode: focusNode, placeholder: const Text('Type an email')),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText).last);
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offstage autocomplete measurement copy stays inactive', (tester) async {
    final controller = MultiSelectController();
    final textController = TextEditingController(text: 'a');

    addTearDown(controller.dispose);
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      ShadApp(
        home: Offstage(
          child: MultiSelectAutocomplete(
            controller: controller,
            textController: textController,
            autofocus: true,
            minimumSearchLength: 1,
            debounceDuration: const Duration(milliseconds: 1),
            placeholder: const Text('Type an email'),
            search: (_) async => const ['alpha@example.com'],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(find.byType(EditableText, skipOffstage: false));

    expect(editableText.autofocus, isFalse);
    expect(find.text('alpha@example.com'), findsNothing);
  });
}
