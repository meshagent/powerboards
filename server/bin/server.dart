import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

const webRoot = 'public';
const index = 'index.html';

Middleware corsControlMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final origin = request.headers['Origin'];
      final corsHeaders = <String, Object>{};

      if (origin != null && origin.isNotEmpty) {
        corsHeaders[HttpHeaders.accessControlAllowOriginHeader] = origin;
        corsHeaders[HttpHeaders.accessControlAllowCredentialsHeader] = 'true';
        corsHeaders[HttpHeaders.accessControlAllowMethodsHeader] =
            'GET,POST,DELETE,OPTIONS';
      }

      if (request.method == 'OPTIONS') {
        return Response.ok(null, headers: corsHeaders);
      }

      final response = await innerHandler(request);

      return response.change(headers: {...response.headers, ...corsHeaders});
    };
  };
}

Middleware handleRedirects() {
  return (Handler inner) {
    return (Request request) async {
      final host = request.headers['host'];

      if (host == null) {
        return inner(request);
      }

      if (host == 'localhost' || host.startsWith('localhost:')) {
        return inner(request);
      }

      final hasSubdomain = '.'.allMatches(host).length >= 2;
      if (!hasSubdomain) {
        final newHost = redirectToApp ? 'app.$host' : 'www.$host';
        final newUri = request.requestedUri.replace(host: newHost);

        return Response.found(newUri.toString());
      }

      if (host.startsWith('www.') && redirectToApp) {
        final newHost = 'app.${host.substring(4)}';
        final newUri = request.requestedUri.replace(host: newHost);

        return Response.found(newUri.toString());
      }

      return inner(request);
    };
  };
}

Router setupRoutes() {
  final router = Router();
  final indexFile = File(p.join(webRoot, index));

  final rootHandler = createStaticHandler(
    webRoot,
    serveFilesOutsidePath: false,
  );

  router.mount(
    '/assets/',
    createStaticHandler(
      p.join(webRoot, 'assets'),
      serveFilesOutsidePath: false,
    ),
  );
  router.mount(
    '/canvaskit/',
    createStaticHandler(
      p.join(webRoot, 'canvaskit'),
      serveFilesOutsidePath: false,
    ),
  );

  if (Directory(p.join(webRoot, 'config')).existsSync()) {
    router.mount(
      '/config/',
      createStaticHandler(
        p.join(webRoot, 'config'),
        serveFilesOutsidePath: false,
      ),
    );
  }

  router.mount(
    '/.well-known/',
    createStaticHandler(
      p.join(webRoot, '.well-known'),
      serveFilesOutsidePath: false,
    ),
  );

  router.get('/favicon.ico', rootHandler);
  router.get('/flutter_bootstrap.js', rootHandler);
  router.get('/flutter.js', rootHandler);
  router.get('/flutter_service_worker.js', rootHandler);
  router.get('/main.dart.js', rootHandler);
  router.get('/manifest.json', rootHandler);
  router.get('/version.json', rootHandler);
  router.get(
    '/<ignored|.*>',
    (Request req) => Response.ok(
      indexFile.openRead(),
      headers: {'content-type': 'text/html; charset=utf-8'},
    ),
  );

  return router;
}

bool redirectToApp = false;
void main(List<String> arguments) async {
  final parser =
      ArgParser()..addFlag(
        'redirect-to-app',
        defaultsTo: false, // 👈 explicit default
        negatable: false, // prevents --no-redirect-to-app
        help: 'Redirect www.example.com to app.example.com',
      );

  final results = parser.parse(arguments);

  redirectToApp = results['redirect-to-app'] as bool;

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(handleRedirects())
      .addMiddleware(corsControlMiddleware())
      .addHandler(setupRoutes().call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 80);

  server.autoCompress = true;
}
