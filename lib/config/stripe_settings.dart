import 'package:injectable/injectable.dart';
import 'package:miaid/utils/configure_dependencies.dart';

abstract class StripeSettings {
  StripeSettings({
    required this.publishableKey,
    required this.isTestEnvironment,
  });

  final String publishableKey;
  final bool isTestEnvironment;
}

@dev
@Injectable(as: StripeSettings)
class DevStripeSettings implements StripeSettings {
  @override
  String get publishableKey => 'pk_test_mKeqwmvc9iZjij8icv575Yls';

  @override
  bool get isTestEnvironment => true;
}

@sandbox
@Injectable(as: StripeSettings)
class SandboxStripeSettings implements StripeSettings {
  @override
  String get publishableKey => 'pk_test_mKeqwmvc9iZjij8icv575Yls';

  @override
  bool get isTestEnvironment => true;
}

@prod
@Injectable(as: StripeSettings)
class ProdStripeSettings implements StripeSettings {
  @override
  String get publishableKey => 'pk_live_6CNriW3ulwfhdATUZU7RUmPw';

  @override
  bool get isTestEnvironment => false;
}
