import 'dart:async';
import 'dart:collection';

import 'package:chopper/chopper.dart';

class AuthenticationInterceptor implements RequestInterceptor {
  final String apiKey;
  final String Function() accessTokenProvider;

  AuthenticationInterceptor(this.apiKey, this.accessTokenProvider);

  @override
  FutureOr<Request> onRequest(Request request) {
    Map<String, String> headers = HashMap.from(request.headers);
    headers['x-access-token'] = accessTokenProvider();
    headers['x-api-key'] = apiKey;
    if (headers['Accept'] == null) {
      headers['Accept'] = 'application/json';
    }
    return request.copyWith(headers: headers);
  }

  static Map<String, String> authHeaders(String apiKey, String accessToken) {
    final headers = HashMap<String, String>();
    headers['x-access-token'] = accessToken;
    headers['x-api-key'] = apiKey;
    return headers;
  }
}
