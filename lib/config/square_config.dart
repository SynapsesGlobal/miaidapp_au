/// square payment

class SquareConfig {
  // 从 Square Developer Dashboard → Credentials 拿
  static const String applicationId = 'sq0idp-PgTVhGxMj-YzDRdv5svSCw';

  // 与 Info.plist 里 CFBundleURLSchemes 一致
  static const String callbackScheme = 'miaidsquare';
  static const String callbackHost = 'payment-result';

  static String get callbackUrl => '$callbackScheme://$callbackHost';

  // 货币（按客户地区改）
  static const String currencyCode = 'AUD';
}