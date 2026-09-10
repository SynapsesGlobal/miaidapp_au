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

  // 点"取消"后 24 小时内不再弹升级框；后台若换了新的最低版本号则立即恢复提醒
  static const _updateDismissedAtKey = 'update_dialog_dismissed_at';
  static const _updateDismissedVersionKey = 'update_dialog_dismissed_version';
  static const _updateRemindInterval = Duration(hours: 24);

  Future ongoingCallStore(BuildContext context, AppVersionResponse appVersionResponse) async {
    final newVersion = appVersionResponse.minimumAppVersion;

    final prefs = await SharedPreferences.getInstance();
    final dismissedAt = prefs.getInt(_updateDismissedAtKey);
    final dismissedVersion = prefs.getString(_updateDismissedVersionKey);
    if (dismissedAt != null &&
        dismissedVersion == (newVersion ?? '') &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(dismissedAt),
            ) <
            _updateRemindInterval) {
      return;
    }

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 渐变头图 + 装饰圆环 + 图标徽章
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.k0cbcc5,
                      Color(0xFF089AA6),
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: -30,
                      right: -20,
                      child: _decorCircle(90),
                    ),
                    Positioned(
                      bottom: -36,
                      left: -14,
                      child: _decorCircle(110),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        // logo 图片自带深色圆角底，这里只负责投影
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Image(
                        image: AssetImage('assets/images/logo_splash.png'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.of(context).updateModuleTitle,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (newVersion != null && newVersion.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // 新版本号徽章
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.k0cbcc5.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'V $newVersion',
                          style: GoogleFonts.rubik(
                            color: AppColors.k0cbcc5,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      S.of(context).updateModuleMessage,
                      style: GoogleFonts.rubik(
                        color: AppColors.k8f8f8f,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.k0cbcc5,
                              Color(0xFF089AA6),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.k0cbcc5.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _openStorePage(
                            context,
                            appVersionResponse,
                          ),
                          child: Text(
                            S.of(context).updateModuleButton,
                            style: GoogleFonts.rubik(
                              color: AppColors.kffffff,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        await prefs.setInt(
                          _updateDismissedAtKey,
                          DateTime.now().millisecondsSinceEpoch,
                        );
                        await prefs.setString(
                          _updateDismissedVersionKey,
                          newVersion ?? '',
                        );
                        Navigator.pop(context);
                      },
                      child: Text(
                        S.of(context).updateModuleCancel,
                        style: GoogleFonts.rubik(
                          color: AppColors.k8f8f8f,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 14,
        ),
      ),
    );
  }

  Future<void> _openStorePage(
    BuildContext context,
    AppVersionResponse appVersionResponse,
  ) async {
    final packageInfo = await PackageInfo.fromPlatform();

    // iOS 用后端下发的 App Store 链接（可能缺失，不能强解包）；
    // Android 优先应用市场协议，测试包等无市场入口时回退网页版商店
    final candidates = Platform.isAndroid
        ? [
            'market://details?id=${packageInfo.packageName}',
            'https://play.google.com/store/apps/details?id=${packageInfo.packageName}',
          ]
        : [
            if (appVersionResponse.iosAppLink?.isNotEmpty ?? false)
              appVersionResponse.iosAppLink!,
          ];

    for (final link in candidates) {
      final url = Uri.parse(link);
      if (await canLaunchUrl(url)) {
        Navigator.pop(context);
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }
    developer.log('Could not open store page, candidates: $candidates');
  }
}
