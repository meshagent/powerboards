import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent_flutter_desktop_updater/meshagent_flutter_desktop_updater.dart';
import 'package:meshagent_flutter_dev/meshagent_flutter_dev.dart';
import 'package:meshagent_flutter_shadcn/code_editor.dart';
import 'package:meshagent_flutter_shadcn/web_context_menu_manager.dart';
import 'package:powerboards/ui/error_states.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:url_strategy/url_strategy.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'powerboards_router/powerboards_router.dart';
import 'powerboards_controller/powerboards_controller.dart';

import 'logical_keyboard_monitor/logical_keyboard_monitor.dart';
import 'meshagent/meshagent.dart';
import 'meshagent/room_lifecycle_errors.dart';
import 'nav/chrome_visibility.dart';
import 'nav/nav.dart';
import 'pdf/pdf_backend.dart';
import 'theme/theme.dart';
import 'ui/incoming_share_watcher.dart';
import 'ui/powerboards_breakpoints.dart';
import 'ui/link_listener.dart';
import 'ui/meeting_view.dart';
import 'ui/powerboards_adaptive_input.dart';
import 'ui/powerboards_shad_dialog.dart';
import 'ui/powerboards_toast_theme.dart';
import 'ui/routes.dart';
import 'ui/top_banner.dart';
import 'updates/powerboards_desktop_update_banner.dart';
import 'settings/shared_profiles.dart';
import 'settings/ui_mode.dart';

final uiRoot = GlobalKey();

ShadDecoration? _powerboardsDecorationThemeForContext(BuildContext context) {
  if (!powerboardsUsesMobileFieldLabelStyle(context)) {
    return null;
  }

  return ShadDecoration(labelStyle: powerboardsMobileFieldLabelTextStyle(powerboardsShadColorScheme().foreground));
}

ShadCheckboxTheme _powerboardsCheckboxThemeForContext(BuildContext context) {
  return ShadCheckboxTheme(
    decoration: ShadDecoration(border: ShadBorder.all(radius: const BorderRadius.all(Radius.circular(6)))),
  );
}

ShadDialogTheme _powerboardsDialogThemeForContext(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  final screenWidth = mediaQuery?.size.width ?? 1024.0;
  final screenHeight = mediaQuery?.size.height ?? 768.0;
  final isMobile = screenWidth < 600;
  final mobileInset = powerboardsMobileDialogEdgeInset * 2;
  final maxWidth = isMobile ? ((screenWidth - mobileInset) > 0 ? screenWidth - mobileInset : screenWidth) : 512.0;
  final maxHeight = (screenHeight - mobileInset) > 0 ? screenHeight - mobileInset : screenHeight;
  final closeTop = isMobile ? 24.0 : 20.0;
  final closeEnd = 24.0;

  return ShadDialogTheme(
    backgroundColor: shadCard,
    constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
    radius: BorderRadius.circular(20),
    removeBorderRadiusWhenTiny: false,
    closeIconPosition: ShadPosition(top: closeTop, right: closeEnd),
  );
}

BorderRadius _powerboardsButtonRadiusForContext(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  final screenWidth = mediaQuery?.size.width ?? 1024.0;
  return BorderRadius.circular(screenWidth < 600 ? 12 : 6);
}

void _configureDebugPrintFilter() {
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) {
      return;
    }
    if (message.startsWith('get language error:')) {
      return;
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };
}

bool _isExpectedWebHotRestartViewDispose(Object error, [StackTrace? stackTrace]) {
  if (!(kDebugMode && kIsWeb)) {
    return false;
  }

  final errorText = '$error';
  final stackText = stackTrace?.toString() ?? '';
  return errorText.contains('Trying to render a disposed EngineFlutterView') ||
      (errorText.contains('org-dartlang-sdk:///lib/_engine/engine/window.dart:99:12') &&
          stackText.contains('Trying to render a disposed EngineFlutterView'));
}

bool _isExpectedRoomClientDisposed(Object error, [StackTrace? stackTrace]) {
  return powerboardsIsExpectedRoomLifecycleClosure(error, stackTrace);
}

void main() async {
  SolidartConfig.assertSignalBuilderWithoutDependencies = false;

  WidgetsFlutterBinding.ensureInitialized();
  configurePowerboardsPdfBackend();

  // If SERVER_URL is in the environment, it means the config was complied in. Use it.
  const serverUrl = String.fromEnvironment("SERVER_URL");
  if (serverUrl.isNotEmpty) {
    MeshagentConfig.current = MeshagentConfig.fromEnvironment();
  } else {
    // Get the config from the website
    final configUri = Uri.parse("/config/config.json");
    MeshagentConfig.current = await MeshagentConfig.fromUri(configUri);
  }

  final config = MeshagentConfig.current!;

  if (config.sentryEnabled) {
    await SentryFlutter.init((options) {
      options.dsn = config.sentryDsn;
      if (config.sentryRelease.isNotEmpty) {
        options.release = config.sentryRelease;
      }
      if (config.sentryEnvironment.isNotEmpty) {
        options.environment = config.sentryEnvironment;
      }
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      // ignore: experimental_member_use
      options.profilesSampleRate = 1.0;
    }, appRunner: startApp);
  } else {
    runZonedGuarded(
      startApp,
      (object, stackTrace) {
        if (_isExpectedRoomClientDisposed(object, stackTrace)) {
          return;
        }
        debugPrint("Unhandled exception $object $stackTrace");
      },
      zoneSpecification: ZoneSpecification(
        handleUncaughtError: (self, parent, zone, error, stackTrace) {
          if (_isExpectedRoomClientDisposed(error, stackTrace)) {
            return;
          }
          debugPrint("Unhandled exception handled $error $stackTrace");
        },
      ),
    );
  }
}

Future<void> startApp() async {
  _configureDebugPrintFilter();
  final originalFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_isExpectedWebHotRestartViewDispose(details.exception, details.stack) ||
        _isExpectedRoomClientDisposed(details.exception, details.stack)) {
      return;
    }
    originalFlutterErrorHandler?.call(details);
  };
  setPathUrlStrategy();

  await initializeApp();
  await initLocalStorage();
  await initializeCodeEditor();
  await initializeMeshagentTerminalRuntime();
  initializePowerboardsUiMode();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // keep status bar transparent
      statusBarIconBrightness: Brightness.dark, // ANDROID: dark icons on light bg
      statusBarBrightness: Brightness.light, // iOS: status bar text dark on light bg
    ),
  );

  await applySharedProfileConfigIfSupported();
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows)) {
    MeshagentConfig.current = await MeshagentConfig.current!.withDeploymentConfig();
  }
  await hydrateSharedProfileAuthIfSupported();

  final initialLink = kIsWeb ? null : await appLinks.getInitialLink();
  final uri = initialLink != null && isShareMediaUri(initialLink) ? null : initialLink;
  final screenshotController = ScreenshotController();

  runApp(
    Screenshot(
      controller: screenshotController,
      child: Material(
        color: Colors.white,
        child: WebContextMenuManager(child: MyApp(uri)),
      ),
    ),
  );
}

Future<void> initializeApp() async {
  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  await initializeFlutterDocumenRuntime();
  await Highlighter.initialize(['dart', 'sql', 'yaml']);

  LogicalKeyboardMonitor.start();
}

class MyApp extends StatelessWidget {
  final Uri? uri;
  late final PathRouteConfiguration configuration;

  MyApp(this.uri, {super.key}) {
    configuration = setupPathRouter(
      notFound: PathRoute(
        path: "404",
        builder: (context, route) => NotFound(uri: route.uri),
      ),
      routes: routes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp.router(
      title: 'Powerboards',
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ShadThemeData(
        colorScheme: powerboardsShadColorScheme(),
        brightness: Brightness.light,
        radius: _powerboardsButtonRadiusForContext(context),
        textTheme: powerboardsShadTextTheme(),
        decoration: _powerboardsDecorationThemeForContext(context),
        checkboxTheme: _powerboardsCheckboxThemeForContext(context),
        primaryBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        secondaryBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        destructiveBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        outlineBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        primaryToastTheme: powerboardsToastThemeForContext(context),
        destructiveToastTheme: powerboardsToastThemeForContext(context, destructive: true),
        selectTheme: ShadSelectTheme(
          decoration: ShadDecoration(border: ShadBorder.all(color: shadBorder, width: 1)),
        ),
        tabsTheme: ShadTabsTheme(
          tabBackgroundColor: shadCard,
          tabDecoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
        ),
        primaryDialogTheme: _powerboardsDialogThemeForContext(context),
        alertDialogTheme: _powerboardsDialogThemeForContext(context),
        popoverTheme: ShadPopoverTheme(
          decoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
        ),
        contextMenuTheme: ShadContextMenuTheme(
          backgroundColor: shadCard,
          decoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
          selectedBackgroundColor: shadMuted,
        ),
        menubarTheme: ShadMenubarTheme(
          backgroundColor: shadCard,
          decoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
        ),
        outlineButtonTheme: ShadButtonTheme(
          backgroundColor: shadCard,
          decoration: ShadDecoration(border: ShadBorder.all(color: shadBorder, width: 1)),
        ),
      ),

      builder: (context, child) {
        final media = MediaQuery.of(context);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(textScale)),
            child: DefaultTextStyle(
              style: powerboardsInterTextStyle(fontSize: 14),
              child: ShadToaster(
                child: _RootProviders(
                  child: IncomingShareWatcher(
                    navigatorKey: configuration.routerDelegate.navigatorKey,
                    child: LinksWatcher(
                      navigatorKey: configuration.routerDelegate.navigatorKey,
                      child: TopBanner(child: child!),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      routeInformationParser: configuration.routeInformationParser,
      routerDelegate: configuration.routerDelegate,
    );
  }
}

class _RootProviders extends StatefulWidget {
  const _RootProviders({required this.child});

  final Widget child;

  @override
  State createState() => _RootProvidersState();
}

class _RootProvidersState extends State<_RootProviders> {
  final documentRecorder = GlobalKey();
  final documentPlayer = GlobalKey();
  final navController = NavController();
  final meetingViewController = MeetingViewController();
  late final desktopUpdateController = DesktopUpdateController(config: DesktopUpdateConfig.fromEnvironment());

  @override
  void initState() {
    super.initState();
    desktopUpdateController.startUpdateChecks();
  }

  @override
  void dispose() {
    documentRecorder.currentState?.dispose();
    documentPlayer.currentState?.dispose();
    desktopUpdateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context).copyWith(
      popupMenuTheme: PopupMenuThemeData(
        color: shadCard,
        surfaceTintColor: shadCard,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: shadBorder, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(shadCard),
          surfaceTintColor: const WidgetStatePropertyAll(shadCard),
          side: const WidgetStatePropertyAll(BorderSide(color: shadBorder, width: 1)),
          shape: WidgetStateProperty.all<OutlinedBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
        ),
      ),
    );
    return ShadTheme(
      data: ShadThemeData(
        colorScheme: powerboardsShadColorScheme(),
        brightness: Brightness.light,
        radius: _powerboardsButtonRadiusForContext(context),
        textTheme: powerboardsShadTextTheme(),
        decoration: _powerboardsDecorationThemeForContext(context),
        checkboxTheme: _powerboardsCheckboxThemeForContext(context),
        primaryBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        secondaryBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        destructiveBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        outlineBadgeTheme: const ShadBadgeTheme(padding: powerboardsBadgePadding),
        primaryToastTheme: powerboardsToastThemeForContext(context),
        destructiveToastTheme: powerboardsToastThemeForContext(context, destructive: true),
        selectTheme: ShadSelectTheme(
          decoration: ShadDecoration(border: ShadBorder.all(color: shadBorder, width: 1)),
        ),
        tabsTheme: ShadTabsTheme(
          tabBackgroundColor: shadCard,
          tabDecoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
        ),
        primaryDialogTheme: _powerboardsDialogThemeForContext(context),
        alertDialogTheme: _powerboardsDialogThemeForContext(context),
        popoverTheme: ShadPopoverTheme(
          decoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
        ),
        contextMenuTheme: ShadContextMenuTheme(
          backgroundColor: shadCard,
          decoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
          selectedBackgroundColor: shadMuted,
        ),
        menubarTheme: ShadMenubarTheme(
          backgroundColor: shadCard,
          decoration: ShadDecoration(
            color: shadCard,
            border: ShadBorder.all(color: shadBorder, width: 1),
          ),
        ),
        outlineButtonTheme: ShadButtonTheme(
          backgroundColor: shadCard,
          decoration: ShadDecoration(border: ShadBorder.all(color: shadBorder, width: 1)),
        ),
      ),
      child: ChromeVisibility(
        child: Theme(
          data: materialTheme,
          child: Material(
            type: MaterialType.transparency,
            child: Directionality(
              key: uiRoot,
              textDirection: TextDirection.ltr,
              child: powerboardsResponsiveBreakpoints(
                child: ControllerProvider(
                  controller: navController,
                  child: ControllerProvider(
                    controller: meetingViewController,
                    child: Portal(
                      child: DesktopUpdateControllerScope(
                        controller: desktopUpdateController,
                        child: PowerboardsDesktopUpdateBanner(controller: desktopUpdateController, child: widget.child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
