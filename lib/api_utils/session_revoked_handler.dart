import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/main.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/home/home_screen.dart';

/// 账号在其他设备登录时，后端（AuthController::login）会硬删同账号
/// 其它设备的 device 记录，被顶掉的旧设备之后所有请求都是 401。
/// 这里统一识别并处理"被踢下线"：明确提示 + 本地登出 + 回到未登录首页，
/// 替代之前零散调用链里的 Something went wrong。
class SessionRevokedHandler {
  SessionRevokedHandler._();

  /// 新版后端中间件对"被其他设备登录顶掉"的 token 返回的专属错误码
  static const String _kickedErrorCode = 'LOGGED_IN_ELSEWHERE';

  /// 旧版后端对失效 token 的通用文案（被踢与自然过期同文案，无法区分）
  static const String _invalidTokenMessage = 'Invalid device access token';

  /// 后端 access_token 固定 90 天有效期（Device::$defaultTokenExpiryDays）。
  /// 距登录远不足该期限就失效，基本只可能是账号在别处登录被顶掉；
  /// 留 5 天余量避免边界误判。仅用于旧后端没有 error_code 时的降级判断。
  static const Duration _tokenLifetime = Duration(days: 85);

  static bool _handling = false;

  /// 由 Chopper 响应拦截器对 401 响应调用；[error] 为响应体（Map 或 JSON 字符串）
  static void handle401(dynamic error) {
    final body = _asMap(error);
    if (body == null) return;
    final message = body['message']?.toString() ?? '';
    final errorCode = body['error_code']?.toString();

    if (errorCode == _kickedErrorCode) {
      _run(kicked: true);
    } else if (message.contains(_invalidTokenMessage)) {
      _run(kicked: _isWithinTokenLifetime());
    }
    // 其余 401（密码错误、账号被禁用等）不在这里处理，保持原有行为
  }

  /// FCM 收到 logged-in-elsewhere 事件时调用（登录踢出的实时通知）
  static void handleKickedPush() {
    _run(kicked: true);
  }

  static bool _isWithinTokenLifetime() {
    final lastLoginAt = getIt<UserProvider>().lastLoginAt;
    // 没有登录时间记录（老版本升级上来）时按被踢处理，提示对用户更可执行
    if (lastLoginAt == null) return true;
    return DateTime.now().difference(lastLoginAt) < _tokenLifetime;
  }

  static Map<String, dynamic>? _asMap(dynamic error) {
    if (error is Map<String, dynamic>) return error;
    if (error is String) {
      try {
        final decoded = jsonDecode(error);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> _run({required bool kicked}) async {
    if (_handling) return;
    final userProvider = getIt<UserProvider>();
    // 冷启动恢复会话失败等未登录场景：不弹框，让未登录首页自然接管
    if (!userProvider.isLoggedIn) return;
    _handling = true;

    try {
      // token 已在服务端失效，只做本地清理；不能调 logout 接口，
      // 那会再产生一次 401
      await userProvider.onSessionRevoked();

      final context = navigatorKey.currentContext;
      if (context == null) return;

      final message =
          kicked ? S.current.accountLoggedInElsewhere : S.current.relogin;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          title: Text(
            S.of(dialogContext).alert,
            textAlign: TextAlign.center,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.rubik(fontSize: 13),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  S.of(dialogContext).confirm,
                  style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      // 与抽屉登出保持一致：清栈回到未登录首页
      final homeScreen = getIt<HomeScreen>();
      await navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (context) => homeScreen,
        ),
        (route) => false,
      );
    } finally {
      _handling = false;
    }
  }
}
