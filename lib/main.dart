import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:powerboards/ui/error_states.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:screenshot/screenshot.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:url_strategy/url_strategy.dart';
// ignore: depend_on_referenced_packages
import 'package:meshagent_luau/meshagent_luau.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'powerboards_router/powerboards_router.dart';
import 'powerboards_controller/powerboards_controller.dart';

import 'firebase.dart';
import 'logical_keyboard_monitor/logical_keyboard_monitor.dart';
import 'meshagent/meshagent.dart';
import 'nav/chrome_visibility.dart';
import 'nav/nav.dart';
import 'theme/theme.dart';
import 'ui/link_listener.dart';
import 'ui/meeting_view.dart';
import 'ui/routes.dart';
import 'ui/top_banner.dart';
import 'web_context_menu_manager/web_context_menu_manager.dart';

final uiRoot = GlobalKey();

const breakpoints = [
  Breakpoint(start: 0, end: 600, name: MOBILE),
  Breakpoint(start: 601, end: 960, name: TABLET),
  Breakpoint(start: 961, end: 1250, name: "chromebook"),
  Breakpoint(start: 961, end: 1920, name: DESKTOP),
  Breakpoint(start: 1921, end: double.infinity, name: '4K'),
];

const breakpointsLandscape = [
  Breakpoint(start: 0, end: 960, name: MOBILE),
  Breakpoint(start: 961, end: 1920, name: TABLET),
  Breakpoint(start: 1366, end: 1600, name: "chromebook"),
  Breakpoint(start: 1601, end: 2560, name: DESKTOP),
  Breakpoint(start: 2561, end: double.infinity, name: '4K'),
];

void main() async {
  if (kIsWeb) {
    Luau.init();
  }

  SolidartConfig.assertSignalBuilderWithoutDependencies = false;

  const sentryEnabled = bool.fromEnvironment('SENTRY_ENABLED', defaultValue: false);
  const sentryRelease = String.fromEnvironment('SENTRY_RELEASE');
  const sentryEnvironment = String.fromEnvironment('SENTRY_ENVIRONMENT');

  if (sentryEnabled) {
    await SentryFlutter.init((options) {
      if (sentryRelease.isNotEmpty) {
        options.release = sentryRelease;
      }
      if (sentryEnvironment.isNotEmpty) {
        options.environment = sentryEnvironment;
      }
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
    }, appRunner: startApp);
  } else {
    runZonedGuarded(
      startApp,
      (object, stackTrace) {
        debugPrint("Unhandled exception $object $stackTrace");
      },
      zoneSpecification: ZoneSpecification(
        handleUncaughtError: (self, parent, zone, error, stackTrace) {
          debugPrint("Unhandled exception handled $error $stackTrace");
        },
      ),
    );
  }
}

Future<void> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();

  await initializeApp();
  await initLocalStorage();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // keep status bar transparent
      statusBarIconBrightness: Brightness.dark, // ANDROID: dark icons on light bg
      statusBarBrightness: Brightness.light, // iOS: status bar text dark on light bg
    ),
  );

  MeshagentConfig.current = MeshagentConfig.fromEnvironment();

  final uri = kIsWeb ? null : await appLinks.getInitialLink();
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

  if (!kIsWeb) {
    if (kReleaseMode || const bool.fromEnvironment("FIREBASE_INITIALIZE")) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  }
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
        colorScheme: ShadColorScheme.fromName("neutral"),
        brightness: Brightness.light,
        textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
      ),

      builder: (context, child) {
        final media = MediaQuery.of(context);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(textScale)),
            child: DefaultTextStyle(
              style: GoogleFonts.inter(fontSize: 14),
              child: _RootProviders(
                child: LinksWatcher(
                  navigatorKey: configuration.routerDelegate.navigatorKey,
                  child: TopBanner(child: child!),
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

  @override
  void dispose() {
    super.dispose();

    documentRecorder.currentState?.dispose();
    documentPlayer.currentState?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadTheme(
      data: ShadThemeData(
        colorScheme: ShadColorScheme.fromName("neutral"),
        brightness: Brightness.light,
        textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
      ),
      child: ChromeVisibility(
        child: Material(
          type: MaterialType.transparency,
          child: Directionality(
            key: uiRoot,
            textDirection: TextDirection.ltr,
            child: ResponsiveBreakpoints.builder(
              breakpoints: breakpoints,
              breakpointsLandscape: breakpointsLandscape,
              child: ControllerProvider(
                controller: navController,
                child: ControllerProvider(
                  controller: meetingViewController,
                  child: Portal(child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
