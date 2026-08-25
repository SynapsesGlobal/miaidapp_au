import 'dart:async';

import 'package:chopper/chopper.dart';

import 'session_revoked_handler.dart';

/// 全局识别"token 已失效/账号在其他设备登录"的 401 响应。
/// login/logout/deleteUser 自身的 401（密码错误、登出时 token 恰好已失效）
/// 排除在外，避免干扰这些流程原有的提示与导航。
class SessionRevokedInterceptor implements ResponseInterceptor {
  static const List<String> _excludedPathSuffixes = [
    '/login',
    '/logout',
    '/deleteUser',
  ];

  @override
  FutureOr<Response<dynamic>> onResponse(Response<dynamic> response) {
    if (response.statusCode == 401) {
      final path = response.base.request?.url.path ?? '';
      final excluded = _excludedPathSuffixes.any(path.endsWith);
      if (!excluded) {
        SessionRevokedHandler.handle401(response.error);
      }
    }
    return response;
  }
}
