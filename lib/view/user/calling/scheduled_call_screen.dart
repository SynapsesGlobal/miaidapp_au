import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/doctor_interpreter/incoming_call_screen.dart';
import 'package:miaid/view/user/calling/call_screen.dart';
import 'package:mobx/mobx.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';


@injectable
class ScheduledCallScreenServices {
  ScheduledCallScreenServices(this.store);

  final OngoingCallStore store;
}

@injectable
class ScheduledCallScreen extends StatefulWidget {
  ScheduledCallScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final IncomingCallScreenParams? params;
  final ScheduledCallScreenServices services;

  @override
  _ScheduledCallScreenState createState() => _ScheduledCallScreenState();
}

class _ScheduledCallScreenState extends State<ScheduledCallScreen> {

  @observable
  bool isConnecting = false;

  @override
  Widget build(BuildContext context) {
    return callAlertDialog(context);
  }

  AlertDialog callAlertDialog(BuildContext context) {
    final callData = widget.params!.incomingCallData;

    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).scheduledCall,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 14,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Text(
              [callData.operatorFullName, callData.doctorFullName]
                  .where((name) => name != null)
                  .join(', '),
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.k0cbcc5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              // horizontal: 45,
              vertical: 30,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(
                  height: 55.14,
                  width: 55.14,
                  image: AssetImage('assets/images/ic_call_operator.png'),
                ),
                SizedBox(width: 4),
                Image(
                  height: 55.14,
                  width: 55.14,
                  image: AssetImage('assets/images/ic_call_doctor.png'),
                ),
                SizedBox(width: 4),
                Image(
                  height: 55.14,
                  width: 55.14,
                  image: AssetImage('assets/images/ic_call_translator.png'),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(
              left: 40,
              right: 30,
              bottom: 30,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TapDebouncer(
                  onTap: () async {
                    isConnecting = true;
                    if(isConnecting) {
                      await widget.services.store
                          .acceptCall(widget.params!.incomingCallData.callId);
                      widget.services.store
                          .closeIncomingCallScreen(widget.params!.incomingCallData.callId);


                      await Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) =>  getIt<CallScreen>(),
                        ),
                      );


                      isConnecting = false;
                    }



                  },
                  builder: (context, onTap) => InkWell(
                    onTap: onTap,
                    child: Image(
                      image: AssetImage('assets/images/btn_call_answer.png'),
                    ),
                  ),
                ),
                SizedBox(width: 25),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TapDebouncer(
                    onTap: () async {
                      await widget.services.store
                          .rejectCall(widget.params!.incomingCallData.callId);
                      widget.services.store
                          .closeIncomingCallScreen(widget.params!.incomingCallData.callId);
                    },
                    builder: (context, onTap) => InkWell(
                      onTap: onTap,
                      child: Image(
                        image: AssetImage('assets/images/btn_call_hangup.png'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );

    return alert;
  }
}
