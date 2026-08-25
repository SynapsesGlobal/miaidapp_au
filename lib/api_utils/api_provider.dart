import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:injectable/injectable.dart';

import 'authentication_interceptor.dart';
import 'session_revoked_interceptor.dart';

@singleton
class ApiProvider {
  ApiProvider({
    required this.apiSettings,
    required this.userProvider,
  }) {
    // ignore: avoid_print
    print('[ENV-CHECK] ApiSettings=${apiSettings.runtimeType} endpoint=${apiSettings.endpoint} sub=${apiSettings.endpointSub}');
    apiClientMain = _createApiClient(apiSettings.endpoint, apiSettings.apiKey);
    apiClientSub =
        _createApiClient(apiSettings.endpointSub, apiSettings.apiKeySub);
  }

  ApiSettings apiSettings;
  UserProvider userProvider;

  late ApiClient apiClientMain;
  late ApiClient apiClientSub;

  ApiClient _createApiClient(String endpoint, String apiKey) {
    return ApiClient.create(
      ChopperClient(
        client: _TimeoutHttpClient(),
        interceptors: [
          AuthenticationInterceptor(
            apiKey,
            () => userProvider.user?.accessToken ?? '',
          ),
          SessionRevokedInterceptor(),
          HttpLoggingInterceptor(),
        ],
        converter: $JsonSerializableConverter(),
        errorConverter: $JsonSerializableConverter(),
        baseUrl: endpoint,
      ),
    );
  }

  ApiClient get apiClient {
    if (userProvider.isDoctor || userProvider.isTranslator) {
      return apiClientMain;
    } else {
      return apiClientSub;
    }
  }

  String get baseUrl {
    if (userProvider.isDoctor || userProvider.isTranslator) {
      return apiSettings.baseUrl;
    } else {
      return apiSettings.baseUrlSub;
    }
  }

  String get apiKey {
    if (userProvider.isDoctor || userProvider.isTranslator) {
      return apiSettings.apiKey;
    } else {
      return apiSettings.apiKeySub;
    }
  }
}

/// 弱网或 Wi-Fi/蜂窝切换后复用已死的 TCP 连接时，默认 HttpClient 没有任何
/// 超时，请求会无限挂起（后端收不到请求，界面停在 Connecting）。
/// 这里统一限制建立连接和等待响应头的时间；响应体的下载不受此限制。
class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient()
      : _inner = IOClient(
          HttpClient()..connectionTimeout = const Duration(seconds: 10),
        );

  final http.Client _inner;

  static const Duration _responseTimeout = Duration(seconds: 30);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(_responseTimeout);

  @override
  void close() => _inner.close();
}
