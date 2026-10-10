import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';

/// 个人页"登录方式"相关接口失败，[message] 来自后端（可能为空，调用方给默认文案）。
class SocialAccountException implements Exception {
  const SocialAccountException(this.message);

  final String message;

  @override
  String toString() => 'SocialAccountException: $message';
}

/// 已绑定的第三方账号。
class LinkedSocialAccount {
  const LinkedSocialAccount({
    required this.provider,
    this.email,
    this.isPrivateEmail = false,
    this.linkedAt,
  });

  factory LinkedSocialAccount.fromJson(Map<String, dynamic> json) {
    return LinkedSocialAccount(
      provider: json['provider'] as String? ?? '',
      email: json['email'] as String?,
      isPrivateEmail: json['is_private_email'] == true,
      linkedAt: DateTime.tryParse(json['linked_at'] as String? ?? ''),
    );
  }

  static const String providerApple = 'apple';
  static const String providerGoogle = 'google';

  final String provider;
  final String? email;

  /// Apple「隐藏邮箱」转发地址
  final bool isPrivateEmail;
  final DateTime? linkedAt;

  /// 平台显示名（Apple / Google）
  String get label {
    switch (provider) {
      case providerApple:
        return 'Apple';
      case providerGoogle:
        return 'Google';
      default:
        return provider;
    }
  }
}

/// 当前用户的登录方式概览：是否已设置密码、绑定了哪些第三方账号。
class SocialAccountSummary {
  const SocialAccountSummary(
      {required this.hasPassword, required this.accounts});

  factory SocialAccountSummary.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    return SocialAccountSummary(
      hasPassword: json['has_password'] == true,
      accounts: rawAccounts is List
          ? rawAccounts
              .whereType<Map<String, dynamic>>()
              .map(LinkedSocialAccount.fromJson)
              .toList()
          : const [],
    );
  }

  final bool hasPassword;
  final List<LinkedSocialAccount> accounts;

}

/// 登录方式管理：查询绑定、解绑、为无密码用户设置密码。
///
/// 这几个接口是本次新增的，生成的 swagger 客户端里没有，直接用 http 调客户端 API。
class SocialAccountService {
  SocialAccountService(this.api);

  final ApiProvider api;

  Future<SocialAccountSummary> fetch() async {
    final json = await _request('GET', '/profile/social-accounts');
    return SocialAccountSummary.fromJson(
        json['payload'] as Map<String, dynamic>);
  }

  /// 解绑后返回最新概览。没有密码的用户后端会拒绝并说明原因。
  Future<SocialAccountSummary> unlink(String provider) async {
    final json = await _request(
      'POST',
      '/profile/social-accounts/unlink',
      body: {'provider': provider},
    );
    return SocialAccountSummary.fromJson(
        json['payload'] as Map<String, dynamic>);
  }

  /// 仅对尚未设置密码的用户有效；已有密码走原来的修改密码接口。
  Future<void> setPassword(String password, String confirmation) async {
    await _request(
      'POST',
      '/password/set',
      body: {'password': password, 'password_confirmation': confirmation},
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? body,
  }) async {
    final uri = Uri.parse('${api.apiSettings.endpointSub}$path');
    final headers = {
      'x-api-key': api.apiSettings.apiKeySub,
      'x-access-token': api.userProvider.user?.accessToken ?? '',
      'Accept': 'application/json',
    };

    final http.Response response;
    try {
      response = method == 'GET'
          ? await http.get(uri, headers: headers)
          : await http.post(uri, headers: headers, body: body);
    } catch (e) {
      debugPrint('登录方式接口请求失败 $path: $e');
      throw const SocialAccountException('');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      json = <String, dynamic>{};
    }

    if (response.statusCode == 200 && json['result'] == true) {
      return json;
    }

    // 422 的 message 是后端给用户看的原因（如"请先设置密码"）
    throw SocialAccountException(json['message'] as String? ?? '');
  }
}
