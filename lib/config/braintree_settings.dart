import 'package:injectable/injectable.dart';
import 'package:miaid/utils/configure_dependencies.dart';

abstract class BraintreeSettings {
  BraintreeSettings({required this.tokenizationKey});

  final String tokenizationKey;
}

@dev
@Injectable(as: BraintreeSettings)
class DevBraintreeSettings implements BraintreeSettings {
  @override
  String get tokenizationKey => 'sandbox_243zmtxn_b8wnqk3cvc86sgk3';
}

@sandbox
@Injectable(as: BraintreeSettings)
class SandboxBraintreeSettings implements BraintreeSettings {
  @override
  String get tokenizationKey => 'sandbox_243zmtxn_b8wnqk3cvc86sgk3';
}

@prod
@Injectable(as: BraintreeSettings)
class ProdBraintreeSettings implements BraintreeSettings {
  @override
  // TODO
  String get tokenizationKey => 'TODO';
}
