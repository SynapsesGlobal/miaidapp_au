/* import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
} */

import UIKit
import Flutter
import CoreLocation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {

    var locationManager: CLLocationManager?
    var flutterChannel: FlutterMethodChannel?
    var timer: Timer?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            flutterChannel = FlutterMethodChannel(name: "com.miaid.location", binaryMessenger: controller.binaryMessenger)
            flutterChannel?.setMethodCallHandler(handleMethodCall)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startLocationService":
            startLocationService()
            result(nil)
        case "stopLocationService":
            stopLocationService()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func startLocationService() {
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.pausesLocationUpdatesAutomatically = false
        }

        if #available(iOS 14.0, *) {
            let status = locationManager?.authorizationStatus ?? .notDetermined
            print("当前定位权限状态(iOS14+): \(status.rawValue)")
            handleAuthorizationStatus(status)
        } else {
            let status = CLLocationManager.authorizationStatus()
            print("当前定位权限状态(iOS<14): \(status.rawValue)")
            handleAuthorizationStatus(status)
        }
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            DispatchQueue.main.async {
                self.locationManager?.requestAlwaysAuthorization()
            }
        case .authorizedAlways:
            locationManager?.startUpdatingLocation()
            startTimer()
        case .authorizedWhenInUse:
            locationManager?.startUpdatingLocation()
            startTimer()
            print("仅获得使用期间定位权限，建议引导用户开启“始终允许”")
        case .denied, .restricted:
            print("定位权限被拒绝或受限制，请用户开启权限")
        @unknown default:
            break
        }
    }

    func stopLocationService() {
        timer?.invalidate()
        timer = nil
        locationManager?.stopUpdatingLocation()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.sendCurrentLocation()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func sendCurrentLocation() {
        guard let loc = locationManager?.location else { return }
        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude
        let ts = Int(loc.timestamp.timeIntervalSince1970)

        flutterChannel?.invokeMethod("uploadLocation", arguments: ["lat": lat, "lng": lng, "ts": ts])
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            let status = manager.authorizationStatus
            print("权限变化回调(iOS14+): \(status.rawValue)")
            handleAuthorizationStatus(status)
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("权限变化回调(iOS<14): \(status.rawValue)")
        handleAuthorizationStatus(status)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error.localizedDescription)")
    }
}
