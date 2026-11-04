import 'package:geolocator/geolocator.dart';
import 'package:miaid/utils/geolocation.dart';

/// 取一次设备位置的结果状态，界面按状态给出不同提示
enum DeviceLocationStatus {
  ok,

  /// 系统定位服务整体关闭
  serviceDisabled,

  /// 本次拒绝了定位权限，可再次请求
  permissionDenied,

  /// 永久拒绝，只能引导去系统设置
  permissionDeniedForever,

  /// 已授权但取不到位置（超时、无定位源等）
  failed,
}

class DeviceLocationResult {
  const DeviceLocationResult(this.status, [this.position]);

  final DeviceLocationStatus status;
  final Position? position;

  bool get isOk => status == DeviceLocationStatus.ok && position != null;
}

/// 购物车"使用当前位置"和地图选点页"回到我的位置"共用的一次性定位。
///
/// 与首页定位不同，这里要的是收货地址，所以先要一次新鲜的高精度定位，
/// 超时才退回最近一次已知位置；权限请求走 [MyGeoLocation.requestPermission]
/// 以免和首页并发的权限请求冲突。
class DeviceLocationService {
  static const _timeout = Duration(seconds: 12);

  static Future<DeviceLocationResult> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationResult(DeviceLocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await MyGeoLocation.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult(DeviceLocationStatus.permissionDeniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const DeviceLocationResult(DeviceLocationStatus.permissionDenied);
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        );
        return DeviceLocationResult(DeviceLocationStatus.ok, position);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return DeviceLocationResult(DeviceLocationStatus.ok, last);
        }
        return const DeviceLocationResult(DeviceLocationStatus.failed);
      }
    } catch (_) {
      return const DeviceLocationResult(DeviceLocationStatus.failed);
    }
  }
}
