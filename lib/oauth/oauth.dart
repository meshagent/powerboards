import 'package:meshagent/meshagent.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

Future<Uri> oauth2Authenticate(OAuthTokenRequest request, Uri redirectUri, String state) async {
  final callbackUrlScheme = "powerboards";

  String url = await FlutterWebAuth2.authenticate(
    url: Uri.parse(request.authorizationEndpoint)
        .replace(
          queryParameters: {
            "response_type": "code",
            "state": state,
            "redirect_uri": redirectUri.toString(),
            "client_id": request.clientId,
            if (request.challenge != null) "code_challenge": request.challenge,
            if (request.challenge != null) "code_challenge_method": "S256",
            if (request.scopes != null) "scope": request.scopes!.join(","),
          },
        )
        .toString(),
    callbackUrlScheme: callbackUrlScheme,
    options: FlutterWebAuth2Options(windowName: "_self"),
  );

  return Uri.parse(url);
}

String? oauth2AuthorizationCode(Uri uri) {
  return uri.queryParameters['code'];
}
