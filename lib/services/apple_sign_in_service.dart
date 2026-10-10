import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/config/apple_sign_in_config.dart';
import 'package:miaid/services/social_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Sign in with Apple（仅客户角色）。
///
/// 两步：[requestCredential] 调起 Apple 授权拿到 identity token；
/// [login] 把令牌交给后端 `/login/social` 验签并换取与密码登录相同的响应。
/// 分成两步是为了让页面只在请求后端时显示 loading，而不盖住系统授权弹层。
///
/// nonce 由 App 生成：交给 Apple 的是其 SHA-256，原值交给后端核对，防止令牌被重放。
class AppleSignInService {
  AppleSignInService(this.api);

  final ApiProvider api;

  static const int _nonceLength = 32;
  static const String _nonceCharset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';

  /// Android 没有原生 Apple 登录，由插件打开网页授权完成
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// 调起 Apple 授权。取消抛 [SocialSignInCancelled]，失败抛 [SocialSignInException]。
  Future<AppleCredential> requestCredential() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
        state: Platform.isAndroid ? await _androidState() : null,
        webAuthenticationOptions:
            Platform.isAndroid ? _webAuthenticationOptions() : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      debugPrint('Apple 授权失败: ${e.code} ${e.message}');
      throw const SocialSignInException('');
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const SocialSignInException('');
    }

    return AppleCredential._(
      identityToken: identityToken,
      authorizationCode: credential.authorizationCode,
      rawNonce: rawNonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  /// 把 Apple 令牌交给后端换取登录态。
  /// 姓名只在用户首次授权时返回，后端仅在新建账号时作为默认值。
  Future<SocialSignInResult> login(
    AppleCredential credential, {
    required String devicePushToken,
  }) {
    return SocialSignInClient(api).login(
      SocialSignInRequest(
        provider: SocialSignInRequest.providerApple,
        identityToken: credential.identityToken,
        rawNonce: credential.rawNonce,
        authorizationCode: credential.authorizationCode,
        givenName: credential.givenName,
        familyName: credential.familyName,
      ),
      devicePushToken: devicePushToken,
    );
  }

  WebAuthenticationOptions _webAuthenticationOptions() {
    return WebAuthenticationOptions(
      clientId: AppleSignInConfig.servicesId,
      redirectUri: Uri.parse(
        '${api.apiSettings.endpointSub}${AppleSignInConfig.callbackPath}',
      ),
    );
  }

  /// Android 回跳要拉起哪个包由后端根据 state 决定：正式包与测试包包名不同。
  /// 格式 `<包名>:<随机串>`，与后端 AppleSignInCallbackController 约定一致。
  Future<String> _androidState() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.packageName}:${_generateNonce()}';
  }

  static String _generateNonce() {
    final random = Random.secure();
    return List.generate(
      _nonceLength,
      (_) => _nonceCharset[random.nextInt(_nonceCharset.length)],
    ).join();
  }
}

/// Apple 授权成功后拿到的凭据，连同本次使用的原始 nonce 一起交给后端。
class AppleCredential {
  const AppleCredential._({
    required this.identityToken,
    required this.authorizationCode,
    required this.rawNonce,
    this.givenName,
    this.familyName,
  });

  final String identityToken;
  final String authorizationCode;
  final String rawNonce;
  final String? givenName;
  final String? familyName;
}
