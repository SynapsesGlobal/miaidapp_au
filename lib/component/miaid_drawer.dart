import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/utils/auth_gate.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/drawer/about.dart';
import 'package:miaid/view/drawer/privacy_and_policy.dart';
import 'package:miaid/view/drawer/terms_and_cond.dart';
import 'package:miaid/view/main_tabs/main_tabs.dart';
import 'package:miaid/view/user/calling/call_history/call_history.dart';
import 'package:miaid/view/user/notification/notification_screen.dart';
import 'package:miaid/view/user/user_profile_screen/user_profile_screen.dart';

import '../view/tracking/location_tracking.dart';
import 'miaid_doctor_translator_drawer.dart';

class MiAidDrawerParams {
  const MiAidDrawerParams(this.key);

  final Key key;
}

@injectable
class MiAidDrawerServices {
  MiAidDrawerServices(this.user);

  final UserProvider user;
}

/// 客户端侧边抽屉。个人资料、Travel/Corporate Care、邀请好友、登出已移到底部导航的
/// 「我的」tab，MiSpace 已是独立 tab，这里只保留其余入口。
@injectable
class MiAidDrawer extends StatelessWidget {
  MiAidDrawer({@factoryParam this.params,
      required this.services,
      required this.activeSubscriptionStore
  }) : super(key: params?.key);

  final MiAidDrawerParams? params;
  final MiAidDrawerServices services;
  // 构造参数由生成的 DI 配置传入，去掉要重跑 build_runner，先保留
  final ActiveSubscriptionStore activeSubscriptionStore;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_home.png',
              S.of(context).home,
              () {
                Navigator.pop(context);
                MainTabs.pushAsRoot(context);
              },
            ),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_callhistory.png',
              S.of(context).callHistory,
              () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => getIt<CallHistory>(),
                ));
              },
            ),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_notifications.png',
              S.of(context).notificationList,
              () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/'),
                  builder: (context) => getIt<NotificationScreen>(),
                ));
              },
            ),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_terms.png',
              S.of(context).positionTracking,
              () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => LocationTracking(),
                ));
              },
            ),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_terms.png',
              S.of(context).tandc,
              () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => getIt<TermsConditions>(),
              )),
            ),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_privacy.png',
              S.of(context).privacy,
              () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => getIt<PrivacyPolicy>(),
              )),
            ),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_about.png',
              S.of(context).about,
              () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => getIt<AboutMiAid>(),
              )),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    void openProfile() {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute<void>(
        builder: (context) => getIt<UserProfileScreen>(),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 52, 0, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: openProfile,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.k0cbcc5, width: 2),
                image: profileDecorationImage(context, services.user.user!, getIt<ApiSettings>()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: openProfile,
            child: Text(
              services.user.user?.fullName ?? '',
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    String iconPath,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      minVerticalPadding: 0,
      leading: Image.asset(iconPath, width: 24, height: 24),
      title: Text(
        label,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}

DecorationImage profileDecorationImage(BuildContext context, User user, ApiSettings apiSettings) {
  ImageProvider image = AssetImage('assets/images/logo_auth.png');
  if (user.avatarUrl != null) {
    image = CachedNetworkImageProvider(apiSettings.rewriteHost(user.avatarUrl!));
  }

  return DecorationImage(
    image: image,
    fit: BoxFit.cover,
  );
}

/// 登出二次确认弹窗，确认后执行 [logout]。「我的」页的登出入口走这里。
Future<void> confirmLogout(BuildContext context, UserProvider user) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).logout,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(color: AppColors.k010101, fontWeight: FontWeight.w700),
      ),
      content: Text(
        S.of(context).logoutAlertMessage,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(fontSize: 13),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
          child: Column(
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k0cbcc5.withOpacity(0.2),
                      blurRadius: 10.0,
                      offset: const Offset(0.0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(S.of(context).no, style: GoogleFonts.rubik(
                    color: AppColors.kffffff,
                    fontSize: 14,
                  ),),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(S.of(context).yes, style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                ),),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await logout(context, user);
  }
}

Future<void> logout(BuildContext context, UserProvider user) async {
  // logOut() 内部（_resetUserRelatedData）会统一停止定位上传服务并清缓存。
  await user.logOut();

  // 未登录只能停留在登录页：清空路由栈回登录页
  await AuthGate.toSignIn(context);
}

Future<void> deleteUser(BuildContext context, UserProvider user) async {
  final deleted = await user.deleteAccount();
  if (!deleted) {
    // 服务端未删除成功：提示用户，保持登录，不跳转
    await HttpExceptionNotifyUser.showError(S.of(context).deleteAccountFailed);
    return;
  }
  await AuthGate.toSignIn(context);
}

Widget getDrawer(UserProvider user) {
  if (!user.isLoggedIn || user.isCustomer) {
    return getIt<MiAidDrawer>();
  }
  // TODO
  return getIt<MiAidDoctorTranslatorDrawer>();
}
