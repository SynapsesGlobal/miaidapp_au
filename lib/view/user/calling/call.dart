import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/chat/chat_screen.dart';

class Call extends StatefulWidget {
  @override
  _CallState createState() => _CallState();
}

class _CallState extends State<Call> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          S.of(context).assistant,
          style: GoogleFonts.rubik(
            color: AppColors.kffffff,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
        actions: [
          _muteButton(context),
        ], systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.k010101, AppColors.k0cbcc5],
            stops: [
              0.0,
              0.3,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            _fullScreenVideo(context),
            _topDropShadow(context),
            _timerTopScreen(context),
            _otherCallerVideos(context),
            _callButtons(context),
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
      child: navBarIcon(iconAssetName: 'ic_nb_call_soundoff.png'),
    );
  }

  Positioned _callButtons(BuildContext context) {
    return Positioned(
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.k003f51.withOpacity(0.2),
                    blurRadius: 25.0, // soften the shadow
                    spreadRadius: 5.0, //extend the shadow
                    offset: Offset(
                      15.0, // Move to right 10  horizontally
                      15.0, // Move to bottom 10 Vertically
                    ),
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
                    padding: const EdgeInsets.only(
                      left: 24,
                      top: 10,
                      bottom: 10,
                      right: 24,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Image(
                          fit: BoxFit.cover,
                          image: AssetImage(
                              'assets/images/btn_call_switchcamera.png'),
                          width: 32,
                          height: 32,
                        ),
                        SizedBox(
                          width: 24.89,
                        ),
                        Image(
                          fit: BoxFit.cover,
                          image: AssetImage(
                              'assets/images/btn_call_turnoffvideo.png'),
                          width: 32,
                          height: 32,
                        ),
                        SizedBox(
                          width: 24.89,
                        ),
                        Image(
                          fit: BoxFit.cover,
                          image: AssetImage(
                              'assets/images/btn_call_turnonmic_copy.png'),
                          width: 32,
                          height: 32,
                        ),
                        /*SizedBox(
                          width: 24.89,
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (context) => getIt<ChatScreen>(),
                              ),
                            );
                          },
                          child: Image(
                            fit: BoxFit.cover,
                            image:
                                AssetImage('assets/images/btn_call_chat.png'),
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
                    offset: Offset(
                      15.0, // Move to right 10  horizontally
                      15.0, // Move to bottom 10 Vertically
                    ),
                  )
                ],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image(
                image: AssetImage('assets/images/btn_call_hangup.png'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Positioned _otherCallerVideos(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.only(
          right: 16,
          left: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _videoThumbnail(context),
            _videoThumbnail(context),
            _videoThumbnail(context),
          ],
        ),
      ),
    );
  }

  Widget _videoThumbnail(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Container(
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
              offset: Offset(
                0.0, // Move to right 10  horizontally
                8, // Move to bottom 10 Vertically
              ),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image(
            fit: BoxFit.cover,
            image: AssetImage('assets/images/female_doctor.jpg'),
          ),
        ),
      ),
    );
  }

  Positioned _timerTopScreen(BuildContext context) {
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
          child: Text(
            '4:36',
            style: GoogleFonts.rubik(
              color: AppColors.kffffff,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
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
          stops: [
            0.0,
            0.3,
          ],
        ),
      ),
    );
  }

  Image _fullScreenVideo(BuildContext context) {
    return Image(
      fit: BoxFit.cover,
      image: AssetImage('assets/images/doctor.jpg'),
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
    );
  }
}
