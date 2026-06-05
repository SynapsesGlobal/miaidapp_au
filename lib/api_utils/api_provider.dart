import 'package:chopper/chopper.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:injectable/injectable.dart';

import 'authentication_interceptor.dart';

@singleton
class ApiProvider {
  ApiProvider({
    required this.apiSettings,
    required this.userProvider,
  }) {
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
        interceptors: [
          AuthenticationInterceptor(
            apiKey,
            () => userProvider.user?.accessToken ?? '',
          ),
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
