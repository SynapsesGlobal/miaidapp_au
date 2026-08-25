import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:miaid/api_utils/session_revoked_handler.dart';
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
      if (eventName == 'emergency_follow_up') {
        var taskId = message.data['notificationId'].toString();
        ArrivalHospitalDialog.show(taskId: taskId);
      }

      // 账号在其他设备登录，本设备被踢下线（后端登录踢出时实时推送）
      if (eventName == 'logged-in-elsewhere') {
        SessionRevokedHandler.handleKickedPush();
        return;
      }

      if (eventName == 'incoming-call') {
        final callId = int.parse(message.data['call_id']);
        final operatorFullName = message.data['operator_full_name'];
        final customerFullName = message.data['customer_full_name'];
        final doctorFullName = message.data['doctor_full_name'];
        final customerUserId = int.parse(message.data['customer_user_id']);

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
    String? eventName;
    if (message.data.containsKey('event_name')) {
      eventName = message.data['event_name'];
    }
    if (eventName == 'emergency_follow_up') {
      var taskId = message.data['notificationId'].toString();
      ArrivalHospitalDialog.show(taskId: taskId);
    }
    // 后台收到踢出推送后点通知进入 App：此时补做本地登出和提示
    if (eventName == 'logged-in-elsewhere') {
      SessionRevokedHandler.handleKickedPush();
    }
  }
}
