import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMTokenService {
  // 单例
  FCMTokenService._();
  static final FCMTokenService instance = FCMTokenService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _currentToken;
  StreamSubscription<String>? _refreshSub;

  // 提供 token 变化的 Stream，业务层可以订阅
  final _tokenController = StreamController<String>.broadcast();
  Stream<String> get tokenStream => _tokenController.stream;

  /// 获取当前 FCM Token
  /// [forceRefresh] 为 true 时强制重新获取，否则返回缓存值
  Future<String?> getToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _currentToken != null) {
      return _currentToken;
    }

    try {
      // 1. 请求权限
      final hasPermission = await _requestPermission();
      if (!hasPermission) return null;

      // 2. iOS 需要先等 APNs Token
      if (Platform.isIOS) {
        final apnsReady = await _waitForAPNSToken();
        if (!apnsReady) {
          print('[FCM] APNs Token 未就绪');
          return null;
        }
      }

      // 3. 获取 FCM Token（带超时）
      final token = await _messaging
          .getToken()
          .timeout(const Duration(seconds: 15), onTimeout: () => null);

      if (token == null) {
        print('[FCM] Token 获取超时或返回 null');
        return null;
      }

      _currentToken = token;
      _setupRefreshListener();
      return token;
    } catch (e, stack) {
      print('[FCM] 获取 Token 异常: $e\n$stack');
      return null;
    }
  }

  /// 请求通知权限
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final status = settings.authorizationStatus;
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// 等待 iOS APNs Token 就绪（最多重试 5 次，间隔 2 秒）
  Future<bool> _waitForAPNSToken({int maxRetry = 5}) async {
    for (int i = 0; i < maxRetry; i++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) return true;
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  /// 监听 Token 刷新（重要！Token 会过期）
  void _setupRefreshListener() {
    _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen((newToken) {
      print('[FCM] Token 已刷新');
      _currentToken = newToken;
      _tokenController.add(newToken);
    });
  }

  /// 释放资源（一般在 App 退出时调用，单例模式可不调）
  void dispose() {
    _refreshSub?.cancel();
    _tokenController.close();
  }

  /// 删除当前 Token（用户登出时可调用）
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _currentToken = null;
    } catch (e) {
      print('[FCM] 删除 Token 失败: $e');
    }
  }
}