import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
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
