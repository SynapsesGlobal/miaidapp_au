import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/config/apple_sign_in_config.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 用户在 Apple 授权页取消了登录，调用方静默处理即可。
class AppleSignInCancelled implements Exception {
  const AppleSignInCancelled();
}

/// Apple 授权或后端校验失败，[message] 可直接展示给用户（可能为空，调用方给默认文案）。
class AppleSignInException implements Exception {
  const AppleSignInException(this.message);

  final String message;

  @override
  String toString() => 'AppleSignInException: $message';
}

/// 后端 /login/social 返回的登录结果，与密码登录的 payload 结构一致。
class AppleSignInResult {
  const AppleSignInResult({required this.user, required this.rawPayload});

  /// 生成的 User 模型，供 onLogIn / getHomeFromUser 使用
  final User user;

  /// 原始 payload，用于读取生成模型里没有的字段（如 open_position_tracking）
  final Map<String, dynamic> rawPayload;
}

/// Sign in with Apple（仅客户角色）。
///
/// 两步：[requestCredential] 调起 Apple 授权拿到 identity token；
/// [login] 把令牌交给后端 `/login/social` 验签并换取与密码登录相同的响应。
/// 分成两步是为了让页面只在请求后端时显示 loading，而不盖住系统授权弹层。
///
/// nonce 由 App 生成：交给 Apple 的是其 SHA-256，原值交给后端核对，防止令牌被重放。
/// 这里不走生成的 swagger 客户端（手工补丁会被 build_runner 覆盖），直接用 http 发表单。
class AppleSignInService {
  AppleSignInService(this.api);

  final ApiProvider api;

  static const int _nonceLength = 32;
  static const String _nonceCharset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';

  /// Android 没有原生 Apple 登录，由插件打开网页授权完成
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// 调起 Apple 授权。取消抛 [AppleSignInCancelled]，失败抛 [AppleSignInException]。
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
        throw const AppleSignInCancelled();
      }
      debugPrint('Apple 授权失败: ${e.code} ${e.message}');
      throw const AppleSignInException('');
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const AppleSignInException('');
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
  Future<AppleSignInResult> login(
    AppleCredential credential, {
    required String devicePushToken,
  }) async {
    final body = <String, String>{
      'provider': 'apple',
      'identity_token': credential.identityToken,
      'authorization_code': credential.authorizationCode,
      'nonce': credential.rawNonce,
      'device_id': api.userProvider.deviceId.deviceId,
      'device_type': api.userProvider.deviceId.deviceType,
      'device_push_token': devicePushToken,
      'timezone': await _localTimezone(),
    };
    // 姓名只在用户首次授权时返回，后端仅在新建账号时作为默认值
    if (credential.givenName?.isNotEmpty ?? false) {
      body['first_name'] = credential.givenName!;
    }
    if (credential.familyName?.isNotEmpty ?? false) {
      body['last_name'] = credential.familyName!;
    }

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('${api.apiSettings.endpointSub}/login/social'),
        headers: {
          'x-api-key': api.apiSettings.apiKeySub,
          'Accept': 'application/json',
        },
        body: body,
      );
    } catch (e) {
      debugPrint('Apple 登录请求失败: $e');
      throw const AppleSignInException('');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      json = <String, dynamic>{};
    }

    final payload = json['payload'];
    if (response.statusCode == 200 && payload is Map<String, dynamic>) {
      return AppleSignInResult(
          user: User.fromJson(payload), rawPayload: payload);
    }

    // 401：令牌无效 / 账号被禁用等；422：参数校验失败。后端 message 可直接展示
    throw AppleSignInException(json['message'] as String? ?? '');
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

  Future<String> _localTimezone() async {
    try {
      return await FlutterNativeTimezone.getLocalTimezone();
    } catch (_) {
      return '';
    }
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
