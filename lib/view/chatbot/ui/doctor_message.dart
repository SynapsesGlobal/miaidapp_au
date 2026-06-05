import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';
import '../../../store/user/calling/call_screen_store.dart';
import '../../user/calling/call_screen_helper.dart';

class DoctorMessage extends StatelessWidget {
  final dynamic message;
  final dynamic services;
  final String chatbotId;
  const DoctorMessage({super.key, this.message, this.services, required this.chatbotId});

  @override
  Widget build(BuildContext context) {
    return message['content'].toString().isNotEmpty ? Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          maxRadius: 16,
          backgroundColor: AppColors.k0cbcc5,
          child: Image.asset('assets/images/logo_auth.png'),
        ),
        SizedBox(width: 10,),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width*0.7
          ),
          child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10)
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              message['content'].contains('background-color') ? Html(
                data: message['content'],
                style: {'a': Style(
                  fontSize: FontSize.medium,
                  color: AppColors.k0cbcc5,
                  textDecoration: TextDecoration.none
                ),},
                onAnchorTap: (url,context1, attributes) async {
                  showAlertDialog(context);
                },
              ) : Text(
                message['content'],
                textAlign: TextAlign.left,
                style: GoogleFonts.rubik(
                  color: Colors.black,
                  fontSize: 15,
                )
              ),
              message.containsKey('video_consultation') ? InkWell(
                onTap: () async {
                  showAlertDialog(context);
                },
                child: Text(S.of(context).click, textAlign: TextAlign.left, style: TextStyle(
                  color: AppColors.k0cbcc5,
                  fontWeight: FontWeight.bold
                ),),
              ) : Offstage(),
              message.containsKey('appoint_interpreter') ? InkWell(
                onTap: () async {
                  showAlertDialog(context);
                },
                child: Text(S.of(context).click, textAlign: TextAlign.left, style: TextStyle(
                  color: AppColors.k0cbcc5,
                  fontWeight: FontWeight.bold
                ),),
              ) : Offstage()
            ],),
          ),
        ),
      ],
    ) : Offstage();
  }

  void showAlertDialog(BuildContext context) {
    Widget okButton = Padding(
      padding: const EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
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
                  offset: const Offset(0.0, 4),
                ),
              ],
            ),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                S.of(context).no,
                style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 14),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                S.of(context).yes,
                style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );

    var alert = AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      title: Text(
        S.of(context).videoConsult,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(color: AppColors.k010101, fontWeight: FontWeight.w700, fontSize: 14),
      ),
      content: Text(
        S.of(context).proceed_video_consultation,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(fontSize: 13),
      ),
      actions: [okButton],
    );

    showDialog(context: context, builder: (BuildContext context) => alert).then((value) async {
      if (value ?? false) {
        var sharedPreferences = await SharedPreferences.getInstance();
        await sharedPreferences.setString('video-call-source', 'chatbot');
        await sharedPreferences.setString('chatbot-id', chatbotId);
        await navigateToCallScreen(context, services, VIDEO_CALL_TYPE.ASSISTANCE);
      }
    });
  }
}
