import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/invite_friends_sheet.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/tracking/location_tracking.dart';
import 'package:miaid/view/user/corporate_care_packages/corporate_care_packages.dart';
import 'package:miaid/view/user/travel_care_packages/travel_care_packages.dart';
import 'package:miaid/view/user/user_profile_screen/user_profile_screen.dart';

/// 底部导航「我的」tab：个人资料、Travel Care、Corporate Care、定位追踪、邀请好友、登出的快捷入口。
/// 原来这些入口都在抽屉里，抽屉里已去掉。
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final _userProvider = getIt<UserProvider>();
  final _subscriptions = getIt<ActiveSubscriptionStore>();

  /// 和抽屉原来的规则一致：有企业订阅才显示 Corporate Care
  bool get _hasCorporateCare =>
      _subscriptions.activeCompanySubscriptionDetails?.isNotEmpty ?? false;

  Future<void> _push(Widget page) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    // 从资料页回来头像、姓名可能已改，tab 页常驻不会自动重建
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(l10n.me, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(context),
          const SizedBox(height: 16),
          miAidCard(Observer(builder: (_) => Column(
            children: [
              _MeItem(
                icon: 'assets/images/ic_sidebar_profile.png',
                label: l10n.myProfile,
                onTap: () => _push(getIt<UserProfileScreen>()),
              ),
              const _ItemDivider(),
              _MeItem(
                icon: 'assets/images/ic_sidebar_travelcare.png',
                label: l10n.travelCare,
                onTap: () => _push(getIt<TravelCarePackages>()),
              ),
              if (_hasCorporateCare) ...[
                const _ItemDivider(),
                _MeItem(
                  icon: 'assets/images/ic_sidebar_corporatecare2.png',
                  label: l10n.corporateCare,
                  onTap: () => _push(getIt<CorporateCarePackages>()),
                ),
              ],
              const _ItemDivider(),
              _MeItem(
                icon: 'assets/images/ic_sidebar_terms.png',
                label: l10n.positionTracking,
                onTap: () => _push(LocationTracking()),
              ),
              const _ItemDivider(),
              _MeItem(
                icon: 'assets/images/invite.png',
                label: l10n.inviteFriends,
                onTap: () => showInviteFriendsSheet(context),
              ),
            ],
          ))),
          const SizedBox(height: 16),
          miAidCard(_MeItem(
            icon: 'assets/images/ic_sidebar_logout.png',
            label: l10n.logout,
            labelColor: AppColors.kfa0020,
            showChevron: false,
            onTap: () => confirmLogout(context, _userProvider),
          )),
        ],
      ),
    );
  }

  /// 头像 + 姓名 + 邮箱，点击进个人资料
  Widget _header(BuildContext context) {
    final user = _userProvider.user;
    if (user == null) return const SizedBox.shrink();

    return miAidCard(InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => _push(getIt<UserProfileScreen>()),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.k0cbcc5, width: 2),
                image: profileDecorationImage(context, user, getIt<ApiSettings>()),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName ?? '',
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.email?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.email!,
                      style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.k8f8e94),
          ],
        ),
      ),
    ));
  }
}

class _MeItem extends StatelessWidget {
  const _MeItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.showChevron = true,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? labelColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Image.asset(icon, width: 24, height: 24),
      title: Text(
        label,
        style: GoogleFonts.rubik(color: labelColor ?? AppColors.k010101, fontSize: 14),
      ),
      trailing: showChevron ? Icon(Icons.chevron_right, color: AppColors.k8f8e94) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onTap: onTap,
    );
  }
}

class _ItemDivider extends StatelessWidget {
  const _ItemDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, indent: 56, endIndent: 16, color: Color(0xFFF0F0F0));
}
