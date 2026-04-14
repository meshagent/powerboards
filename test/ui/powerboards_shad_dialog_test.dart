import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/ui/powerboards_mobile_field_suggestion_menu.dart';
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

class _InviteSuggestionsOverlayHost extends StatefulWidget {
  const _InviteSuggestionsOverlayHost();

  @override
  State<_InviteSuggestionsOverlayHost> createState() => _InviteSuggestionsOverlayHostState();
}

class _InviteSuggestionsOverlayHostState extends State<_InviteSuggestionsOverlayHost> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _tapRegionGroupId = Object();
  String? _selectedEmail;
  static const _suggestions = [
    'prb-01@mail.meshagent.com',
    'prb-02@mail.meshagent.com',
    'prb-03@mail.meshagent.com',
    'prb-04@mail.meshagent.com',
    'prb-05@mail.meshagent.com',
    'prb-06@mail.meshagent.com',
    'prb-07@mail.meshagent.com',
    'prb-08@mail.meshagent.com',
    'prb-09@mail.meshagent.com',
    'prb-10@mail.meshagent.com',
    'prb-11@mail.meshagent.com',
    'prb-12@mail.meshagent.com',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
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
        height: 220,
        child: AnimatedBuilder(
          animation: Listenable.merge([_textController, _focusNode]),
          builder: (context, _) {
            final suggestions = _textController.text.trim().isEmpty ? const <String>[] : _suggestions;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return ShadPortal(
                      visible: suggestions.isNotEmpty,
                      anchor: const ShadAnchor(
                        childAlignment: Alignment.topLeft,
                        overlayAlignment: Alignment.bottomLeft,
                        offset: Offset(0, 12),
                      ),
                      portalBuilder: (_) {
                        return PowerboardsMobileFieldSuggestionMenu<String>(
                          width: constraints.maxWidth,
                          items: suggestions,
                          groupId: _tapRegionGroupId,
                          maxHeight: 168,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD9D9D9)),
                          ),
                          itemBuilder: (context, email, index) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _selectedEmail = email;
                                });
                              },
                              child: Padding(padding: const EdgeInsets.all(16), child: Text(email)),
                            );
                          },
                          separatorBuilder: (context, index) => const Divider(height: 1),
                        );
                      },
                      child: TextFieldTapRegion(
                        groupId: _tapRegionGroupId,
                        child: ShadInput(
                          controller: _textController,
                          focusNode: _focusNode,
                          groupId: _tapRegionGroupId,
                          placeholder: const Text('Type an email'),
                          onPressedOutside: (_) {
                            _focusNode.unfocus();
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedEmail != null) Text('Selected: $_selectedEmail'),
                const Text('Body content'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AsyncGrowingListBody extends StatefulWidget {
  const _AsyncGrowingListBody();

  @override
  State<_AsyncGrowingListBody> createState() => _AsyncGrowingListBodyState();
}

class _AsyncGrowingListBodyState extends State<_AsyncGrowingListBody> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _expanded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return const SizedBox(height: 48, child: Center(child: Text('Loading threads')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(8, (index) => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Thread item'))),
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

  testWidgets('mobile flow dialog waits for background keyboard insets to clear before presenting', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

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
                    builder: (_) => PowerboardsShadDialog.task(
                      title: const Text('Permissions'),
                      description: const Text('Adjust room access.'),
                      mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.ignore,
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
    await tester.pump();

    expect(find.text('Permissions'), findsNothing);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Permissions'), findsOneWidget);
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

  testWidgets('mobile list picker flow dialog stays anchored to the screen when a background keyboard inset exists', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.listPicker(
        title: const Text('All threads'),
        description: const Text('Select a thread to view.'),
        actions: [ShadButton(onPressed: () {}, child: const Text('Done'))],
        child: const SizedBox(height: 48, child: Center(child: Text('Thread list'))),
      ),
      bottomInset: 320,
      resizeToAvoidBottomInset: false,
    );

    final dialogBottom = tester.getBottomLeft(_flowDialogSurface()).dy;

    expect(dialogBottom, greaterThan(820));
  });

  testWidgets('mobile task flow dialog can stay anchored to the screen when keyboard avoidance is disabled', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        title: const Text('Permissions'),
        description: const Text('Adjust room access.'),
        mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.ignore,
        actions: [ShadButton(onPressed: () {}, child: const Text('Done'))],
        child: const SizedBox(height: 60, child: Text('Permissions body')),
      ),
      bottomInset: 320,
      resizeToAvoidBottomInset: false,
    );

    final dialogBottom = tester.getBottomLeft(_flowDialogSurface()).dy;

    expect(dialogBottom, greaterThan(820));
  });

  testWidgets('mobile list picker flow dialog remeasures when async body content grows after open', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PowerboardsShadDialog.listPicker(
              title: const Text('All threads'),
              description: const Text('Select a thread to view.'),
              actions: [ShadButton(onPressed: () {}, child: const Text('Done'))],
              child: const _AsyncGrowingListBody(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final dialogFinder = _flowDialogSurface();
    final initialHeight = tester.getSize(dialogFinder).height;
    expect(find.text('Loading threads'), findsOneWidget);

    await tester.pump();
    await tester.pump();

    final expandedHeight = tester.getSize(dialogFinder).height;

    expect(expandedHeight, greaterThan(initialHeight));
    expect(find.text('Thread item'), findsNWidgets(8));
    expect(tester.takeException(), isNull);
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

  testWidgets('mobile invite suggestions open below the field without moving body content', (tester) async {
    await _pumpDialog(tester, const _InviteSuggestionsOverlayHost(), resizeToAvoidBottomInset: false);

    final bodyRectBefore = tester.getRect(find.text('Body content'));
    final inputFinder = find.byType(EditableText);
    final inputRect = tester.getRect(inputFinder);

    await tester.tap(inputFinder);
    await tester.enterText(inputFinder, 'prb');
    await tester.pump();
    await tester.pump();

    final bodyRectAfter = tester.getRect(find.text('Body content'));
    final suggestionRect = tester.getRect(find.text('prb-01@mail.meshagent.com'));

    expect(bodyRectAfter.top, closeTo(bodyRectBefore.top, 0.01));
    expect(suggestionRect.top, greaterThanOrEqualTo(inputRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile invite suggestion overlay remains selectable', (tester) async {
    await _pumpDialog(tester, const _InviteSuggestionsOverlayHost(), resizeToAvoidBottomInset: false);

    final inputFinder = find.byType(EditableText);

    await tester.tap(inputFinder);
    await tester.enterText(inputFinder, 'prb');
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('prb-01@mail.meshagent.com'));
    await tester.pump();

    expect(find.text('Selected: prb-01@mail.meshagent.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile invite suggestion overlay scrolls through larger result sets', (tester) async {
    await _pumpDialog(tester, const _InviteSuggestionsOverlayHost(), resizeToAvoidBottomInset: false);

    final inputFinder = find.byType(EditableText);

    await tester.tap(inputFinder);
    await tester.enterText(inputFinder, 'prb');
    await tester.pump();
    await tester.pump();

    expect(find.text('prb-12@mail.meshagent.com'), findsNothing);

    await tester.dragUntilVisible(find.text('prb-12@mail.meshagent.com'), find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('prb-12@mail.meshagent.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile invite suggestion overlay stays above the keyboard and remains scrollable', (tester) async {
    const bottomInset = 320.0;
    await _pumpDialog(tester, const _InviteSuggestionsOverlayHost(), bottomInset: bottomInset, resizeToAvoidBottomInset: false);

    final inputFinder = find.byType(EditableText);

    await tester.tap(inputFinder);
    await tester.enterText(inputFinder, 'prb');
    await tester.pump();
    await tester.pump();

    final keyboardTop = tester.view.physicalSize.height - bottomInset;
    final menuRect = tester.getRect(find.byType(PowerboardsMobileFieldSuggestionMenu<String>));

    expect(menuRect.bottom, lessThanOrEqualTo(keyboardTop + 0.01));
    expect(find.text('prb-12@mail.meshagent.com'), findsNothing);

    await tester.dragUntilVisible(find.text('prb-12@mail.meshagent.com'), find.byType(ListView).last, const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(find.text('prb-12@mail.meshagent.com'), findsOneWidget);
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
