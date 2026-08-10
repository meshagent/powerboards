import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_button.dart';
import '../primitives/pb_empty_state.dart';
import '../primitives/pb_spinning_icon.dart';
import '../primitives/pb_svg_icon.dart';
import 'pb_agent_email_field.dart';

enum PbAgentEmailSetupStep { introduction, emailEntry, initializing, connected, error }

enum PbAgentEmailSetupProcessing { installing, uninstalling }

typedef PbAgentEmailInstaller = Future<void> Function(String? email);

String? powerboardsAgentEmailLocalPartError(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'Enter an email name.';
  }
  if (normalized.length > 48) {
    return 'Use 48 characters or fewer.';
  }
  if (!RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$').hasMatch(normalized)) {
    return 'Use letters, numbers, periods, hyphens, or underscores.';
  }
  return null;
}

class PbAgentEmailSetupWizard extends StatefulWidget {
  const PbAgentEmailSetupWizard({
    super.key,
    required this.domain,
    required this.onInstall,
    this.topFactor = pbEmptyStateReferenceTopFactor,
    this.topOffset = pbEmptyStateReferenceTopOffset,
    this.processing,
  });

  final String domain;
  final PbAgentEmailInstaller onInstall;
  final double topFactor;
  final double topOffset;
  final PbAgentEmailSetupProcessing? processing;

  @override
  State<PbAgentEmailSetupWizard> createState() => _PbAgentEmailSetupWizardState();
}

class _PbAgentEmailSetupWizardState extends State<PbAgentEmailSetupWizard> {
  final TextEditingController _emailController = TextEditingController();
  PbAgentEmailSetupStep _step = PbAgentEmailSetupStep.introduction;
  String? _validationError;
  String? _installError;
  String? _lastSubmittedEmail;
  bool _submitting = false;

  String get _emailSuffix {
    final domain = widget.domain.trim();
    return domain.startsWith('@') ? domain : '@$domain';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showEmailEntry() {
    setState(() {
      _step = PbAgentEmailSetupStep.emailEntry;
      _installError = null;
    });
  }

  Future<void> _completeEmailSetup() async {
    final error = powerboardsAgentEmailLocalPartError(_emailController.text);
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    if (widget.domain.trim().isEmpty) {
      setState(() => _validationError = 'Agent email is not configured for this deployment.');
      return;
    }
    final email = '${_emailController.text.trim()}$_emailSuffix';
    await _install(email);
  }

  Future<void> _install(String? email) async {
    if (_submitting) {
      return;
    }
    _submitting = true;
    _lastSubmittedEmail = email;
    setState(() {
      _step = PbAgentEmailSetupStep.initializing;
      _validationError = null;
      _installError = null;
    });

    try {
      await widget.onInstall(email);
      if (!mounted) {
        return;
      }
      setState(() => _step = PbAgentEmailSetupStep.connected);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst(RegExp(r'^(Exception|StateError|Bad state):\s*'), '').trim();
      setState(() {
        _installError = message.isEmpty ? 'Unable to initialize Assistant.' : message;
        _step = PbAgentEmailSetupStep.error;
      });
    } finally {
      _submitting = false;
    }
  }

  void _backFromError() {
    setState(() {
      _installError = null;
      _step = _lastSubmittedEmail == null ? PbAgentEmailSetupStep.introduction : PbAgentEmailSetupStep.emailEntry;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.processing == null ? _step : PbAgentEmailSetupStep.initializing;
    final bodyTopGap = step == PbAgentEmailSetupStep.emailEntry ? 18.0 : 12.0;
    final presentation = switch (widget.processing) {
      PbAgentEmailSetupProcessing.installing => const _WizardPresentation(
        iconAssetName: 'loader-circle-empty-state',
        title: 'Initializing your agent',
        subtitle: 'Installing…',
        spinning: true,
      ),
      PbAgentEmailSetupProcessing.uninstalling => const _WizardPresentation(
        iconAssetName: 'loader-circle-empty-state',
        title: 'Uninstalling your agent',
        subtitle: 'Uninstalling…',
        spinning: true,
      ),
      null => switch (step) {
        PbAgentEmailSetupStep.introduction => const _WizardPresentation(
          iconAssetName: 'messages-square',
          title: 'Give your agent an email',
          subtitle: 'Set up an address so you can send requests and continue conversations from your inbox too.',
        ),
        PbAgentEmailSetupStep.emailEntry => const _WizardPresentation(
          iconAssetName: 'at-sign',
          title: 'Set up your agent email',
          subtitle: '',
        ),
        PbAgentEmailSetupStep.initializing => const _WizardPresentation(
          iconAssetName: 'loader-circle-empty-state',
          title: 'Initializing your agent',
          subtitle: 'Initializing…',
          spinning: true,
        ),
        PbAgentEmailSetupStep.connected => const _WizardPresentation(
          iconAssetName: 'loader-circle-empty-state',
          title: 'Initializing your agent',
          subtitle: 'Connected',
        ),
        PbAgentEmailSetupStep.error => _WizardPresentation(
          iconAssetName: 'triangle-alert',
          title: 'Unable to initialize your agent',
          subtitle: _installError ?? 'Try again.',
        ),
      },
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final top = (constraints.maxHeight * widget.topFactor + widget.topOffset).clamp(0.0, double.infinity);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: top,
              left: 24,
              right: 24,
              child: Semantics(
                container: true,
                liveRegion: step == PbAgentEmailSetupStep.initializing || step == PbAgentEmailSetupStep.error,
                label: presentation.title,
                child: Center(
                  child: SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (presentation.spinning)
                          PbSpinningIcon(assetName: presentation.iconAssetName, size: 46, color: PbColors.customGray)
                        else
                          PbSvgIcon(assetName: presentation.iconAssetName, size: 46, color: PbColors.customGray),
                        const SizedBox(height: 18),
                        Text(presentation.title, textAlign: TextAlign.center, style: PowerboardsTypography.customEmptyStateTitle),
                        SizedBox(key: const ValueKey('agent-email-wizard-body-top-gap'), height: bodyTopGap),
                        if (step == PbAgentEmailSetupStep.emailEntry)
                          Column(
                            key: const ValueKey('agent-email-wizard-body-slot'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PbAgentEmailField(
                                controller: _emailController,
                                domain: widget.domain,
                                autofocus: true,
                                onChanged: (_) {
                                  if (_validationError != null) {
                                    setState(() => _validationError = null);
                                  }
                                },
                                onSubmitted: (_) => unawaited(_completeEmailSetup()),
                              ),
                              if (_validationError != null) ...[
                                const SizedBox(height: 7),
                                Text(
                                  _validationError!,
                                  key: const ValueKey('agent-email-validation-error'),
                                  textAlign: TextAlign.center,
                                  style: PowerboardsTypography.small.copyWith(color: PbColors.customAlert),
                                ),
                              ],
                            ],
                          )
                        else
                          ConstrainedBox(
                            key: const ValueKey('agent-email-wizard-body-slot'),
                            constraints: const BoxConstraints(minHeight: 53),
                            child: Center(
                              child: Text(
                                presentation.subtitle,
                                textAlign: TextAlign.center,
                                style: PowerboardsTypography.p.copyWith(
                                  color: step == PbAgentEmailSetupStep.error ? PbColors.customAlert : PbColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        if (step == PbAgentEmailSetupStep.introduction || step == PbAgentEmailSetupStep.emailEntry) ...[
                          const SizedBox(height: 30),
                          SizedBox(
                            key: const ValueKey('agent-email-wizard-primary-action'),
                            width: 196,
                            child: PbButton(
                              label: step == PbAgentEmailSetupStep.introduction ? 'Set up email' : 'Complete Setup',
                              variant: PbButtonVariant.primary,
                              height: 44,
                              onPressed: step == PbAgentEmailSetupStep.introduction
                                  ? _showEmailEntry
                                  : () => unawaited(_completeEmailSetup()),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _WizardTextButton(
                            label: step == PbAgentEmailSetupStep.introduction ? 'Skip to start chatting' : 'Skip for now',
                            onPressed: () => unawaited(_install(null)),
                          ),
                        ] else if (step == PbAgentEmailSetupStep.error) ...[
                          const SizedBox(height: 30),
                          SizedBox(
                            width: 196,
                            child: PbButton(
                              label: 'Retry',
                              variant: PbButtonVariant.primary,
                              height: 44,
                              onPressed: () => unawaited(_install(_lastSubmittedEmail)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _WizardTextButton(label: 'Back', onPressed: _backFromError),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WizardPresentation {
  const _WizardPresentation({required this.iconAssetName, required this.title, required this.subtitle, this.spinning = false});

  final String iconAssetName;
  final String title;
  final String subtitle;
  final bool spinning;
}

class _WizardTextButton extends StatefulWidget {
  const _WizardTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_WizardTextButton> createState() => _WizardTextButtonState();
}

class _WizardTextButtonState extends State<_WizardTextButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: PowerboardsTypography.button.copyWith(color: _hovered ? PbColors.dynamicCustomBlue : PbColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
