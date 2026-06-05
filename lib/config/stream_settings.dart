import 'package:injectable/injectable.dart';
import 'package:miaid/utils/configure_dependencies.dart';

abstract class StreamSettings {
  StreamSettings({
    required this.apiKey,
    required this.region,
    required this.appId,
  });

  final String apiKey;
  final String region;
  final String appId;
}

@dev
@Injectable(as: StreamSettings)
class DevStreamSettings implements StreamSettings {
  @override
  String get apiKey => 'fac7a8798244a4417e9d204a9cc40e4a732ed251';
  @override
  String region = "EU";
  @override
  String appId = "244146b5f9580653";
}

@sandbox
@Injectable(as: StreamSettings)
class SandboxStreamSettings implements StreamSettings {
  @override
  String get apiKey => 'b4042539ba64d41e0bd9fb1a0e4eb9a415ea6f11';
  @override
  String get region => "EU";
  @override
  String get appId => "2493841c3811c98d";
}

@prod
@Injectable(as: StreamSettings)
class ProdStreamSettings implements StreamSettings {
  @override
  String get apiKey => 'b4042539ba64d41e0bd9fb1a0e4eb9a415ea6f11';
  @override
  String get region => "EU";
  @override
  String get appId => "2493841c3811c98d";
}
