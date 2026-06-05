
import 'package:injectable/injectable.dart';
import 'package:miaid/notifications/notifications_token_provider.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceId {
  DeviceId(this.deviceId);

  final String deviceId;

  String get deviceType {
    return getIt<NotificationsTokenProvider>().deviceType;
  }
}

@singleton
class DeviceIdProvider {
  final _DEVICE_ID_KEY = 'FLUTTER_DEVICE_ID_KEY';

  DeviceIdProvider(this.sharedPreferences);

  final SharedPreferences sharedPreferences;

  DeviceId get deviceId {
    var deviceId = sharedPreferences.getString(_DEVICE_ID_KEY);
    if (deviceId == null) {
      deviceId = Uuid().v4().toString();
      sharedPreferences.setString(_DEVICE_ID_KEY, deviceId);
    }
    return DeviceId(deviceId);
  }
}
