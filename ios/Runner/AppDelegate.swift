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
import BackgroundTasks

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {

    var locationManager: CLLocationManager?
    var flutterChannel: FlutterMethodChannel?
    var timer: Timer?

    // ---- 智能戒指：iOS 后台刷新（BGAppRefreshTask）----
    // 戒指已绑定时按 15 分钟间隔申请后台刷新，触发后让 Dart 侧补一次同步上传（见 RingBackgroundSync）
    static let ringTaskId = "com.em.bright.miaid.ring-sync"
    private let ringEnabledKey = "ring_background_sync_enabled"
    var ringChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            flutterChannel = FlutterMethodChannel(name: "com.miaid.location", binaryMessenger: controller.binaryMessenger)
            flutterChannel?.setMethodCallHandler(handleMethodCall)
        }

        if let controller = window?.rootViewController as? FlutterViewController {
            ringChannel = FlutterMethodChannel(name: "miaid/ring_background", binaryMessenger: controller.binaryMessenger)
            ringChannel?.setMethodCallHandler { [weak self] call, result in
                guard let self = self else { return }
                switch call.method {
                case "setEnabled":
                    let enabled = (call.arguments as? Bool) ?? false
                    UserDefaults.standard.set(enabled, forKey: self.ringEnabledKey)
                    if enabled { self.scheduleRingSync() } else { self.cancelRingSync() }
                    result(nil)
                case "scheduleNow":
                    self.scheduleRingSync()
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.ringTaskId, using: nil) { [weak self] task in
                guard let self = self, let task = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
                self.handleRingSync(task: task)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ---- 智能戒指后台刷新 ----

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        if UserDefaults.standard.bool(forKey: ringEnabledKey) { scheduleRingSync() }
    }

    func scheduleRingSync() {
        guard #available(iOS 13.0, *) else { return }
        let request = BGAppRefreshTaskRequest(identifier: AppDelegate.ringTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("RingSync: schedule failed: \(error)")
        }
    }

    func cancelRingSync() {
        guard #available(iOS 13.0, *) else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: AppDelegate.ringTaskId)
    }

    @available(iOS 13.0, *)
    func handleRingSync(task: BGAppRefreshTask) {
        // 先排下一次，保证链不断
        scheduleRingSync()
        var finished = false
        let finish: (Bool) -> Void = { ok in
            if finished { return }
            finished = true
            task.setTaskCompleted(success: ok)
        }
        task.expirationHandler = { [weak self] in
            self?.ringChannel?.invokeMethod("cancel", arguments: nil)
            finish(false)
        }
        // 后台冷启动时 Dart 侧可能还没注册 handler，最多重试 10 次（约 10 秒）
        invokeRingSync(attempt: 0, completion: finish)
    }

    private func invokeRingSync(attempt: Int, completion: @escaping (Bool) -> Void) {
        guard let channel = ringChannel else { completion(false); return }
        channel.invokeMethod("sync", arguments: nil) { [weak self] reply in
            if reply is FlutterError || (reply as AnyObject) === FlutterMethodNotImplemented {
                if attempt < 10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.invokeRingSync(attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
                return
            }
            completion((reply as? Bool) ?? false)
        }
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
