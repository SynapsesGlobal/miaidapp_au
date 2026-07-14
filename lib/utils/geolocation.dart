import 'package:flutter/material.dart';
import 'package:flutter/src/material/scaffold.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:geolocator/geolocator.dart';

class MyGeoLocation {
  // 首页初始化（急救号码/剩余问诊次数/国家信息）等场景会并发请求定位权限，
  // 而 geolocator 不允许并发的 requestPermission（会抛 PermissionRequestInProgress），
  // 共享进行中的请求，让并发调用方等待同一次系统弹窗的结果，避免相互冲突随机失败。
  static Future<LocationPermission>? _pendingPermissionRequest;

  static Future<LocationPermission> requestPermission() {
    final pending = _pendingPermissionRequest ??= Geolocator.requestPermission()
        .whenComplete(() => _pendingPermissionRequest = null);
    return pending;
  }

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  Future<Position> determinePosition(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('First turn your location services on')));
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await MyGeoLocation.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.

    final lastPosition = await Geolocator.getLastKnownPosition();
    if (lastPosition != null) {
      return lastPosition;
    }

    return await Geolocator.getCurrentPosition();
  }
}
