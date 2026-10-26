import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/utils/configure_dependencies.dart';

/// 邀请码接口不在 swagger 里，按仓库惯例用 http 直接调，不改生成的客户端。
class InvitationService {
  /// 取当前登录用户的邀请码；未登录、接口非 200 或网络异常都返回 null，由调用方提示。
  static Future<String?> fetchInvitationCode() async {
    final api = getIt<ApiProvider>();
    final user = api.userProvider.user;
    if (user == null) return null;

    final url = Uri.parse('${api.baseUrl}/api/v1/invitation_code')
        .replace(queryParameters: {'userId': user.id.toString()});
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-api-key': api.apiKey,
        'x-access-token': user.accessToken.toString(),
      });
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body)['invitation_code']?.toString();
    } catch (e) {
      debugPrint('fetch invitation code failed: $e');
      return null;
    }
  }
}
