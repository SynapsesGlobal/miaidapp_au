import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:miaid/main.dart';
import 'package:miaid/services/ring_alert_center.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/view/user/smart_ring/family/ring_alerts_screen.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/dialogs/arrival_hospital.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/doctor_interpreter/incoming_call_screen.dart';
import 'package:miaid/view/user/calling/scheduled_call_screen.dart';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import 'notifications_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}, ${message.data}');
}

class FirebaseNotificationHandler extends NotificationHandler {
  @override
  Future<void> setup(BuildContext contextParam) async {
    context = contextParam;
    if (isSetup) {
      return;
    }
    isSetup = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print(message.data);
      String? eventName;
      if (message.data.containsKey('event_name')) {
        eventName = message.data['event_name'];
      }
      if (eventName == 'ring_alert') {
        if ('${message.data['self'] ?? ''}' == '1') {
          // 自己的戒指读数超阈值：前台用提示条显示（后台由系统通知显示）
          final title = message.notification?.title ?? '';
          final body = message.notification?.body ?? '';
          unawaited(HttpExceptionNotifyUser.showInfo([title, body].where((t) => t.isNotEmpty).join('\n')));
          return;
        }
        // 家人戒指异常：前台收到时刷新状态中心，横幅 / 红点 / 高危弹窗由它处理
        RingAlertCenter.instance.onPush();
        return;
      }
      if (eventName == 'emergency_follow_up') {
        var taskId = message.data['notificationId'].toString();
        ArrivalHospitalDialog.show(taskId: taskId);
      }

      if (eventName == 'incoming-call') {
        final callId = int.parse(message.data['call_id']);
        final operatorFullName = message.data['operator_full_name'];
        final customerFullName = message.data['customer_full_name'];
        final doctorFullName = message.data['doctor_full_name'];
        final customerUserId = int.parse(message.data['customer_user_id']);

        // 戴着戒指的用户：让戒指震动显示来电（Android 推消息到戒指；iOS 由系统通知转发）
        unawaited(SmartRingService.instance.notifyIncomingCall(
          title: 'MiAid',
          body: [doctorFullName, operatorFullName].where((n) => n != null && '$n'.isNotEmpty).join(' / '),
        ));

        if (store.hasOngoingCall || store.hasPendingCall) {
          print('Ongoingcall, ignoring incoming call event $callId');
        } else if (store.hasIncomingCall) {
          print('Incoming call, ignoring incoming call event $callId');
        } else {
          var params = IncomingCallScreenParams(
            incomingCallData: IncomingCallData(
              callId: callId,
              operatorFullName: operatorFullName,
              customerFullName: customerFullName,
              doctorFullName: doctorFullName,
              customerUserId: customerUserId,
            ),
          );

          // display customer call dialog
          Widget incomingCall = getIt<ScheduledCallScreen>(param1: params);
          // if the current user is not customer
          if (customerUserId != user.user?.id) {
            // display call dialog with reschedule options
            incomingCall = getIt<IncomingCallScreen>(param1: params);
          }

          if (context == null) {
            throw Exception('Context must be set before receiving notifications');
          }

          await showDialog<void>(
            context: context!,
            barrierDismissible: false,
            builder: (context) {
              store.setIncomingCall(
                incomingCallId: callId,
                incomingCallContext: context,
              );
              return incomingCall;
            },
          );
        }
      } else if (eventName == 'call-ended') {
        final callId = int.parse(message.data['call_id']);
        // gavin change here
        store.setOngoingCall(ongoingCall: null);
        store.closeIncomingCallScreen(callId);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // App 完全退出时点击通知冷启动：消息不会走上面两个 stream，
    // 只能通过 getInitialMessage 取回（同一条消息只返回一次，不会重复弹框）
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessageTap(initialMessage);
      });
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    // 未登录只能停留在登录页，不响应通知点击打开业务弹窗
    if (!getIt<UserProvider>().isLoggedIn) return;
    String? eventName;
    if (message.data.containsKey('event_name')) {
      eventName = message.data['event_name'];
    }
    if (eventName == 'emergency_follow_up') {
      var taskId = message.data['notificationId'].toString();
      ArrivalHospitalDialog.show(taskId: taskId);
    }
    if (eventName == 'ring_alert') {
      openRingAlertFromPush(message.data);
    }
  }
}

/// 点击「家人戒指异常」通知：进入该长辈的提醒列表并直接打开这一条。
void openRingAlertFromPush(Map<String, dynamic> data) {
  final nav = navigatorKey.currentState;
  if ('${data['self'] ?? ''}' == '1') {
    // 自己的提醒：打开自己的提醒记录
    nav?.push(MaterialPageRoute<void>(builder: (context) => const RingAlertsScreen(mine: true)));
    return;
  }
  final linkId = int.tryParse('${data['link_id'] ?? ''}');
  final alertId = int.tryParse('${data['alert_id'] ?? ''}');
  RingAlertCenter.instance.onPush();
  if (nav == null) return;
  nav.push(MaterialPageRoute<void>(
    builder: (context) => RingAlertsScreen(linkId: linkId, initialAlertId: alertId),
  ));
}
