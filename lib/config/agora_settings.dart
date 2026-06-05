import 'package:injectable/injectable.dart';
import 'package:miaid/utils/configure_dependencies.dart';

abstract class AgoraSettings {
  AgoraSettings({
    required this.appId,
  });

  final String appId;
}

@dev
@Injectable(as: AgoraSettings)
class DevAgoraSettings implements AgoraSettings {
  @override
  String get appId => '4944d39727984768a9771377c42104ee';
}

@sandbox
@Injectable(as: AgoraSettings)
class SandboxAgoraSettings implements AgoraSettings {
  @override
  String get appId => '4944d39727984768a9771377c42104ee';
}

@prod
@Injectable(as: AgoraSettings)
class ProdAgoraSettings implements AgoraSettings {
  @override
  String get appId => '4944d39727984768a9771377c42104ee';
}
