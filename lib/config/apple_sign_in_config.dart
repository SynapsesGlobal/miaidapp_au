/// Sign in with Apple
class AppleSignInConfig {
  AppleSignInConfig._();

  /// Apple Developer 后台登记的 Services ID。
  /// 只有 Android 用到（网页授权的 client_id）；iOS 走原生授权，用的是 Bundle ID。
  /// 正式包和测试包共用同一个 Services ID，后端据此校验令牌的 aud。
  static const String servicesId = 'com.em.bright.miaid.signin';

  /// 后端回调路径（相对客户端 API 根路径），Apple 后台 Services ID 的 Return URL 必须与之一致。
  /// Android 网页授权结束后 Apple 把结果 POST 到这里，后端再重定向回 App。
  static const String callbackPath = '/auth/apple/callback';
}
