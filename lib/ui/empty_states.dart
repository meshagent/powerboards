import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:localstorage/localstorage.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent/client.dart';

import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';

class EmptyRooms extends StatelessWidget {
  const EmptyRooms({super.key, this.onCreateRoom});

  final VoidCallback? onCreateRoom;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final tt = ShadTheme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ShadCard(
          padding: const .all(40),
          radius: .circular(32),
          footer: onCreateRoom != null
              ? Padding(
                  padding: const .only(top: 30),
                  child: ShadButton(width: .infinity, onPressed: onCreateRoom, child: const Text('Continue')),
                )
              : null,
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: cs.primary, borderRadius: .circular(12)),
                child: Icon(LucideIcons.packagePlus, size: 24, color: cs.background),
              ),
              const SizedBox(height: 16),

              Text('Create a room', style: tt.h3.copyWith(fontWeight: .w800)),

              const SizedBox(height: 8),
              Text('Rooms bring people, agents, and content together. Create one to:'),
              const SizedBox(height: 20),

              Padding(
                padding: const .only(left: 8),
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    Row(
                      crossAxisAlignment: .start,
                      spacing: 8,
                      children: [
                        Text('•'),
                        Expanded(child: Text('Organize discussions')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: .start,
                      spacing: 8,
                      children: [
                        Text('•'),
                        Expanded(child: Text('Create files with agents')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: .start,
                      spacing: 8,
                      children: [
                        Text('•'),
                        Expanded(child: Text('Share files')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: .start,
                      spacing: 8,
                      children: [
                        Text('•'),
                        Expanded(child: Text('Invite members')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: .start,
                      spacing: 8,
                      children: [
                        Text('•'),
                        Expanded(child: Text('Manage agents')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 16),
        Text(label, style: ShadTheme.of(context).textTheme.p),
      ],
    );
  }
}

class EmptyProjectsState extends StatelessWidget {
  const EmptyProjectsState({super.key, required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final tt = ShadTheme.of(context).textTheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ShadCard(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 0 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / icon header
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(LucideIcons.briefcase, size: 28),
                    ),
                    const SizedBox(height: 16),

                    // Title & description
                    Text('Create your project', style: tt.h4, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Projects are the top-level space for your work. They contain rooms, members, and billing. '
                      'Start by creating a project—add rooms and invite teammates when you’re ready.',
                      style: tt.muted,
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),
                    const ShadSeparator.horizontal(),
                    const SizedBox(height: 16),

                    // Tiny benefit list (wrap for small screens)
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: const [
                        _Point(icon: LucideIcons.layers, label: 'Organize rooms'),
                        _Point(icon: LucideIcons.users, label: 'Manage members'),
                        _Point(icon: LucideIcons.creditCard, label: 'Centralize billing'),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Actions
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [ShadButton(onPressed: onCreateProject, child: const Text('Create project'))],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BalanceLowWarning extends StatelessWidget {
  const BalanceLowWarning({super.key, required this.onAddCredits, required this.role});

  final VoidCallback onAddCredits;
  final ProjectRole role;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const .all(20),
          child: ShadCard(
            child: Column(
              mainAxisSize: .min,
              children: [
                Container(
                  width: 64.0,
                  height: 64.0,
                  decoration: BoxDecoration(color: cs.destructiveForeground, borderRadius: .circular(12)),
                  child: Icon(LucideIcons.triangleAlert, size: 28.0, color: cs.destructive),
                ),
                const SizedBox(height: 16),

                // Title & description
                Text("Low Credit Balance", style: tt.h4, textAlign: .center),
                const SizedBox(height: 8),

                if (role == ProjectRole.admin && kIsWeb)
                  Text(
                    "Your credit balance is low. Please purchase credits to continue using Powerboards features.",
                    style: tt.muted,
                    textAlign: .center,
                  )
                else if (role == ProjectRole.admin)
                  Text("Your credit balance is low. Please use web browser to purchase more credits.", style: tt.muted, textAlign: .center)
                else
                  Text("Your credit balance is low. Please contact an admin to resolve this issue.", style: tt.muted, textAlign: .center),
                if (role == ProjectRole.admin && kIsWeb) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: .center,
                    children: [ShadButton(onPressed: onAddCredits, child: Text("Add Credits"))],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserForbiddenWarning extends StatelessWidget {
  const UserForbiddenWarning({super.key});

  Widget _body(BuildContext context, ShadColorScheme cs, ShadTextTheme tt) {
    final user = MeshagentAuth.current.getUser();

    return Column(
      mainAxisSize: .min,
      children: [
        Container(
          width: 64.0,
          height: 64.0,
          decoration: BoxDecoration(color: cs.destructiveForeground, borderRadius: .circular(12)),
          child: Icon(LucideIcons.x, size: 28.0, color: cs.destructive),
        ),
        const SizedBox(height: 16),
        Text("Access Denied", style: tt.h4, textAlign: .center),
        const SizedBox(height: 8),
        RichText(
          textAlign: .center,
          text: TextSpan(
            style: tt.muted.copyWith(height: 1.5),
            children: [
              TextSpan(text: "Your user "),
              TextSpan(
                text: user?['email'],
                style: TextStyle(fontWeight: .bold),
              ),
              TextSpan(
                text:
                    " does not have permission to access this project. "
                    "Please check user's permissions or contact an admin for assistance.",
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShadButton(
          onPressed: () {
            MeshagentAuth.current.signOut();
            localStorage.clear();

            final returnUrl = MeshagentConfig.current!.appUrl;
            final signOutUrl = MeshagentConfig.current!.serverUrl
                .resolve("/signout")
                .replace(queryParameters: {if (MeshagentConfig.current?.appUrl != null) "return_url": returnUrl.toString()});

            if (kIsWeb) {
              launchUrl(signOutUrl, webOnlyWindowName: "_self");
            } else {
              context.go("/");
            }
          },
          child: const Text("Sign out"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final isMobile = context.breakpoint < theme.breakpoints.sm;

    if (isMobile) {
      return Padding(
        padding: const .all(20),
        child: Center(child: _body(context, cs, tt)),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const .all(20),
          child: ShadCard(child: _body(context, cs, tt)),
        ),
      ),
    );
  }
}
