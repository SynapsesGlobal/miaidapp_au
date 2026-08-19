import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/main.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/store/user/calling/call_screen_store.dart';
import 'package:miaid/store/user/chat/chat_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/chat/chat_screen.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../component/progress_indicator.dart';
import 'dart:developer' as developer;

class CallScreenParams {
  const CallScreenParams(this.key);

  final Key key;
}

@injectable
class CallScreenServices {
  CallScreenServices(
    this.store,
    this.chatStore,
    this.activeSubscriptionStore,
  );

  final CallScreenStore store;
  final ChatScreenStore chatStore;
  final ActiveSubscriptionStore activeSubscriptionStore;
}

@injectable
class CallScreen extends StatefulWidget {
  CallScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final CallScreenParams? params;
  final CallScreenServices services;

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? timer;
  bool isConnecting = true;
  // Waiting time
  int waitingTime = 60;
  @override
  void initState() {
    Wakelock.enable();

    widget.services.store.initEngine().then((_) {
      debugPrint('Going to call');
      timer = Timer.periodic(Duration(seconds: 1), (timer) async {
        widget.services.store.updateTimerText();
        if (timer.tick >= waitingTime && widget.services.store.thumbnailUserIds.isEmpty && (widget.services.store.isCallConnected == false)) {

          var sharedPreferences = await SharedPreferences.getInstance();
          await sharedPreferences.setString('doctor-or-translator-state', 'available');

          await HttpExceptionNotifyUser.showInfo(S.of(context).phoneNoResponseNotification);
          await widget.services.store.leaveCall();

          // FIXME: 感觉这里会是导致页面弹出两次有bug的原因
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            timer.cancel();
            await Navigator.pushReplacement(context, MaterialPageRoute<void>(
              settings: RouteSettings(name: "/"),
              builder: (context) => getHomeFromUser(widget.services.store.user.user),
            ));
          }
        }
        if (widget.services.store.isCallConnected) {
          if (isConnecting) {
            setState(() => isConnecting = false);
          }
        }
      });
    }).catchError((e) {
      // on error go to homepage
      if (e is HttpException && e.statusCode == 401) {
        widget.services.store.user.logOut();
        HttpExceptionNotifyUser.showInfo(S.of(context).relogin);
      } else {
        HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }

      Navigator.pushAndRemoveUntil(
        context,
        // ignore: inference_failure_on_instance_creation
        MaterialPageRoute<void>(
          settings: RouteSettings(name: '/'),
          builder: (context) => getHomeFromUser(widget.services.store.user.user),
        ),
        (route) => false,
      );
    });

    super.initState();
  }

  @override
  void dispose() {
    Wakelock.disable();
    timer?.cancel();
    isConnecting = true;
    widget.services.store.dispose();
    widget.services.activeSubscriptionStore.fetchActiveSubscription();

    widget.services.chatStore.dispose();
    super.dispose();
  }

  Future<String> fetchCallUserRole(int userId) async {
    var ongoingCall = widget.services.store.ongoingCallStore.ongoingCall;

    var doctorId = ongoingCall?.doctor?.user?.id;
    var translatorId = ongoingCall?.translator?.user?.id;
    var operatorId = ongoingCall?.$Operator?.user?.id;

    if (doctorId == userId) return 'Doctor';
    if (translatorId == userId) return 'Translator';
    if (operatorId == userId) return 'Operator';

    return 'Client';
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;
    store.localBuildContext = context;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(S.of(context).assistant,
        style: GoogleFonts.rubik(
          color: AppColors.kffffff,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        actions: [
          _muteButton(context),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.k010101, AppColors.k0cbcc5],
            stops: [0.0, 0.3,],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Observer(builder: (context) {
              if (store.isShowingFullScreen) {
                return _fullScreenVideo(context, store);
              }
              return _videoPlaceHolder(context, store);
            }),
            _topDropShadow(context),
            _timerTopScreen(context, store),
            _otherCallerVideos(context, store),
            _callButtons(context, store),
            _isShowingConnectingIndicator(context, store)
          ],
        ),
      ),
    );
  }

  Padding _muteButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 13,
      ),
      child: Observer(
        builder: (context) => widget.services.store.hasSpeaker ? navBarIcon(
          iconAssetName: 'ic_nb_call_sound.png',
          onTap: () async {
            await widget.services.store.toggleSpeaker();
          },
        ) : navBarIcon(
          iconAssetName: 'ic_nb_call_soundoff.png',
          onTap: () async {
            await widget.services.store.toggleSpeaker();
          },
        ),
      ),
    );
  }

  Positioned _callButtons(BuildContext context, CallScreenStore store) {
    return Positioned(
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Row(children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.k003f51.withOpacity(0.2),
                  blurRadius: 25.0,
                  spreadRadius: 5.0,
                  offset: Offset( 15.0, 15.0),
                )
              ],
              color: AppColors.kffffff,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10, right: 24,),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Stack(children: <Widget>[
                        Image(
                          fit: BoxFit.cover,
                          image: AssetImage('assets/images/btn_call_switchcamera.png'),
                          width: 32,
                          height: 32,
                        ),
                        Positioned.fill(child: Material(
                          color: Colors.transparent,
                          child: TapDebouncer(
                            onTap: () async {
                              await store.toggleCamera();
                            },
                            builder: (BuildContext context, onTap) => InkWell(
                              onTap: onTap,
                            ),
                          ),
                        ),),
                      ],),
                      SizedBox(width: 24.89,),
                      Stack(children: <Widget>[
                        Observer(
                          builder: (context) => Image(
                            fit: BoxFit.cover,
                            image: AssetImage(store.hasVideo ? 'assets/images/btn_call_turnonvideo.png' : 'assets/images/btn_call_turnoffvideo.png'),
                            width: 32,
                            height: 32,
                          ),
                        ),
                        Positioned.fill(child: Material(
                          color: Colors.transparent,
                          child: TapDebouncer(
                            onTap: () async {
                              await store.toggleVideo();
                            },
                            builder: (BuildContext context, onTap) => InkWell(
                              onTap: onTap,
                            ),
                          ),
                        ),),
                      ],),
                      SizedBox(width: 24.89,),
                      Stack(children: <Widget>[
                        Observer(
                          builder: (context) => Image(
                            fit: BoxFit.cover,
                            image: AssetImage(store.hasMicrophone ? 'assets/images/btn_call_turnonmic.png' : 'assets/images/btn_call_turnoffmic.png'),
                            width: 32,
                            height: 32,
                          ),
                        ),
                        Positioned.fill(child: Material(
                          color: Colors.transparent,
                          child: TapDebouncer(
                            onTap: () async {
                              await store.toggleMicrophone();
                            },
                            builder: (BuildContext context, onTap) => InkWell(
                              onTap: onTap,
                            ),
                          ),
                        ),),
                      ],),
                      /*SizedBox(width: 24.89,),
                      InkWell(
                        onTap: () async {
                          if (store.isChatEnabled) {
                            await Navigator.push(context, MaterialPageRoute<void>(
                              builder: (context) => getIt<ChatScreen>(),
                            ),);
                            setState(() => {});
                          }
                        },
                        child: Image(
                          fit: BoxFit.cover,
                          image: AssetImage('assets/images/btn_call_chat.png'),
                          width: 32,
                          height: 32,
                        ),
                      ),*/
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.k003f51.withOpacity(0.2),
                  blurRadius: 25.0, // soften the shadow
                  spreadRadius: 5.0, //extend the shadow
                  offset: Offset(15.0, 15.0,),
                )
              ],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(children: <Widget>[
              Image(image: AssetImage('assets/images/btn_call_hangup.png'),),
              Positioned.fill(child: Material(
                color: Colors.transparent,
                child: TapDebouncer(
                  onTap: () async {
                    endPhoneCallAlert(context, store);
                  },
                  builder: (BuildContext context, onTap) => InkWell(
                    onTap: onTap,
                  ),
                ),
              ),),
            ],),
          )
        ],),
      ),
    );
  }

  Positioned _otherCallerVideos(BuildContext context, CallScreenStore store) {
    return Positioned(
      bottom: 80,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, left: 0,),
        child: Observer(
          builder: (context) => Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ..._videoThumbnails(context, store),
            ],
          ),
        ),
      ),
    );
  }

  Observer _isShowingConnectingIndicator(
      BuildContext context, CallScreenStore store) {
    return Observer(
      builder: (context) => Positioned.fill(child: Align(
        alignment: Alignment.center,
        child: Visibility(
          visible: isConnecting,
          child: Container(
            height: 100,
            child: Column(children: [
              Align(
                alignment: Alignment.center,
                child: progressIndicator(),
              ),
              SizedBox(height: 10,),
              Text(S.of(context).connecting, style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),),
            ],),
          ),
        ),
      ),),
    );
  }

  List<Widget> _videoThumbnails(BuildContext context, CallScreenStore store) {
    if (store.thumbnailUserIds.isEmpty) {
      return <Widget>[_noCaller(context)];
    }
    return <Widget>[
      // 显示其他用户的视频
      for (var userId in store.thumbnailUserIds)
        if (userId != store.fullScreenVideoUserId)
          _videoThumbnail(context, userId, false),

      // 如果本地用户不是全屏显示，但有视频，那么显示小窗口
      if (!store.isLocalFullScreen && store.hasVideo)
        _videoThumbnail(context, store.user.user!.id!, true)
      // 如果本地用户不是全屏显示，但没有视频，那么显示占位图
      else if (!store.isLocalFullScreen && !store.hasVideo)
        _noCaller(context)
    ];
  }

  Widget _noCaller(BuildContext context) {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.k000000.withOpacity(0.24),
            blurRadius: 15.0,
            spreadRadius: 0.0, //extend the shadow
            offset: Offset(0.0, 8),
          ),
        ],
      ),
      child: Image(
        image: AssetImage('assets/images/ph_call_user.png'),
      ),
    );
  }

  Widget _videoThumbnail(BuildContext context, int userId, bool isLocal,) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: GestureDetector(
        onTap: () {
          widget.services.store.setFullScreenUserId(userId);
        },
        child: Stack(children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppColors.kffffff,
                width: 2,
              ),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.k000000.withOpacity(0.24),
                  blurRadius: 15.0,
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset(0.0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: isLocal || widget.services.store.ongoingCallStore.ongoingCall == null
                  ? _localVideoView()
                  : _remoteVideoView(
                      key: Key(userId.toString()),
                      uid: userId,
                      channelId: widget.services.store.ongoingCallStore.ongoingCall!.channelName!,
                    ),
            ),
          ),
          Positioned(bottom: 10, left: 10, child: FutureBuilder(
            future: fetchCallUserRole(userId),
            builder: (context, snapshot) {
              String? role = 'Client';
              if (snapshot.hasData) {
                role = snapshot.data;
              }
              var roleIcon = 'assets/images/ph_call_user.png';
              if (role == 'Doctor') roleIcon = 'assets/images/ph_call_doctor.png';
              if (role == 'Translator') roleIcon = 'assets/images/ph_call_translator.png';
              if (role == 'Operator') roleIcon = 'assets/images/ph_call_operator.png';
              return Image.asset(width: 40, height: 40, roleIcon);
            },
          ),)
        ],)
      ),
    );
  }

  Positioned _timerTopScreen(BuildContext context, CallScreenStore store) {
    return Positioned(
      top: AppBar().preferredSize.height + 25,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.k010101.withOpacity(0.3),
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 17,
            right: 17,
            top: 10,
            bottom: 10,
          ),
          child: Observer(
            builder: (context) => Text(
              store.timerText,
              style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Container _topDropShadow(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.k010101, Colors.transparent],
          stops: [0.0, 0.3,],
        ),
      ),
    );
  }

  Widget _fullScreenVideo(BuildContext context, CallScreenStore store) {
    /*if (store.isLocalFullScreen) {
      return RtcLocalView.SurfaceView();
    }

    try {
      return RtcRemoteView.SurfaceView(
        key: Key(store.fullScreenVideoUserId.toString()),
        uid: store.fullScreenVideoUserId!,
        channelId: store.ongoingCallStore.ongoingCall!.channelName!
      );
    } catch (e) {
      return Container();
    }*/

    if (store.isLocalFullScreen) {
      return Stack(children: [
        _localVideoView(),
        Positioned(top: 100, left: 20, child: FutureBuilder(
          future: fetchCallUserRole(9999999999),
          builder: (context, snapshot) {
            String? role = 'Client';
            if (snapshot.hasData) {
              role = snapshot.data;
            }
            var roleIcon = 'assets/images/ph_call_user.png';
            if (role == 'Doctor') roleIcon = 'assets/images/ph_call_doctor.png';
            if (role == 'Translator') roleIcon = 'assets/images/ph_call_translator.png';
            if (role == 'Operator') roleIcon = 'assets/images/ph_call_operator.png';
            return Image.asset(width: 40, height: 40, roleIcon);
          },
        ),)
      ],);
    }

    try {
      return Stack(children: [
        _remoteVideoView(
          key: UniqueKey(),
          uid: store.fullScreenVideoUserId!,
          channelId: store.ongoingCallStore.ongoingCall!.channelName!,
        ),
        Positioned(top: 100, left: 20, child: FutureBuilder(
          future: fetchCallUserRole(store.fullScreenVideoUserId!),
          builder: (context, snapshot) {
            String? role = 'Client';
            if (snapshot.hasData) {
              role = snapshot.data;
            }
            var roleIcon = 'assets/images/ph_call_user.png';
            if (role == 'Doctor') roleIcon = 'assets/images/ph_call_doctor.png';
            if (role == 'Translator') roleIcon = 'assets/images/ph_call_translator.png';
            if (role == 'Operator') roleIcon = 'assets/images/ph_call_operator.png';
            return Image.asset(width: 40, height: 40, roleIcon);
          },
        ),)
      ],);
    } catch (e) {
      return Container();
    }
  }


  Widget _videoPlaceHolder(BuildContext context, CallScreenStore store) {
    return Image(image: AssetImage('assets/images/ph_call_user.png'),);
  }

  Widget _localVideoView() {
    final engine = widget.services.store.engine;
    if (engine == null) {
      return Image(image: AssetImage('assets/images/ph_call_user.png'));
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _remoteVideoView({
    Key? key,
    required int uid,
    required String channelId,
  }) {
    final engine = widget.services.store.engine;
    if (engine == null) {
      return Image(image: AssetImage('assets/images/ph_call_user.png'));
    }
    return AgoraVideoView(
      key: key,
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: channelId),
      ),
    );
  }

  void endPhoneCallAlert(BuildContext context, CallScreenStore store) {
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
              onPressed: () async {
                try {
                  await EasyLoading.show(maskType: EasyLoadingMaskType.clear,);
                  await store.leaveCall();
                } catch (e) {
                  // catch any error and leave call anyway to avoid stuck in call
                  developer.log(e.toString());
                } finally {
                  await EasyLoading.dismiss();
                }

                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    await Navigator.pushReplacement(context, MaterialPageRoute<void>(
                      settings: RouteSettings(name: "/"),
                      builder: (context) => getHomeFromUser(widget.services.store.user.user),
                    ),);
                  }
                } else {
                  await Navigator.pushReplacement(context, MaterialPageRoute<void>(
                    settings: RouteSettings(name: "/"),
                    builder: (context) => getHomeFromUser(widget.services.store.user.user),
                  ),);
                }
              },
              child: Text(S.of(context).yes, style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 14,
              ),),
            ),
          ),
          SizedBox(height: 20,),
          Center(child: InkWell(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(context, MaterialPageRoute<void>(
                  settings: RouteSettings(name: "/"),
                  builder: (context) => getHomeFromUser(widget.services.store.user.user),
                ),);
              }
            },
            child: Text(S.of(context).cancel, style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: 14,
            ),),
          ),),
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
        S.of(context).endPhoneCallAlert,
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
}
