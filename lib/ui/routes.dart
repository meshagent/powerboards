import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent/meshagent.dart';

import 'package:powerboards/chat/meshagent_room.dart';
import 'package:powerboards/meshagent/connection.dart';
import 'package:powerboards/meshagent/install_agent.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/oauth_response.dart';
import 'package:powerboards/meshagent/preselect_room.dart';
import 'package:powerboards/meshagent/rooms_list_builder.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/settings/selected_room.dart';

import 'empty_states.dart';
import 'login_button.dart';
import 'logout_card.dart';
import 'main_wrapper.dart';
import 'nav_page.dart';

const homeKey = ValueKey("home");

class _OAuthPayloadState {
  const _OAuthPayloadState({required this.redirectUri});

  final Uri redirectUri;

  String encode() {
    final map = {"redirect_uri": redirectUri.toString()};

    return base64Url.encode(utf8.encode(jsonEncode(map)));
  }

  factory _OAuthPayloadState.decode(String encoded) {
    final decoded = utf8.decode(base64Url.decode(encoded));
    final map = jsonDecode(decoded);

    return _OAuthPayloadState(redirectUri: Uri.parse(map["redirect_uri"]));
  }
}

class _InvokeSignIn extends StatefulWidget {
  const _InvokeSignIn({required this.signIn});

  final void Function(String? provider) signIn;

  @override
  State createState() => _InvokeSignInState();
}

class _InvokeSignInState extends State<_InvokeSignIn> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => widget.signIn(null));
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _SingInScreen extends StatefulWidget {
  const _SingInScreen({required this.isCancelled, required this.signIn});

  final bool isCancelled;
  final void Function(String provider) signIn;

  @override
  State createState() => _SingInScreenState();
}

class _SingInScreenState extends State<_SingInScreen> {
  late final oauthProviders = Resource<List<AuthProvider>>(listMeshagentOAuthProviders);

  Widget _inner(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final title = widget.isCancelled ? "Login cancelled" : "Sign in to Powerboards";

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: cs.primary),
            width: 44.0,
            height: 44.0,
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(8.0),

            child: SvgPicture(
              const AssetBytesLoader('lib/assets/powerboards-logo.vec'),
              colorFilter: ColorFilter.mode(cs.background, BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(title, style: tt.h3.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text("Powered by the MeshAgent platform.", style: tt.small.copyWith(color: const Color(0xFF8ECF3B))),

        const SizedBox(height: 32),
        Text("Continue to sign in to Powerboards.", style: tt.muted),
        const SizedBox(height: 32),

        SignalBuilder(
          builder: (context, _) {
            final isReady = oauthProviders.state.isReady;
            final providers = oauthProviders.state.value ?? [];

            if (!isReady) {
              return Center(child: CircularProgressIndicator());
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: 16.0,
              children: providers
                  .map(
                    (provider) => ProviderButton(
                      key: ValueKey(provider.id),
                      provider: provider,
                      signIn: (providerId) {
                        widget.signIn(providerId);
                      },
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    if (isMobile) {
      return SafeArea(
        child: Padding(padding: const EdgeInsets.all(32.0), child: _inner(context)),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ShadCard(
          padding: const EdgeInsets.all(50.0),
          rowMainAxisSize: MainAxisSize.max,
          rowMainAxisAlignment: MainAxisAlignment.center,
          columnCrossAxisAlignment: CrossAxisAlignment.center,
          child: _inner(context),
        ),
      ),
    );
  }
}

class _LoginFailed extends StatefulWidget {
  const _LoginFailed({required this.error, required this.errorCode, required this.errorDescription});

  final String error;
  final String errorCode;
  final String errorDescription;

  @override
  State createState() => _LoginFailedState();
}

class _LoginFailedState extends State<_LoginFailed> {
  bool showError = false;

  Widget _inner(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: cs.primary),
            width: 44.0,
            height: 44.0,
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture(
              const AssetBytesLoader('lib/assets/powerboards-logo.vec'),
              colorFilter: ColorFilter.mode(cs.background, BlendMode.srcIn),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Unable to sign in', style: tt.h3.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(
          "We couldn't sign you in at this time. "
          "This could be due to a temporary issue with the "
          "authentication service or an expired login session.",
          style: tt.muted,
        ),
        const SizedBox(height: 12),
        Text("Please try again, or use a different sign-in method if available.", style: tt.muted),

        const SizedBox(height: 16),
        if (showError)
          ShadCard(
            title: Text(widget.error),
            description: Text(widget.errorDescription),
            backgroundColor: cs.destructiveForeground,
            footer: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Error Code: ${widget.errorCode}", style: tt.small.copyWith(color: cs.destructive)),
            ),
          )
        else
          ShadButton.link(
            onPressed: () {
              setState(() {
                showError = true;
              });
            },
            child: Text("Show error details", style: tt.p.copyWith(fontWeight: FontWeight.w700)),
          ),

        const SizedBox(height: 32),
        ShadButton(
          onPressed: () {
            context.go('/');
          },
          child: Text("Continue"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    if (isMobile) {
      return SafeArea(
        child: Padding(padding: const EdgeInsets.all(32.0), child: _inner(context)),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ShadCard(
          padding: const EdgeInsets.all(50.0),
          rowMainAxisSize: MainAxisSize.max,
          rowMainAxisAlignment: MainAxisAlignment.center,
          columnCrossAxisAlignment: CrossAxisAlignment.center,
          child: _inner(context),
        ),
      ),
    );
  }
}

Widget signInBuilder(BuildContext context, bool isCancelled, void Function(String?) signIn) {
  if (kIsWeb) {
    return _InvokeSignIn(signIn: signIn);
  }

  return _SingInScreen(isCancelled: isCancelled, signIn: signIn);
}

Widget loginRequiredBuilder(BuildContext context, WidgetBuilder builder, Uri currentUri) {
  final config = MeshagentConfig.current;

  if (config == null) {
    return const Center(child: Text("Meshagent is not configured"));
  }

  final state = _OAuthPayloadState(redirectUri: currentUri);

  return LoginScope(
    serverUrl: config.serverUrl,
    callbackUrl: config.oauthCallbackUrl,
    oauthClientId: config.oauthClientId,
    onAuthenticated: (returnUrl) => context.go(returnUrl),
    signInBuilder: signInBuilder,
    builder: builder,
    scope: "email",
    extraQueryParams: {"state": state.encode()},
  );
}

final routes = [
  PathRoute.key(
    name: "view_home",
    path: "/",
    key: homeKey,
    builder: ((context, args) =>
        loginRequiredBuilder(context, (context) => NavPage(projectId: null, builder: (context, projects) => EmptyRooms()), args.uri)),
  ),

  PathRoute.key(
    name: "view_home",
    path: "/signout",
    key: homeKey,
    builder: ((context, args) => Center(
      child: Padding(padding: const EdgeInsets.all(20), child: LogoutCard()),
    )),
  ),

  PathRoute.keyBuilder(
    keyBuilder: (route) => ValueKey(route.parameters["project_id"]),
    path: "/mauth/callback",
    builder: (context, args) {
      final error = args.uri.queryParameters["error"];
      final errorCode = args.uri.queryParameters["error_code"];
      final errorDescription = args.uri.queryParameters["error_description"];
      final hasError = error != null || errorCode != null || errorDescription != null;

      if (hasError) {
        return _LoginFailed(
          error: error ?? "Unknown error",
          errorCode: errorCode ?? "unknown_error",
          errorDescription: errorDescription ?? "No description provided",
        );
      }

      final code = args.uri.queryParameters["code"];
      String redirectUri = args.uri.queryParameters["redirect_uri"] ?? "/";

      final config = MeshagentConfig.current!;
      final stateParam = args.uri.queryParameters["state"];

      if (stateParam != null) {
        final state = _OAuthPayloadState.decode(stateParam);
        redirectUri = state.redirectUri.toString();
      }

      return MAuthResponsePage(
        serverUrl: config.serverUrl,
        callbackUrl: config.oauthCallbackUrl,
        oauthClientId: config.oauthClientId,
        authorizationCode: code!,
        onAuthSuccess: () {
          context.go(redirectUri);
        },
      );
    },
  ),

  PathRoute.keyBuilder(
    name: "oauth_callback",
    keyBuilder: (route) => ValueKey(route.parameters["room_name"]),
    path: "/oauth2/callback",
    builder: (context, args) {
      final state = jsonDecode(args.uri.queryParameters["state"]!);
      final roomName = state["room_name"];
      final requestId = state["request_id"];

      final code = args.uri.queryParameters['code']!;
      final projectId = state["projectId"];

      return OAuthResponsePage(projectId: projectId, roomName: roomName, requestId: requestId, authorizationCode: code);
    },
  ),

  PathRoute.keyBuilder(
    name: 'view_room',
    path: '/p/{project_id}/r/{room_name}/a/{agent_id}',
    keyBuilder: (match) => kIsWeb ? homeKey : ValueKey(match.parameters["project_id"]),
    builder: ((context, args) {
      final projectId = toUUID(args.parameters["project_id"]!);
      final roomName = args.parameters["room_name"]!;
      final agentId = args.parameters["agent_id"]!;

      setLastSelectedRoom(projectId, roomName);

      return loginRequiredBuilder(context, (context) {
        final user = MeshagentAuth.current.getUser();
        final userId = user?['id'] as String?;

        if (userId == null) {
          return const Center(child: Text("User not logged in"));
        }

        return NavPage(
          projectId: projectId,
          selectedRoom: roomName,
          builder: (context, projects) => MeshagentConnectionBuilder(
            key: ValueKey("$projectId-$roomName"),
            projectId: projectId,
            projects: projects,
            roomName: roomName,
            builder: (context, room) => MeshagentRoom(projectId: projectId, projects: projects, room: room, service: agentId),
          ),
        );
      }, args.uri);
    }),
  ),

  PathRoute.keyBuilder(
    name: 'view_room',
    path: '/p/{project_id}/r/{room_name}',
    keyBuilder: (match) => kIsWeb ? homeKey : ValueKey(match.parameters["project_id"]),
    builder: ((context, args) {
      final projectId = toUUID(args.parameters["project_id"]!);
      final roomName = args.parameters["room_name"]!;

      setLastSelectedRoom(projectId, roomName);

      return loginRequiredBuilder(context, (context) {
        return NavPage(
          projectId: projectId,
          selectedRoom: roomName,
          builder: (context, projects) => MeshagentConnectionBuilder(
            key: ValueKey("$projectId-$roomName"),
            projectId: projectId,
            projects: projects,
            roomName: roomName,
            builder: (context, room) => MeshagentRoom(projectId: projectId, projects: projects, room: room),
          ),
        );
      }, args.uri);
    }),
  ),

  PathRoute.keyBuilder(
    name: 'install_agent',
    path: '/install',
    keyBuilder: (match) => kIsWeb ? homeKey : ValueKey(match.parameters["project_id"]),
    builder: (context, args) => loginRequiredBuilder(
      context,
      (context) => LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.minHeight - 200, maxHeight: constraints.maxHeight - 200, maxWidth: 800),
              child: ShadCard(
                title: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 25),
                  child: Text("Install a Powerboards Agent", style: ShadTheme.of(context).textTheme.h3, textAlign: TextAlign.center),
                ),
                child: AgentInstaller(initialUrl: Uri.tryParse(args.uri.queryParameters["url"] ?? "")),
              ),
            ),
          ],
        ),
      ),
      args.uri,
    ),
  ),

  PathRoute.keyBuilder(
    name: 'view_room',
    path: '/p/{project_id}',
    keyBuilder: (match) => kIsWeb ? homeKey : ValueKey(match.parameters["project_id"]),
    builder: ((context, args) {
      final pid = args.parameters["project_id"]!;
      final projectId = toUUID(pid);

      return loginRequiredBuilder(context, (context) {
        return NavPage(
          projectId: projectId,
          builder: (context, projects) => RoomsListBuilder(
            projectId: projectId,
            builder: (context, rooms) {
              return PreselectRoom(
                key: ValueKey("preselect-$projectId"),
                projectId: projectId,
                rooms: rooms,
                child: FutureBuilder<bool>(
                  future: getMeshagentClient().canCreateRooms(projectId),
                  builder: (context, snapshot) {
                    final canCreateRooms = snapshot.data ?? false;

                    return MainWrapper(
                      projectId: projectId,
                      projects: projects,
                      child: EmptyRooms(
                        onCreateRoom: canCreateRooms
                            ? () async {
                                final room = await createMeshagentRoom(context, projectId);
                                if (room != null && context.mounted) {
                                  context.go("/p/$pid/r/${room.name}");
                                }
                              }
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      }, args.uri);
    }),
  ),
];
