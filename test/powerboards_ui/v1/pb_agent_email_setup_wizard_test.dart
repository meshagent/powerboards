import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/chat/meshagent_room.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_agent_email_setup_wizard.dart';

Widget _harness(
  PbAgentEmailInstaller onInstall, {
  PbAgentEmailSetupProcessing? processing,
  String? managedRecoveryMessage,
  VoidCallback? onManagedRecovery,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 700,
        child: PbAgentEmailSetupWizard(
          domain: 'mail.example.test',
          onInstall: onInstall,
          processing: processing,
          managedRecoveryMessage: managedRecoveryMessage,
          onManagedRecovery: onManagedRecovery,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('email setup validates the local part and installs Assistant with the configured domain', (tester) async {
    final installCompleter = Completer<void>();
    final emails = <String?>[];

    await tester.pumpWidget(
      _harness((email) {
        emails.add(email);
        return installCompleter.future;
      }),
    );

    expect(find.text('Give your agent an email'), findsOneWidget);
    expect(find.text('Skip to start chatting'), findsOneWidget);

    await tester.tap(find.text('Set up email'));
    await tester.pump();
    expect(find.text('@mail.example.test'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('agent-email-local-part')), 'bad@name');
    await tester.tap(find.text('Complete Setup'));
    await tester.pump();
    expect(find.byKey(const ValueKey('agent-email-validation-error')), findsOneWidget);
    expect(emails, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('agent-email-local-part')), 'helper');
    await tester.tap(find.text('Complete Setup'));
    await tester.pump();
    expect(emails, ['helper@mail.example.test']);
    expect(find.text('Initializing your agent'), findsOneWidget);

    installCompleter.complete();
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('skip installs without email and reflects the real pending operation', (tester) async {
    final installCompleter = Completer<void>();
    final emails = <String?>[];

    await tester.pumpWidget(
      _harness((email) {
        emails.add(email);
        return installCompleter.future;
      }),
    );

    await tester.tap(find.text('Skip to start chatting'));
    await tester.pump();

    expect(emails, [null]);
    expect(find.text('Initializing…'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);

    installCompleter.complete();
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('install errors expose retry and prevent double submission', (tester) async {
    final retryCompleter = Completer<void>();
    var calls = 0;

    await tester.pumpWidget(
      _harness((email) {
        calls += 1;
        if (calls == 1) {
          throw StateError('Service unavailable');
        }
        return retryCompleter.future;
      }),
    );

    await tester.tap(find.text('Skip to start chatting'));
    await tester.pump();
    expect(find.text('Service unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Retry'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Initializing…'), findsOneWidget);

    retryCompleter.complete();
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('managed service operations replace setup controls with operation-specific progress', (tester) async {
    await tester.pumpWidget(_harness((_) async {}, processing: PbAgentEmailSetupProcessing.installing));

    expect(find.text('Initializing your agent'), findsOneWidget);
    expect(find.text('Installing…'), findsOneWidget);
    expect(find.text('Set up email'), findsNothing);
    expect(find.text('Skip to start chatting'), findsNothing);

    await tester.pumpWidget(_harness((_) async {}, processing: PbAgentEmailSetupProcessing.uninstalling));
    await tester.pump();

    expect(find.text('Uninstalling your agent'), findsOneWidget);
    expect(find.text('Uninstalling…'), findsOneWidget);
    expect(find.text('Set up email'), findsNothing);
    expect(find.text('Skip to start chatting'), findsNothing);
  });

  testWidgets('managed install and uninstall failures expose contextual recovery actions', (tester) async {
    var recoveries = 0;
    await tester.pumpWidget(
      _harness(
        (_) async {},
        processing: PbAgentEmailSetupProcessing.installing,
        managedRecoveryMessage: 'Assistant is not connected yet.',
        onManagedRecovery: () => recoveries += 1,
      ),
    );

    expect(find.text('Assistant is still initializing'), findsOneWidget);
    expect(find.text('Assistant is not connected yet.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(recoveries, 1);

    await tester.pumpWidget(
      _harness(
        (_) async {},
        processing: PbAgentEmailSetupProcessing.uninstalling,
        managedRecoveryMessage: 'Assistant is still being removed.',
        onManagedRecovery: () => recoveries += 1,
      ),
    );
    await tester.pump();

    expect(find.text('Assistant removal is still syncing'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    expect(recoveries, 2);
  });

  testWidgets('non-permitted blank room preserves its non-actionable empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 900, height: 700, child: PowerboardsBlankDesktopPreviewRoomWorkspace(mailDomain: 'mail.example.test')),
        ),
      ),
    );

    expect(find.text('Start with an agent'), findsOneWidget);
    expect(find.text('Set up email'), findsNothing);
    expect(find.text('Skip to start chatting'), findsNothing);
  });

  test('quick-start boundary excludes installed, mobile, legacy, and non-permitted states', () {
    expect(
      powerboardsShouldUseAssistantEmailQuickStart(usesDesktopV1: true, isMobile: false, hasVisibleAgents: false, canInstallAgent: true),
      isTrue,
    );
    expect(
      powerboardsShouldUseAssistantEmailQuickStart(usesDesktopV1: true, isMobile: true, hasVisibleAgents: false, canInstallAgent: true),
      isFalse,
    );
    expect(
      powerboardsShouldUseAssistantEmailQuickStart(usesDesktopV1: false, isMobile: false, hasVisibleAgents: false, canInstallAgent: true),
      isFalse,
    );
    expect(
      powerboardsShouldUseAssistantEmailQuickStart(usesDesktopV1: true, isMobile: false, hasVisibleAgents: true, canInstallAgent: true),
      isFalse,
    );
    expect(
      powerboardsShouldUseAssistantEmailQuickStart(usesDesktopV1: true, isMobile: false, hasVisibleAgents: false, canInstallAgent: false),
      isFalse,
    );
  });

  test('active quick start holds the wizard after the service becomes visible', () {
    expect(powerboardsShouldHoldAssistantQuickStartWorkspace(hasVisibleAgents: false, quickStartActive: false), isTrue);
    expect(powerboardsShouldHoldAssistantQuickStartWorkspace(hasVisibleAgents: true, quickStartActive: true), isTrue);
    expect(powerboardsShouldHoldAssistantQuickStartWorkspace(hasVisibleAgents: true, quickStartActive: false), isFalse);
  });

  test('only Assistant install and uninstall operations drive managed setup progress', () {
    expect(
      powerboardsAssistantSetupProcessingForServiceOperation(
        serviceKindId: 'meshagent.assistant',
        operation: PowerboardsServiceOperation.install,
      ),
      PbAgentEmailSetupProcessing.installing,
    );
    expect(
      powerboardsAssistantSetupProcessingForServiceOperation(
        serviceKindId: 'meshagent.assistant',
        operation: PowerboardsServiceOperation.uninstall,
      ),
      PbAgentEmailSetupProcessing.uninstalling,
    );
    expect(
      powerboardsAssistantSetupProcessingForServiceOperation(
        serviceKindId: 'meshagent.assistant',
        operation: PowerboardsServiceOperation.update,
      ),
      isNull,
    );
    expect(
      powerboardsAssistantSetupProcessingForServiceOperation(
        serviceKindId: 'meshagent.voice',
        operation: PowerboardsServiceOperation.install,
      ),
      isNull,
    );
  });

  test('Assistant reconciliation converges only at operation-specific terminal state', () {
    expect(
      powerboardsAssistantReconciliationHasConverged(
        processing: PbAgentEmailSetupProcessing.installing,
        assistantServicePresent: true,
        assistantParticipantAvailable: true,
      ),
      isTrue,
    );
    expect(
      powerboardsAssistantReconciliationHasConverged(
        processing: PbAgentEmailSetupProcessing.installing,
        assistantServicePresent: true,
        assistantParticipantAvailable: false,
      ),
      isFalse,
    );
    expect(
      powerboardsAssistantReconciliationHasConverged(
        processing: PbAgentEmailSetupProcessing.uninstalling,
        assistantServicePresent: false,
        assistantParticipantAvailable: true,
      ),
      isTrue,
    );
  });

  test('Assistant reconciliation releases only after route and runtime state agree', () {
    expect(
      powerboardsAssistantReconciliationCanRelease(
        processing: PbAgentEmailSetupProcessing.installing,
        assistantServicePresent: true,
        assistantParticipantAvailable: true,
        selectedRouteId: 'meshagent.assistant',
      ),
      isTrue,
    );
    expect(
      powerboardsAssistantReconciliationCanRelease(
        processing: PbAgentEmailSetupProcessing.installing,
        assistantServicePresent: true,
        assistantParticipantAvailable: true,
        selectedRouteId: null,
      ),
      isFalse,
    );
    expect(
      powerboardsAssistantReconciliationCanRelease(
        processing: PbAgentEmailSetupProcessing.installing,
        assistantServicePresent: true,
        assistantParticipantAvailable: false,
        selectedRouteId: 'meshagent.assistant',
      ),
      isFalse,
    );
    expect(
      powerboardsAssistantReconciliationCanRelease(
        processing: PbAgentEmailSetupProcessing.uninstalling,
        assistantServicePresent: false,
        assistantParticipantAvailable: false,
        selectedRouteId: null,
      ),
      isTrue,
    );
    expect(
      powerboardsAssistantReconciliationCanRelease(
        processing: PbAgentEmailSetupProcessing.uninstalling,
        assistantServicePresent: false,
        assistantParticipantAvailable: false,
        selectedRouteId: 'meshagent.assistant',
      ),
      isFalse,
    );
  });

  test('Assistant reconciliation normalizes install and uninstall routes', () {
    expect(powerboardsAssistantRouteAfterReconciliation(PbAgentEmailSetupProcessing.installing), 'meshagent.assistant');
    expect(powerboardsAssistantRouteAfterReconciliation(PbAgentEmailSetupProcessing.uninstalling), isEmpty);
  });
}
