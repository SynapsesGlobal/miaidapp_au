import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/utils/language_native_name.dart';
import 'package:miaid/payment/additional_services.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/store/user/calling/call_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/calling/call_screen.dart';
import 'package:miaid/view/user/travel_care_packages/travel_care_packages.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'dart:developer' as developer;

Future<void> navigateToCallScreen(
  BuildContext context,
  ActiveSubscriptionStore store,
  VIDEO_CALL_TYPE video_call_type,
) async {
  if (store.remainingConsultations == null) {
    // TODO show an error to the user
    // debugPrint('There are no remaining consultations');
    await HttpExceptionNotifyUser.showInfo(
      S.of(context).noAvailableConsultation,
    );
    return;
  }

  /// 给客服打电话不受限制
  /*if (video_call_type == VIDEO_CALL_TYPE.ASSISTANCE) {
    if (!store.hasActiveSubscription && store.remainingConsultations!.remainingConsultations <= 0) {
      individualUserSubscriptionAlert(context);
      return;
    }
  }*/

  if (video_call_type == VIDEO_CALL_TYPE.CONSULT_A_DOCTOR) {
    if (!store.hasActiveSubscription && store.remainingConsultations!.remainingConsultations <= 0) {
      individualUserSubscriptionAlert(context);
      return;
    }

    if (store.remainingConsultations!.remainingConsultations <= 0) {
      videoConsultationsAlert(context);
      return;
    }

    // 发起医生面诊前，确认本次希望医生使用的语言（写回账号后用于后端医生匹配）。
    final languageConfirmed = await _confirmConsultationLanguage(context);
    if (!languageConfirmed) return;
  }

  // if (Platform.isAndroid) {
  //   // TODO check if permission was granted
  //   await [
  //     Permission.microphone,
  //     Permission.camera,
  //     Permission.bluetooth,
  //     Permission.accessMediaLocation,
  //     Permission.bluetoothConnect,
  //     Permission.bluetoothScan
  //   ].request();
  // }

  final cameraPermission = Permission.camera;
  final microphonePermission = Permission.microphone;
  // if one of the permissions is denied, show an alert dialog and request the permission again
  if (await cameraPermission.isDenied || await microphonePermission.isDenied) {
    await [
      cameraPermission,
      microphonePermission,
    ].request();
  }

  var callScreen = getIt<CallScreen>();

  callScreen.services.store.video_call_type = video_call_type;

  await Navigator.push(context, MaterialPageRoute<void>(
    builder: (context) => callScreen,
  ),);
}

/// 发起医生面诊前，让当前用户选择/确认本次希望医生使用的语言。
///
/// 选择后写回当前账号的偏好语言（后端据此匹配对应语言的医生）。
/// 返回 true 表示已确认并写回，可继续发起通话；返回 false（取消或失败）则中止。
///
/// 注意：这与右上角"界面显示语言"是两个不同概念，文案/标题已明确区分。
Future<bool> _confirmConsultationLanguage(BuildContext context) async {
  final store = getIt<CallScreenStore>();

  // 先读取 profile 的 need_select_language：仅当后端要求时才弹框，否则直接拨打。
  var languages = <Language>[];
  try {
    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.black,
    );
    final needSelect = await store.needSelectConsultationLanguage();

    if (!needSelect) {
      // 后端不要求选择语言，直接继续发起通话。
      await EasyLoading.dismiss();
      return true;
    }
    languages = await store.fetchConsultationLanguages();
  } catch (e) {
    await EasyLoading.dismiss();
    return false;
  }
  await EasyLoading.dismiss();
  if (languages.isEmpty) return false;

  final current = store.currentConsultationLanguage;

  final selected = await showCupertinoModalPopup<Language>(
    context: context,
    builder: (popupContext) => CupertinoActionSheet(
      title: Text(
        S.of(context).consultationLanguageTitle,
        style: GoogleFonts.rubik(fontSize: 15, color: AppColors.k8f8e94),
      ),
      message: Text(
        S.of(context).consultationLanguageMessage,
        style: GoogleFonts.rubik(fontSize: 13, color: AppColors.k8f8e94),
      ),
      actions: languages.map((lang) => CupertinoActionSheetAction(
        isDefaultAction: current?.id != null && current?.id == lang.id,
        onPressed: () => Navigator.pop(popupContext, lang),
        child: Text(
          nativeLanguageName(lang.language),
          style: GoogleFonts.rubik(fontSize: 20, color: AppColors.k0cbcc5),
        ),
      )).toList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(popupContext),
        child: Text(
          S.of(context).cancel,
          style: GoogleFonts.rubik(fontSize: 20, color: AppColors.k0cbcc5),
        ),
      ),
    ),
  );

  if (selected == null) return false;

  try {
    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.black,
    );
    await store.updateConsultationLanguage(selected);
  } catch (e) {
    await EasyLoading.dismiss();
    return false;
  }
  await EasyLoading.dismiss();
  return true;
}

void videoConsultationsAlert(BuildContext context) {
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
                offset: Offset(0.0, 4),
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
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => getIt<AdditionalServices>(),
              ),);
            },
            child: Text(S.of(context).yes, style: GoogleFonts.rubik(
              color: AppColors.kffffff,
              fontSize: 14,
            ),),
          ),
        ),
        SizedBox(height: 20,),
        Center(
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: Text(S.of(context).cancel, style: GoogleFonts.rubik(
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
      S.of(context).alert,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(color: AppColors.k010101, fontWeight: FontWeight.w700),
    ),
    content: Text(
      S.of(context).consultAlertMessage,
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
    },
  );
}

void individualUserSubscriptionAlert(BuildContext context) {
  Widget okButton = Padding(
    padding: EdgeInsets.only(left: 20, right: 20, bottom: 24.5),
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
                spreadRadius: 0.0,
                offset: Offset(0.0,  4,),
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
              Navigator.pushReplacement(context, MaterialPageRoute<void>(
                builder: (context) => getIt<TravelCarePackages>(),
              ),);
            },
            child: Text(S.of(context).subscribe, style: GoogleFonts.rubik(
              color: AppColors.kffffff,
              fontSize: 14,
            ),),
          ),
        ),
        SizedBox(height: 20,),
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
              Navigator.pushReplacement(context, MaterialPageRoute<void>(
                builder: (context) => getIt<AdditionalServices>(),
              ),);
            },
            child: Text(S.of(context).purchase, style: GoogleFonts.rubik(
              color: AppColors.kffffff,
              fontSize: 14,
            ),),
          ),
        ),
        SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: Text(S.of(context).cancel, style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: 16,
            ),),
          ),
          SizedBox(width: 20,),
          InkWell(
            onTap: () async {
              Navigator.pop(context);
              final cameraPermission = Permission.camera;
              final microphonePermission = Permission.microphone;
              if (await cameraPermission.isDenied || await microphonePermission.isDenied) {
                await [
                  cameraPermission,
                  microphonePermission,
                ].request();
              }

              var callScreen = getIt<CallScreen>();
              callScreen.services.store.video_call_type = VIDEO_CALL_TYPE.CONSULT_A_DOCTOR;
              await Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => callScreen,
              ),);
            },
            child: Text(S.of(context).continues, style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: 16,
            ),),
          )
        ],)
      ],
    ),
  );

  var alert = AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    title: Text(
      S.of(context).alert,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(color: AppColors.k010101, fontWeight: FontWeight.w700),
    ),
    content: Text(
      S.of(context).travelAlertMessage,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(
        fontSize: 13,
      ),
    ),
    actions: [okButton],
  );


  showDialog(
    barrierColor: Colors.black38,
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
