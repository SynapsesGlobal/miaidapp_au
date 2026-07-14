import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/affiliate/affiliate.dart';
import 'package:miaid/view/drawer/about.dart';
import 'package:miaid/view/drawer/privacy_and_policy.dart';
import 'package:miaid/view/drawer/terms_and_cond.dart';
import 'package:miaid/view/user/calling/call_history/call_history.dart';
import 'package:miaid/view/user/corporate_care_packages/corporate_care_packages.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:miaid/view/user/notification/notification_screen.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/view/user/travel_care_packages/travel_care_packages.dart';
import 'package:miaid/view/user/user_profile_screen/user_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_utils/api_provider.dart';
import '../services/location_upload_service.dart';
import '../view/marketing/category.dart';
import '../view/tracking/location_tracking.dart';
import 'miaid_doctor_translator_drawer.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:http/http.dart' as http;

class MiAidDrawerParams {
  const MiAidDrawerParams(this.key);

  final Key key;
}

@injectable
class MiAidDrawerServices {
  MiAidDrawerServices(this.user);

  final UserProvider user;
}

@injectable
class MiAidDrawer extends StatelessWidget {
  final link = 'https://www.mi-aid.com.au/';
  MiAidDrawer({@factoryParam this.params,
      required this.services,
      required this.activeSubscriptionStore
  }) : super(key: params?.key);

  final MiAidDrawerParams? params;
  final MiAidDrawerServices services;
  final ActiveSubscriptionStore activeSubscriptionStore;

  Widget getCorporateWidgets(BuildContext context) {
    if (!services.user.isLoggedIn ||
        activeSubscriptionStore.activeCompanySubscriptionDetails == null ||
        activeSubscriptionStore.activeCompanySubscriptionDetails!.isEmpty) {
      return const SizedBox.shrink();
    }
    return _drawerItem(
      context,
      'assets/images/ic_sidebar_corporatecare2.png',
      S.of(context).corporateCare,
      () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute<void>(
          builder: (context) => getIt<CorporateCarePackages>(),
        ));
      },
    );
  }

  /*Future<String> _getCreditPoints() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(Consts.marketingApiHost+'/credits/total').replace(queryParameters: {
        'userId': api.userProvider.user!.id.toString(),
      });
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        final sharedPreferences = getIt<SharedPreferences>();
        await sharedPreferences.setString('remaining_credits', responseData['credit'].toString());
        return responseData['credit'].toString();
      }
      return '0';
    } catch (e) {
      return '0';
    }
  }*/

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            _buildHeader(context),
            const Divider(height: 1),

            // ── Main ────────────────────────────────────────────
            _drawerItem(
              context,
              'assets/images/ic_sidebar_home.png',
              S.of(context).home,
              () {
                Navigator.pop(context);
                // 必须在 builder 外创建：MaterialApp 重建（如切换语言）会重新执行路由 builder，
                // 在 builder 内 getIt 会每次生成新实例，导致 store 状态（如国家信息）被清空
                final homeScreen = getIt<HomeScreen>();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/'),
                    builder: (context) => homeScreen,
                  ),
                  (route) => false,
                );
              },
            ),

            // ── Account ─────────────────────────────────────────
            if (services.user.isLoggedIn) ...[
              //_sectionDivider(),
              _drawerItem(
                context,
                'assets/images/ic_sidebar_profile.png',
                S.of(context).myProfile,
                () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute<void>(
                    builder: (context) => getIt<UserProfileScreen>(),
                  ));
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
            ],

            // ── Services ─────────────────────────────────────────
            if (services.user.isLoggedIn) ...[
              //_sectionDivider(),
              _drawerItem(
                context,
                'assets/images/ic_sidebar_travelcare.png',
                S.of(context).travelCare,
                () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute<void>(
                    builder: (context) => getIt<TravelCarePackages>(),
                  ));
                },
              ),
              getCorporateWidgets(context),
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
                'assets/images/ic_sidebar_corporatecare2.png',
                S.of(context).marketing,
                () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute<void>(
                    builder: (context) => MarketingCategory(),
                  ));
                },
              ),
              /*_drawerItem(
                context,
                'assets/images/ic_sidebar_travelcare.png',
                S.of(context).affiliate_title,
                () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute<void>(
                    builder: (context) => AffiliatePage(),
                  ));
                },
              ),*/
            ],

            // ── Info ─────────────────────────────────────────────
            //_sectionDivider(),
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

            // ── Social & logout ───────────────────────────────────
            if (services.user.isLoggedIn) ...[
              //_sectionDivider(),
              _drawerItem(
                context,
                'assets/images/invite.png',
                S.of(context).inviteFriends,
                () => _showInviteSheet(context),
              ),
              _drawerItem(
                context,
                'assets/images/ic_sidebar_logout.png',
                S.of(context).logout,
                () => showAlertDialog(context),
                labelColor: AppColors.kfa0020,
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 52, 0, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (services.user.isLoggedIn) {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => getIt<UserProfileScreen>(),
                ));
              }
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.k0cbcc5, width: 2),
                image: services.user.isLoggedIn
                    ? profileDecorationImage(context, services.user.user!, getIt<ApiSettings>())
                    : const DecorationImage(
                        image: AssetImage('assets/images/logo_auth.png'),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              if (services.user.isLoggedIn) {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => getIt<UserProfileScreen>(),
                ));
              } else {
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => getIt<SignIn>(),
                ));
              }
            },
            child: Text(
              services.user.isLoggedIn
                  ? services.user.user?.fullName ?? ''
                  : S.of(context).signIn,
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

  Widget _sectionDivider() => Divider(
    color: Colors.grey.withOpacity(0.2),
    height: 8,
    indent: 16,
    endIndent: 16,
  );

  void _showInviteSheet(BuildContext context) {
    final action = CupertinoActionSheet(
      message: Text(
        S.of(context).inviteFriends,
        style: TextStyle(fontSize: 13.0, color: AppColors.k8f8e94),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
            final api = getIt<ApiProvider>();
            final headers = <String, String>{
              'Content-Type': 'application/json',
              'x-api-key': api.apiKey,
              'x-access-token': api.userProvider.user!.accessToken.toString(),
            };
            try {
              await EasyLoading.show(status: 'Loading...', maskType: EasyLoadingMaskType.black);
              final url = Uri.parse('${api.baseUrl}/api/v1/invitation_code')
                  .replace(queryParameters: {'userId': api.userProvider.user!.id.toString()});
              final response = await http.get(url, headers: headers);
              await EasyLoading.dismiss();
              if (response.statusCode == 200) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                final responseData = jsonDecode(response.body);
                if (Platform.isIOS) {
                  final message = S.of(context).messageInvitationContent(responseData['invitation_code'], link);
                  await sendSMS(message: message, recipients: [], sendDirect: false)
                      .catchError((dynamic e) { debugPrint('sms error: $e'); return ''; });
                } else {
                  final smsUri = Uri(scheme: 'sms', queryParameters: {
                    'body': S.of(context).messageInvitationContent(responseData['invitation_code'], link),
                  });
                  await launchUrl(smsUri);
                }
              }
            } catch (e) {
              debugPrint('invite error: $e');
            }
          },
          child: Text(S.of(context).viaMessage, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 24)),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () async {
            final api = getIt<ApiProvider>();
            final headers = <String, String>{
              'Content-Type': 'application/json',
              'x-api-key': api.apiKey,
              'x-access-token': api.userProvider.user!.accessToken.toString(),
            };
            try {
              await EasyLoading.show(status: 'Loading...', maskType: EasyLoadingMaskType.black);
              final url = Uri.parse('${api.baseUrl}/api/v1/invitation_code')
                  .replace(queryParameters: {'userId': api.userProvider.user!.id.toString()});
              final response = await http.get(url, headers: headers);
              await EasyLoading.dismiss();
              if (response.statusCode == 200) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                final responseData = jsonDecode(response.body);
                String encodeParams(Map<String, String> p) =>
                    p.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
                final emailUri = Uri(
                  scheme: 'mailto',
                  path: '',
                  query: encodeParams({
                    'subject': S.of(context).emailInvitationTitle,
                    'body': S.of(context).emailInvitationContent(responseData['invitation_code'], link),
                  }),
                );
                await launchUrl(emailUri);
              }
            } catch (e) {
              debugPrint('invite error: $e');
            }
          },
          child: Text(S.of(context).viaEmail, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 24)),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text(S.of(context).cancel, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 20)),
      ),
    );
    showCupertinoModalPopup<void>(context: context, builder: (context) => action);
  }

  void showAlertDialog(BuildContext context) {
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset(0.0, 4,),
                ),
              ],
            ),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(S.of(context).no, style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 14,
              ),),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context, true);
              },
              child: Text(S.of(context).yes, style: GoogleFonts.rubik(
                color: AppColors.k0cbcc5,
                fontSize: 14,
              ),),
            ),
          ),
        ],
      ),
    );
    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
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
        style: GoogleFonts.rubik(
          fontSize: 13,
        ),
      ),
      actions: [okButton],
    );

    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
      return alert;
    }).then((value) async {
      if (value ?? false) {
        await logout(context, services.user);
      }
    });
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

Future<void> logout(BuildContext context, UserProvider user) async {
  await user.logOut();

  var _isRunning = await LocationUploadService.isRunning;
  if (_isRunning) {
    await LocationUploadService.stop();
  }

  while (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
  // 在 builder 外创建，避免 MaterialApp 重建时路由 builder 重新执行生成新实例
  final homeScreen = getIt<HomeScreen>();
  await Navigator.pushAndRemoveUntil(
    context,
    // ignore: inference_failure_on_instance_creation
    MaterialPageRoute(
      // builder: (context) => getIt<SignIn>(),
      builder: (context) => homeScreen,
    ),
    (route) => false,
  );
}

Future<void> deleteUser(BuildContext context, UserProvider user) async {
  await user.deleteAccount();
  while (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
  // 在 builder 外创建，避免 MaterialApp 重建时路由 builder 重新执行生成新实例
  final homeScreen = getIt<HomeScreen>();
  await Navigator.pushAndRemoveUntil(
    context,
    // ignore: inference_failure_on_instance_creation
    MaterialPageRoute(
      // builder: (context) => getIt<SignIn>(),
      builder: (context) => homeScreen,
    ),
    (route) => false,
  );
}

Widget getDrawer(UserProvider user) {
  if (!user.isLoggedIn || user.isCustomer) {
    return getIt<MiAidDrawer>();
  }
  // TODO
  return getIt<MiAidDoctorTranslatorDrawer>();
}
