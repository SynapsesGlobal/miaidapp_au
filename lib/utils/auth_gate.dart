import 'package:flutter/material.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/main.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';

/// 登录门禁：App 的所有页面都要求先登录，未登录状态只能停留在登录页
/// （注册、找回密码从登录页进入）。
///
/// 进入登录页的入口统一收口在这里：启动时未登录（见 main.dart 的
/// getHomeFromUser）、抽屉登出、注销账号、令牌失效（401）。
class AuthGate {
  AuthGate._();

  static bool _handlingUnauthorized = false;

  /// 清空路由栈并进入登录页。[context] 为空时用全局 navigatorKey；
  /// 两者都拿不到（App 还没 runApp）则什么都不做，由启动流程自己选首页。
  static Future<void> toSignIn([BuildContext? context]) async {
    final navigator = context != null && context.mounted
        ? Navigator.of(context)
        : navigatorKey.currentState;
    if (navigator == null) return;

    // 在 builder 外创建，避免 MaterialApp 重建时路由 builder 重新执行生成新实例
    final signIn = getIt<SignIn>();
    await navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => signIn,
      ),
      (route) => false,
    );
  }

  /// 接口返回 401：已登录用户的令牌已失效，清掉本地登录态并回到登录页。
  /// 未登录时（例如登录页本身密码错误返回 401）不做任何事。
  /// 多个请求同时 401 只处理一次。
  static Future<void> onUnauthorized() async {
    final userProvider = getIt<UserProvider>();
    if (!userProvider.isLoggedIn || _handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      // 令牌已经无效，不再调服务端登出接口，只清本地
      await userProvider.onSessionExpired();
      await toSignIn();
    } finally {
      _handlingUnauthorized = false;
    }
  }
}
