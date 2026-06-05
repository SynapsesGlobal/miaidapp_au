import 'package:flutter/cupertino.dart';
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
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Container(
                height: 70,
                width: 70,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            getIt<UserDoctorTranslatorProfileScreen>(),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.k0cbcc5),
                      shape: BoxShape.circle,
                      image: profileDecorationImage(
                          context, services.user.user!, getIt<ApiSettings>()),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 15,
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        getIt<UserDoctorTranslatorProfileScreen>(),
                  ),
                );
              },
              child: Text(
                services.user.user?.fullName ?? '',
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              height: 15,
            ),
            Divider(
              color: Colors.grey,
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute<void>(
                      settings: RouteSettings(name: "/"),
                      builder: (context) => getIt<CallHistory>(),
                    ),
                    (route) => false);
              },
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 23),
                  child: Text(
                    S.of(context).home,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 14,
                    ),
                  ),
                ),
                leading: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 9, right: 20),
                  child: Image(
                    image: AssetImage('assets/images/ic_sidebar_home.png'),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        getIt<UserDoctorTranslatorProfileScreen>(),
                  ),
                );
              },
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 23),
                  child: Text(
                    S.of(context).myProfile,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 14,
                    ),
                  ),
                ),
                leading: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 9, right: 20),
                  child: Image(
                    image: AssetImage('assets/images/ic_sidebar_profile.png'),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    settings: RouteSettings(name: "/"),
                    builder: (context) => getIt<NotificationScreen>(),
                  ),
                );
              },
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 23),
                  child: Text(
                    'Notification',
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 14,
                    ),
                  ),
                ),
                leading: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 9, right: 20),
                  child: Image(
                    width: 36,
                    height: 36,
                    image: AssetImage(
                        'assets/images/ic_sidebar_notifications.png'),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => getIt<TermsConditions>(),
                  ),
                );
              },
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 23),
                  child: Text(
                    S.of(context).tandc,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 14,
                    ),
                  ),
                ),
                leading: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 9, right: 20),
                  child: Image(
                    image: AssetImage('assets/images/ic_sidebar_terms.png'),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => getIt<PrivacyPolicy>(),
                  ),
                );
              },
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 23),
                  child: Text(
                    S.of(context).privacy,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 14,
                    ),
                  ),
                ),
                leading: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 9, right: 20),
                  child: Image(
                    image: AssetImage('assets/images/ic_sidebar_privacy.png'),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => getIt<AboutMiAid>(),
                  ),
                );
              },
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 23),
                  child: Text(
                    S.of(context).about,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 14,
                    ),
                  ),
                ),
                leading: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 9, right: 20),
                  child: Image(
                    image: AssetImage('assets/images/ic_sidebar_about.png'),
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                showAlertDialog(context);
              },
              child: ListTile(
                title: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 23),
                  child: Text(
                    S.of(context).logout,
                    style: GoogleFonts.rubik(
                      color: AppColors.kfa0020,
                      fontSize: 14,
                    ),
                  ),
                ),
                leading: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, bottom: 9, right: 20),
                  child: Image(
                    image: AssetImage('assets/images/ic_sidebar_logout.png'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  offset: Offset(
                    0.0, // Move to right 10  horizontally
                    4, // Move to bottom 10 Vertically
                  ),
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
              child: Text(
                S.of(context).no,
                style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context, true);
              },
              child: Text(
                S.of(context).yes,
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
    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).logout,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
            color: AppColors.k010101, fontWeight: FontWeight.w700),
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

    showDialog(
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
