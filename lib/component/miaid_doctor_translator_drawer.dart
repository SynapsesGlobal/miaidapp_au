import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/doctor_interpreter/user_doctor_translator_profile_screen.dart';
import 'package:miaid/view/drawer/about.dart';
import 'package:miaid/view/drawer/privacy_and_policy.dart';
import 'package:miaid/view/drawer/terms_and_cond.dart';
import 'package:miaid/view/user/calling/call_history/call_history.dart';
import 'package:miaid/view/user/notification/notification_screen.dart';

import 'miaid_drawer.dart';

class MiAidDoctorTranslatorDrawerParams {
  const MiAidDoctorTranslatorDrawerParams(this.key);

  final Key key;
}

@injectable
class MiAidDoctorTranslatorDrawerServices {
  MiAidDoctorTranslatorDrawerServices(this.user);

  final UserProvider user;
}

/// 医生 / 翻译端侧边抽屉。条目样式和间距与客户端抽屉 [MiAidDrawer] 保持一致。
@injectable
class MiAidDoctorTranslatorDrawer extends StatelessWidget {
  MiAidDoctorTranslatorDrawer({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final MiAidDoctorTranslatorDrawerParams? params;
  final MiAidDoctorTranslatorDrawerServices services;

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
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/'),
                    builder: (context) => getIt<CallHistory>(),
                  ),
                  (route) => false,
                );
              },
            ),
            _drawerItem(
              context,
              'assets/images/ic_sidebar_profile.png',
              S.of(context).myProfile,
              () => _openProfile(context),
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
              'assets/images/ic_sidebar_about.png',
              S.of(context).about,
              () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => getIt<AboutMiAid>(),
              )),
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
              'assets/images/ic_sidebar_logout.png',
              S.of(context).logout,
              () => confirmLogout(context, services.user),
              labelColor: AppColors.kfa0020,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => getIt<UserDoctorTranslatorProfileScreen>(),
    ));
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 52, 0, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _openProfile(context),
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
            onTap: () => _openProfile(context),
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
    VoidCallback onTap, {
    Color? labelColor,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      minVerticalPadding: 0,
      leading: Image.asset(iconPath, width: 24, height: 24),
      title: Text(
        label,
        style: GoogleFonts.rubik(
          color: labelColor ?? AppColors.k010101,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }
}
