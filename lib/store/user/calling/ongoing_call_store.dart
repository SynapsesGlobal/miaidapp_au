import 'dart:core';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/doctor_interpreter/incoming_call_screen.dart';
import 'package:miaid/view/user/calling/call_screen.dart';
import 'package:miaid/view/user/calling/scheduled_call_screen.dart';
import 'package:mobx/mobx.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';
import '../../../main.dart';
import 'dart:developer' as developer;
part 'ongoing_call_store.g.dart';

class IncomingCallData {
  IncomingCallData({
    required this.callId,
    required this.operatorFullName,
    required this.doctorFullName,
    required this.customerFullName,
    required this.customerUserId,
  });

  final int callId;

  // Can be null
  final String? operatorFullName;

  // Can be null
  final String? doctorFullName;

  // Can be null
  final String? customerFullName;

  // Can be null
  final int? customerUserId;
}

@singleton
class OngoingCallStore = _OngoingCallStore with _$OngoingCallStore;

abstract class _OngoingCallStore with Store {
  _OngoingCallStore(this.api, this.user);

  final ApiProvider api;
  final UserProvider user;

  /// 当前通话的 RtcEngine 实例，由 CallScreenStore 创建/销毁，
  /// 供 ChatScreen 等共享 OngoingCallStore 的页面渲染远端视频。
  RtcEngine? rtcEngine;

  @observable
  int? incomingCallId;
  BuildContext? incomingCallContext;

  @observable
  Call? ongoingCall;

  @observable
  ObservableList<ScheduledOption> shceduledOptions = <ScheduledOption>[].asObservable();

  bool get hasIncomingCall => incomingCallId != null;

  bool get hasOngoingCall => ongoingCall != null;

  bool hasAnsweredACall = false;

  @observable
  bool hasPendingCall = false;

  @action
  void setHasPendingCall(bool hasPendingCall) {
    this.hasPendingCall = hasPendingCall;
  }

  @action
  void setOngoingCall({
    Call? ongoingCall,
  }) {
    this.ongoingCall = ongoingCall;

    incomingCallId = null;
  }

  @action
  void closeIncomingCallScreen(int incomingCallId) {
    if ((incomingCallId == this.incomingCallId || this.incomingCallId == null || this.incomingCallId == false) && incomingCallContext != null) {
      if (Navigator.canPop(incomingCallContext!)) {
        Navigator.pop(incomingCallContext!);
      } else {
        // Navigator.pushReplacement(
        //   incomingCallContext!,
        //   MaterialPageRoute<void>(
        //     settings: RouteSettings(name: "/"),
        //     builder: (context) => getHomeFromUser(
        //         widget.services.store.user.user),
        //   ),
        // );
      }
    } else {
      //developer.log('Could not close incoming call screen');
    }
    this.incomingCallId = null;
    //incomingCallContext = null;
  }

  @action
  void setIncomingCall({
    int? incomingCallId,
    BuildContext? incomingCallContext,
  }) {
    this.incomingCallId = incomingCallId;
    this.incomingCallContext = incomingCallContext;
  }

  @action
  Future<void> rejectCall(
    int callId,
  ) async {
    final response = await api.apiClientMain.callsPostCallReject(call_id: callId);
    ApiSuccessParser.isSuccessfulOrThrowWithMessage(response);
  }

  @action
  Future<void> acceptCall(
    int callId,
  ) async {
    Position? position;
    String? countryCode;
    if (user.user?.customer != null) {
      position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
      countryCode = await getCountryCodeFromLocation(position);
    }

    final response = await api.apiClientMain.callsPostCallAccept(
      call_id: callId,
      latitude: position?.latitude,
      longitude: position?.longitude,
      country_code: countryCode,
    );
    ApiSuccessParser.isSuccessfulOrThrowWithMessage(response);
  }

  @action
  Future<void> rescheduleCall(
    int callId,
    int call_reschedule_seconds,
  ) async {
    final response = await api.apiClientMain.callsPostCallReschedule(
      call_id: callId,
      call_reschedule_seconds: call_reschedule_seconds,
    );
    ApiSuccessParser.isSuccessfulOrThrowWithMessage(response);
  }

  Future<void> fetchScheduleOptions() async {
    shceduledOptions.clear();
    final response = await api.apiClientMain.callsGetCallsScheduleOptions();
    final reponseOptions = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    shceduledOptions.addAll(reponseOptions);
  }

  Future<void> showIncomingCallDialogOrGoToCallScreen(BuildContext context, Call call) async {
    //developer.log('showIncomingCallDialogOrGoToCallScreen');

    var hasAcceptedCall = false;
    if (call.customer?.user?.id == user.user?.id) {
      hasAcceptedCall = call.customerJoinedAt != null;
    } else if (call.doctor?.user?.id == user.user?.id) {
      hasAcceptedCall = call.doctorJoinedAt != null;
    } else if (call.translator?.user?.id == user.user?.id) {
      hasAcceptedCall = call.translatorJoinedAt != null;
    } else {
      //developer.log('Received unexpected call $call');
      return;
    }

    var sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString('doctor-or-translator-state', 'busy');

    if (hasAcceptedCall && !hasAnsweredACall) {
      setOngoingCall(ongoingCall: call);
      hasAnsweredACall = true;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => getIt<CallScreen>(),
        ),
      );
      hasAnsweredACall = false;
    } else if (incomingCallId == null) {
      showIncomingCallDialog(context, call);
    }
  }

  void showIncomingCallDialog(BuildContext context, Call call) {
    incomingCallContext = context;

    var params = IncomingCallScreenParams(
      incomingCallData: IncomingCallData(
        callId: call.id!,
        operatorFullName: call.$Operator?.user?.fullName,
        customerFullName: call.customer?.user?.fullName,
        doctorFullName: call.doctor?.user?.fullName,
        customerUserId: call.customer?.user?.id,
      ),
    );

    Widget incomingCall = getIt<ScheduledCallScreen>(param1: params);
    if (call.customer?.user?.id != user.user?.id) {
      incomingCall = getIt<IncomingCallScreen>(param1: params);
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => incomingCall,
    );
    incomingCallId = call.id;
  }

  Future ongoingCallStore(BuildContext context, AppVersionResponse appVersionResponse) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
            child: Text(
              S.of(context).updateModuleTitle,
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).updateModuleMessage,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 13,
                  letterSpacing: -0.08,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                height: 30,
              ),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k0cbcc5.withOpacity(0.2),
                      offset: Offset(
                        0,
                        0.4,
                      ),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColors.k0cbcc5),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  onPressed: () async {
                    PackageInfo packageInfo =
                        await PackageInfo.fromPlatform();

                    final url = Uri.parse(Platform.isAndroid
                        ? "market://details?id=${packageInfo.packageName}"
                        : appVersionResponse.iosAppLink!);
                    if (await canLaunch(url.toString())) {
                      Navigator.pop(context);
                      await launchUrl(url);
                    } else {
                      throw 'Could not launch $url';
                      Navigator.pop(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 44,
                      right: 44,
                      top: 10,
                      bottom: 8,
                    ),
                    child: Text(
                      S.of(context).updateModuleButton,
                      style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                style: ButtonStyle(
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
                  S.of(context).updateModuleCancel,
                  style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }
    );
  }
}
