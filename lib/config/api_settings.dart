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

  /// Google 登录用的 iOS 客户端 ID（Google Cloud 对应 Firebase 项目里 iOS 类型的 OAuth 客户端）。
  /// 直接传给插件，不依赖 GoogleService-Info.plist 里的 CLIENT_ID（手动建的客户端 Firebase 不会写进 plist）。
  /// 它的倒序形式还要配在 Xcode 各 configuration 的 GOOGLE_REVERSED_CLIENT_ID 里作为回跳 scheme。
  String get googleIosClientId;

  /// Google 登录用的 Web 客户端 ID（同一项目里 Web application 类型的 OAuth 客户端）。
  /// Android 必须传它才能拿到 ID token；为空表示该环境还没配置。
  String get googleServerClientId;

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
  String get chatBotApiHost =>
      'https://chatbot-dev.synapsesinternational.ai/api/v1';

  @override
  String get chatBotApiToken => '6P6M7ciBXN8eMAyLsva8HOAKSyagfkfH';

  // miaid-dev 项目里 2026-10-09 手动创建的 iOS 客户端
  @override
  String get googleIosClientId =>
      '556738280205-lb1ts9dao517igt843ejgu6qrl50p7rb.apps.googleusercontent.com';

  // miaid-dev 项目里 Firebase 2026-10-10 自动创建的 Web 客户端
  @override
  String get googleServerClientId =>
      '556738280205-ldecgvjc4e5ie1aa6qrmakh4oit458e7.apps.googleusercontent.com';

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
  String get chatBotApiHost =>
      'https://chatbot-dev.synapsesinternational.ai/api/v1';

  @override
  String get chatBotApiToken => '6P6M7ciBXN8eMAyLsva8HOAKSyagfkfH';

  // miaid-dev 项目里 2026-10-09 手动创建的 iOS 客户端
  @override
  String get googleIosClientId =>
      '556738280205-lb1ts9dao517igt843ejgu6qrl50p7rb.apps.googleusercontent.com';

  // miaid-dev 项目里 Firebase 2026-10-10 自动创建的 Web 客户端
  @override
  String get googleServerClientId =>
      '556738280205-ldecgvjc4e5ie1aa6qrmakh4oit458e7.apps.googleusercontent.com';

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
  String get chatBotApiHost =>
      'https://chatbot.synapsesinternational.ai/api/v1';

  @override
  String get chatBotApiToken => '6P6M7ciBXN8eMAyLsva8HOAKSyagfkfH';

  // miaid-prod 项目里 2026-10-10 手动创建的 iOS 客户端
  @override
  String get googleIosClientId =>
      '294522101103-2ephs2nsismorecm75jf3dfl1i2v4js1.apps.googleusercontent.com';

  // miaid-prod 项目里 Firebase 2026-10-10 自动创建的 Web 客户端
  @override
  String get googleServerClientId =>
      '294522101103-p91tj3f8g9alddh8dlsurv9ae59tr5bt.apps.googleusercontent.com';

  @override
  String rewriteHost(String url) {
    return url;
  }
}
