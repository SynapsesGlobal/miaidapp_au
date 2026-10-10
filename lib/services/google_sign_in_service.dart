import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/services/social_sign_in.dart';

/// Google 登录（仅客户角色，仅英文版 App）。
///
/// 两步：[requestCredential] 调起 Google 账号选择拿到 ID token；
/// [login] 把令牌交给后端 `/login/social` 验签并换取与密码登录相同的响应。
///
/// iOS 客户端 ID 和 Web 客户端 ID（Android 拿 ID token 必须）都按环境配在 ApiSettings 里。
class GoogleSignInService {
  GoogleSignInService(this.api);

  final ApiProvider api;

  /// Google Play 服务在中国大陆不可用，本服务只在英文版 App 里使用
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    // iOS 客户端 ID 按环境传入；Android 由 google-services.json 决定，不能传
    clientId:
        Platform.isIOS ? _nullIfEmpty(api.apiSettings.googleIosClientId) : null,
    serverClientId: _nullIfEmpty(api.apiSettings.googleServerClientId),
  );

  static String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

  /// 调起 Google 授权。取消抛 [SocialSignInCancelled]，失败抛 [SocialSignInException]。
  Future<GoogleCredential> requestCredential() async {
    final GoogleSignInAccount? account;
    try {
      // 先登出，保证每次都弹账号选择，而不是沿用上次缓存的账号
      await _googleSignIn.signOut();
      account = await _googleSignIn.signIn();
    } catch (e) {
      // 常见原因：Android 上 SHA-1 未登记（错误码 10）、Google Play 服务不可用
      debugPrint('Google 授权失败: $e');
      throw const SocialSignInException('');
    }

    if (account == null) {
      throw const SocialSignInCancelled();
    }

    final idToken = (await account.authentication).idToken;
    if (idToken == null || idToken.isEmpty) {
      // Android 上没配 serverClientId 时拿不到 ID token
      debugPrint('Google 授权成功但没有返回 ID token，检查 serverClientId 配置');
      throw const SocialSignInException('');
    }

    return GoogleCredential._(idToken: idToken);
  }

  /// 把 Google 令牌交给后端换取登录态。姓名、邮箱后端直接从令牌里取。
  Future<SocialSignInResult> login(
    GoogleCredential credential, {
    required String devicePushToken,
  }) {
    return SocialSignInClient(api).login(
      SocialSignInRequest(
        provider: SocialSignInRequest.providerGoogle,
        identityToken: credential.idToken,
      ),
      devicePushToken: devicePushToken,
    );
  }
}

/// Google 授权成功后拿到的凭据。
class GoogleCredential {
  const GoogleCredential._({required this.idToken});

  final String idToken;
}
