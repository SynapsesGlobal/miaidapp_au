import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';

/// 用户在平台授权页取消了登录，调用方静默处理即可。
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

/// 平台授权或后端校验失败，[message] 可直接展示给用户（可能为空，调用方给默认文案）。
class SocialSignInException implements Exception {
  const SocialSignInException(this.message);

  final String message;

  @override
  String toString() => 'SocialSignInException: $message';
}

/// 后端 /login/social 返回的登录结果，与密码登录的 payload 结构一致。
class SocialSignInResult {
  const SocialSignInResult({required this.user, required this.rawPayload});

  /// 生成的 User 模型，供 onLogIn / getHomeFromUser 使用
  final User user;

  /// 原始 payload，用于读取生成模型里没有的字段（如 open_position_tracking）
  final Map<String, dynamic> rawPayload;
}

/// 平台授权成功后交给后端的凭据。各平台只填自己有的字段。
class SocialSignInRequest {
  const SocialSignInRequest({
    required this.provider,
    required this.identityToken,
    this.rawNonce,
    this.authorizationCode,
    this.givenName,
    this.familyName,
  });

  static const String providerApple = 'apple';
  static const String providerGoogle = 'google';

  final String provider;

  /// 平台签发的 JWT，后端验签
  final String identityToken;

  /// App 生成的原始 nonce（Apple 需要，交给 Apple 的是其 SHA-256）
  final String? rawNonce;

  /// Apple 授权码，后端用来换 refresh token
  final String? authorizationCode;

  /// 平台返回的姓名，后端仅在新建账号时作为默认值
  final String? givenName;
  final String? familyName;
}

/// 把第三方平台的凭据交给后端 `/login/social`，换取与密码登录相同的响应。
///
/// Apple 与 Google 共用。不走生成的 swagger 客户端（手工补丁会被 build_runner 覆盖），直接用 http 发表单。
class SocialSignInClient {
  SocialSignInClient(this.api);

  final ApiProvider api;

  Future<SocialSignInResult> login(
    SocialSignInRequest request, {
    required String devicePushToken,
  }) async {
    final body = <String, String>{
      'provider': request.provider,
      'identity_token': request.identityToken,
      'device_id': api.userProvider.deviceId.deviceId,
      'device_type': api.userProvider.deviceId.deviceType,
      'device_push_token': devicePushToken,
      'timezone': await _localTimezone(),
    };
    _putIfNotEmpty(body, 'nonce', request.rawNonce);
    _putIfNotEmpty(body, 'authorization_code', request.authorizationCode);
    _putIfNotEmpty(body, 'first_name', request.givenName);
    _putIfNotEmpty(body, 'last_name', request.familyName);

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
      debugPrint('${request.provider} 登录请求失败: $e');
      throw const SocialSignInException('');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      json = <String, dynamic>{};
    }

    final payload = json['payload'];
    if (response.statusCode == 200 && payload is Map<String, dynamic>) {
      return SocialSignInResult(
          user: User.fromJson(payload), rawPayload: payload);
    }

    // 401：令牌无效 / 账号被禁用等；422：参数校验失败。后端 message 可直接展示
    throw SocialSignInException(json['message'] as String? ?? '');
  }

  static void _putIfNotEmpty(
      Map<String, String> body, String key, String? value) {
    if (value != null && value.isNotEmpty) body[key] = value;
  }

  Future<String> _localTimezone() async {
    try {
      return await FlutterNativeTimezone.getLocalTimezone();
    } catch (_) {
      return '';
    }
  }
}
