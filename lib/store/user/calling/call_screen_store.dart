import 'dart:core';

import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/agora_settings.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/main.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/store/user/chat/chat_screen_store.dart';
import 'package:mobx/mobx.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

part 'call_screen_store.g.dart';

enum VIDEO_CALL_TYPE {
  NONE,
  ASSISTANCE,
  CONSULT_A_DOCTOR,
}

@injectable
class CallScreenStore = _CallScreenStore with _$CallScreenStore;

abstract class _CallScreenStore with Store {
  _CallScreenStore(
    this.api,
    this.agoraSettings,
    this.user,
    this.ongoingCallStore,
    this.chatScreenStore,
  );

  final ApiProvider api;
  final AgoraSettings agoraSettings;
  final UserProvider user;
  final OngoingCallStore ongoingCallStore;
  final ChatScreenStore chatScreenStore;

  RtcEngine? _engine;

  BuildContext? localBuildContext;

  @observable
  bool hasJoinedChannel = false;

  @observable
  bool hasSpeaker = false;

  @observable
  bool frontCamera = true;

  @observable
  bool hasVideo = false;

  @observable
  bool hasMicrophone = true;

  // TODO translate
  @observable
  String timerText = '';

  @observable
  int? fullScreenVideoUserId;

  // if fullScreenVideoUserId is null, then show local video
  // if fullScreenVideoUserId is not null, and current user id is equal to fullScreenVideoUserId, then show local video
  @computed
  bool get isLocalFullScreen => fullScreenVideoUserId == null || user.user?.id == fullScreenVideoUserId;

  @computed
  bool get isShowingFullScreen => !isLocalFullScreen || (isLocalFullScreen && hasVideo);

  @computed
  bool get isChatEnabled => ongoingCallStore.hasOngoingCall && (thumbnailUserIds.isNotEmpty || ongoingCallStore.ongoingCall?.$Operator != null);

  @observable
  ObservableList<int> thumbnailUserIds = <int>[].asObservable();

  @observable
  VIDEO_CALL_TYPE video_call_type = VIDEO_CALL_TYPE.NONE;

  Future<void> dispose() async {
    localBuildContext = null;
    await _engine?.leaveChannel();
    await _engine?.stopPreview();
    await _engine?.disableVideo();
    await _engine?.disableAudio();
    await _engine?.destroy();
  }

  //Gavin add here
  @observable
  bool isCallConnected = false;

  @action
  Future<void> startNewCall({
    VIDEO_CALL_TYPE video_call_type = VIDEO_CALL_TYPE.NONE,
    bool requestDoctor = false,
  }) async {
    // TODO comment/uncomment the lines above to test calls with hardcoded countries e.g. AU
    var position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
    var sharedPreferences = await SharedPreferences.getInstance();
    var videoSource = sharedPreferences.getString('video-call-source');
    var chatbotId = sharedPreferences.getString('chatbot-id') ?? '';

    var countryCode = await getCountryCodeFromLocation(position);
    var response = await api.apiClientMain.callsPostCreateCall(
      requests_doctor: requestDoctor,
      latitude: position.latitude,
      longitude: position.longitude,
      country_code: countryCode,
      video_call_type: video_call_type.index,
      chatbotId: videoSource == 'chatbot' ? chatbotId : ''
    );
    final call = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    ongoingCallStore.setOngoingCall(ongoingCall: call);

    await _joinChannel(
      channelName: call.channelName,
      agoraToken: call.channelToken,
      userId: call.userCallId,
    );
  }

  @action
  Future<void> startFromExistingCall(Call call) async {
    final response = await api.apiClientMain.callsPostCallActive();
    final call = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    ongoingCallStore.setOngoingCall(ongoingCall: call);
    developer.log(
        'Joining Channel [1] startFromExistingCall call: ${call.toJson()}');
    await chatScreenStore.initChatClientFromCall(call);

    await _joinChannel(
      channelName: call.channelName,
      agoraToken: call.channelToken,
      userId: call.userCallId,
    );
  }

  @action
  Future<void> leaveCall() async {

    var sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString('doctor-or-translator-state', 'available');

    final call = ongoingCallStore.ongoingCall;
    if (call != null) {
      final response = await api.apiClientMain.callsPostCallLeave(call_id: call.id!);
      ApiSuccessParser.isSuccessfulOrThrowWithMessage(response);
    }
    ongoingCallStore.setOngoingCall(ongoingCall: null);
    if (ongoingCallStore.hasPendingCall) {
      ongoingCallStore.setHasPendingCall(false);
    }
    await _engine?.leaveChannel();
  }

  Future<void> initEngine() async {
    if (_engine != null) {
      throw Exception('Engine has already been initialized');
    }

    await EasyLoading.show(
      status: 'Connecting...',
      maskType: EasyLoadingMaskType.clear,
    );

    _engine = await RtcEngine.create(agoraSettings.appId);

    ongoingCallStore.setHasPendingCall(true);
    await _engine!.enableVideo();
    await _engine!.enableAudio();
    await _engine!.startPreview();
    await _engine!.setChannelProfile(ChannelProfile.Communication);
    // await _engine!.setClientRole(ClientRole.Broadcaster);
    await _engine!.muteLocalAudioStream(!hasMicrophone);
    await _engine!.muteLocalVideoStream(!hasVideo);
    _addListeners();

    hasVideo = true;
    // await toggleCamera();

    //developer.log('Get active call');

    final response = await api.apiClientMain.callsPostCallActive();
    developer.log('response: ${response}');
    await ApiSuccessParser.isSuccessfulOrThrowWithMessage(response);

    final existingCall = response.body?.payload;
    if (existingCall == null) {
      developer.log('START new call');
      await startNewCall(video_call_type: video_call_type);
    } else {
      developer.log('EXISTING call');
      final response =
          await api.apiClientMain.callsPostCallAccept(call_id: existingCall.id);
      await ApiSuccessParser.payloadOrThrowWithMessage(response);
      await startFromExistingCall(existingCall);
    }

    await EasyLoading.dismiss();
  }

  void _addListeners() {
    //developer.log('AGORAD Adding listeners to engine $_engine');
    _engine?.setEventHandler(
      RtcEngineEventHandler(
        joinChannelSuccess: (channel, uid, elapsed) {
          // developer.log('AGORAD joinChannelSuccess $channel $uid $elapsed');
          _refreshOngoingCall();
          hasJoinedChannel = true;
        },
        userJoined: (uid, elapsed) async {
          // developer.log('AGORAD userJoined  $uid $elapsed');
          _refreshOngoingCall();
          thumbnailUserIds.add(uid);
          isCallConnected = true;
          if (fullScreenVideoUserId == null) {
            setFullScreenUserId(uid);
          }
        },
        userOffline: (uid, reason) {
          //developer.log('AGORAD userOffline  $uid $reason');
          _refreshOngoingCall();
          // if the offline user is the full screen user, set full screen user to another user in the list if available
          // otherwise, set full screen user to the local user
          if (fullScreenVideoUserId == uid) {
            if (thumbnailUserIds.isNotEmpty) {
              setFullScreenUserId(thumbnailUserIds.first);
            } else {
              setFullScreenUserId(user.user!.id!);
            }
          }
          thumbnailUserIds.remove(uid);
        },
        leaveChannel: (stats) {
          //developer.log('AGORAD leaveChannel ${stats.toJson()}');
          hasJoinedChannel = false;
          thumbnailUserIds.clear();
        },
        error: (errorCode) {
          //developer.log('AGORAD error $errorCode');
        },
      ),
    );
  }

  void _refreshOngoingCall() async {
    final response = await api.apiClientMain.callsPostCallActive();

    // no active call, return to home, clear ongoing call and pending call
    if (response.isSuccessful && response.body?.payload == null) {
      //developer.log('_refreshOngoingCall $localBuildContext');
      if (localBuildContext != null) {
        await Navigator.pushReplacement(
          localBuildContext!,
          MaterialPageRoute<void>(
            settings: RouteSettings(name: "/"),
            builder: (context) => getHomeFromUser(user.user),
          ),
        );
      }

      ongoingCallStore.setOngoingCall(ongoingCall: null);
      if (ongoingCallStore.hasPendingCall) {
        ongoingCallStore.setHasPendingCall(false);
      }

      // has active call, update ongoing call
    } else {
      final call = await ApiSuccessParser.payloadOrThrowWithMessage(response);
      ongoingCallStore.setOngoingCall(ongoingCall: call);
      debugPrint('Ongoing call: ${call.toJson()}');
      await chatScreenStore.initChatClientFromCall(call);
    }
  }

  Future<void> _joinChannel({
    required String channelName,
    required String agoraToken,
    required int userId,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [Permission.microphone, Permission.camera].request();
    }

    developer.log(
        'Joining Channel [1] _joinChannel: agoraToken${agoraToken} -- channelName${channelName} -- userId${userId}');

    final options = ChannelMediaOptions(
      publishLocalAudio: hasMicrophone,
      publishLocalVideo: hasVideo,
    );

    await _engine?.joinChannel(
      agoraToken,
      channelName,
      null,
      userId,
      options,
    );
  }

  void leaveChannel() async {
    await _engine?.leaveChannel();
  }

  @action
  Future<void> toggleCamera() async {
    //developer.log('toggleCamera');
    frontCamera = !frontCamera;
    await _engine?.switchCamera();
  }

  @action
  Future<void> toggleSpeaker() async {
    hasSpeaker = !hasSpeaker;
    await _engine?.setEnableSpeakerphone(hasSpeaker);
  }

  @action
  Future<void> toggleMicrophone() async {
    hasMicrophone = !hasMicrophone;
    //developer.log('hasMicrophone $hasMicrophone');
    await _engine?.muteLocalAudioStream(!hasMicrophone);
  }

  @action
  Future<void> toggleVideo() async {
    hasVideo = !hasVideo;
    //developer.log('hasVideo $hasVideo');
    if (hasVideo) {
      await _engine?.startPreview();
      await _engine?.muteLocalVideoStream(false);
    } else {
      await _engine?.stopPreview();
      await _engine?.muteLocalVideoStream(true);
    }
  }

  @action
  void updateTimerText() {
    timerText = getTimerText();
  }

  @action
  void setFullScreenUserId(int userId) {
    fullScreenVideoUserId = userId;
  }

  String getTimerText() {
    if (!ongoingCallStore.hasOngoingCall) {
      return '...';
    }

    final callStartedAtStr = ongoingCallStore.ongoingCall?.customerJoinedAt ??
        ongoingCallStore.ongoingCall?.doctorJoinedAt ??
        ongoingCallStore.ongoingCall?.translatorJoinedAt;

    if (callStartedAtStr == null) {
      return 'calling...';
    }

    final now = DateTime.now();
    final callStartedAt = DateTime.parse(callStartedAtStr);
    final difference = now.difference(callStartedAt).abs();

    final hoursNumber = difference.inHours;
    final hours = formatDifference(difference.inHours);
    final minutes = formatDifference(difference.inMinutes % 60);
    final seconds = formatDifference(difference.inSeconds % 60);

    if (hoursNumber == 0) {
      return '$minutes:$seconds';
    }

    return '$hours:$minutes:$seconds';
  }

  String formatDifference(int time) {
    if (time < 10) {
      return '0$time';
    }
    return '$time';
  }
}
