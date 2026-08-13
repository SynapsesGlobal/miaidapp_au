import 'package:injectable/injectable.dart';
import 'package:miaid/utils/configure_dependencies.dart';

abstract class ApiSettings {
  ApiSettings({
    required this.apiKey,
    required this.apiKeySub,
    required this.endpoint,
    required this.endpointSub,
    required this.baseUrl,
    required this.baseUrlSub,
  });

  final String apiKey;
  final String apiKeySub;
  final String endpoint;
  final String endpointSub;
  final String baseUrl;
  final String baseUrlSub;

  String get marketingApiHost;
  String get marketingApiKey;
  String get chatBotApiHost;
  String get chatBotApiToken;

  String rewriteHost(String url);
}

@dev
@Injectable(as: ApiSettings)
class DevApiSettings implements ApiSettings {
  @override
  String get apiKey => '123-123-123-123';

  @override
  String get endpoint => 'https://portal-dev.mi-aid.com.au/api/v1';

  @override
  String get baseUrl => 'https://portal-dev.mi-aid.com.au';

  @override
  String get apiKeySub => '123-123-123-123';

  @override
  String get endpointSub => 'https://admin-dev.mi-aid.com.au/api/v1';

  @override
  String get baseUrlSub => 'https://admin-dev.mi-aid.com.au';

  @override
  String get marketingApiHost => 'https://admin-dev.miaidpartners.com/api';

  @override
  String get marketingApiKey => 'MNQZMEIOo52S1fdnWDSzTSRhH8ekQPNn';

  @override
  String get chatBotApiHost => 'https://chatbot-dev.synapsesinternational.ai/api/v1';

  @override
  String get chatBotApiToken => '6P6M7ciBXN8eMAyLsva8HOAKSyagfkfH';

  @override
  String rewriteHost(String url) {
    return url;
  }
}

@sandbox
@Injectable(as: ApiSettings)
class SandboxApiSettings implements ApiSettings {
  @override
  String get apiKey => '123-123-123-123';

  @override
  String get endpoint => 'https://portal-dev.mi-aid.com.au/api/v1';

  @override
  String get baseUrl => 'https://portal-dev.mi-aid.com.au';

  @override
  String get apiKeySub => '123-123-123-123';

  @override
  String get endpointSub => 'https://admin-dev.mi-aid.com.au/api/v1';

  @override
  String get baseUrlSub => 'https://admin-dev.mi-aid.com.au';

  @override
  String get marketingApiHost => 'https://admin-dev.miaidpartners.com/api';

  @override
  String get marketingApiKey => 'MNQZMEIOo52S1fdnWDSzTSRhH8ekQPNn';

  @override
  String get chatBotApiHost => 'https://chatbot-dev.synapsesinternational.ai/api/v1';

  @override
  String get chatBotApiToken => '6P6M7ciBXN8eMAyLsva8HOAKSyagfkfH';

  @override
  String rewriteHost(String url) {
    return url;
  }
}

@prod
@Injectable(as: ApiSettings)
class ProdApiSettings implements ApiSettings {
  @override
  String get apiKey => '123-123-123-123';

  @override
  String get endpoint => 'https://portal.mi-aid.com.au/api/v1';

  @override
  String get baseUrl => 'https://portal.mi-aid.com.au';

  @override
  String get apiKeySub => '123-123-123-123';

  @override
  String get endpointSub => 'https://admin.mi-aid.com.au/api/v1';

  @override
  String get baseUrlSub => 'https://admin.mi-aid.com.au';

  @override
  String get marketingApiHost => 'https://admin.miaidpartners.com/api';

  @override
  String get marketingApiKey => 'MNQZMEIOo52S1fdnWDSzTSRhH8ekQPNn';

  @override
  String get chatBotApiHost => 'https://chatbot.synapsesinternational.ai/api/v1';

  @override
  String get chatBotApiToken => '6P6M7ciBXN8eMAyLsva8HOAKSyagfkfH';

  @override
  String rewriteHost(String url) {
    return url;
  }
}
