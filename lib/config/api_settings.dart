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

  String rewriteHost(String url);
}

@dev
@Injectable(as: ApiSettings)
class DevApiSettings implements ApiSettings {
  @override
  String get apiKey => '123-123-123-123';

  @override
  String get endpoint => 'https://miaid-main.weboostapp.com/api/v1';

  @override
  String get baseUrl => 'https://miaid-main.weboostapp.com';

  @override
  String get apiKeySub => '123-123-123-123';

  @override
  String get endpointSub => 'https://miaid-sub-au.weboostapp.com/api/v1';

  @override
  String get baseUrlSub => 'https://miaid-sub-au.weboostapp.com';

  @override
  String rewriteHost(String url) {
    return url.replaceAll('localhost:8000', '192.168.1.75:8000');
  }
}

@sandbox
@Injectable(as: ApiSettings)
class SandboxApiSettings implements ApiSettings {
  @override
  String get apiKey => '123-123-123-123';

  @override
  String get endpoint => 'https://miaid-main.weboostapp.com/api/v1';

  @override
  String get baseUrl => 'https://miaid-main.weboostapp.com';

  @override
  String get apiKeySub => '123-123-123-123';

  @override
  String get endpointSub => 'https://miaid-sub-au.weboostapp.com/api/v1';

  @override
  String get baseUrlSub => 'https://miaid-sub-au.weboostapp.com';

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
  String rewriteHost(String url) {
    return url;
  }
}
