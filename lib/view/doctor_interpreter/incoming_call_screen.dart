import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/calling/call_screen.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class IncomingCallScreenParams {
  const IncomingCallScreenParams({
    this.key,
    required this.incomingCallData,
  });

  final Key? key;
  final IncomingCallData incomingCallData;
}

@injectable
class IncomingCallScreenServices {
  IncomingCallScreenServices(this.store, this.user);

  final OngoingCallStore store;
  final UserProvider user;
}

@injectable
class IncomingCallScreen extends StatefulWidget {
  IncomingCallScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final IncomingCallScreenParams? params;
  final IncomingCallScreenServices services;

  @override
  _IncomingCallScreenState createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late Timer? _timer;

  @override
  void initState() {
    //widget.services.store.fetchScheduleOptions().then((value) => setState(() {}));

    const periodicSec = Duration(seconds: 30);
    _timer = Timer.periodic(periodicSec, (Timer t) async {
      final response = await widget.services.store.api.apiClientMain.callsPostCallActive();
      if (response.isSuccessful) {
        if (response.body?.payload == null) {
          // The call is no longer active
          widget.services.store.closeIncomingCallScreen(widget.params!.incomingCallData.callId);

          var sharedPreferences = await SharedPreferences.getInstance();
          await sharedPreferences.setString('doctor-or-translator-state', 'available');

          _timer?.cancel();
          _timer = null;
        }
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return callAlertDialog(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    widget.services.store.closeIncomingCallScreen(widget.params!.incomingCallData.callId);
    super.dispose();
  }

  AlertDialog callAlertDialog(BuildContext context) {
    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).incomingCall,
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
          Image.asset('assets/images/2x/ic_call_operator.png'),
          Text(
            widget.params?.incomingCallData.operatorFullName ?? '',
            style: GoogleFonts.rubik(fontSize: 24, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 10,),
          Container(child: Align(
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(S.of(context).customerName, style: GoogleFonts.rubik(
                  fontSize: 12,
                  color: AppColors.k696969,
                ),),
                Text(widget.params?.incomingCallData.customerFullName ?? '', style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),),
                Text('ID ' + (widget.params?.incomingCallData.customerUserId?.toString() ?? ''), style: GoogleFonts.rubik(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),),
              ],
            ),
          ),),
          Padding(
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TapDebouncer(
                    onTap: () async {
                      var sharedPreferences = await SharedPreferences.getInstance();
                      await sharedPreferences.setString('doctor-or-translator-state', 'busy');

                      await widget.services.store.acceptCall(widget.params!.incomingCallData.callId);
                      widget.services.store.closeIncomingCallScreen(widget.params!.incomingCallData.callId);
                      await Navigator.pushReplacement(context, MaterialPageRoute<void>(
                        builder: (context) => getIt<CallScreen>(),
                      ),);
                    },
                    builder: (context, onTap) => InkWell(
                      onTap: onTap,
                      child: Image(
                        image: AssetImage('assets/images/btn_call_answer.png'),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TapDebouncer(
                    onTap: () async {
                      var sharedPreferences = await SharedPreferences.getInstance();
                      await sharedPreferences.setString('doctor-or-translator-state', 'available');

                      await widget.services.store.rejectCall(widget.params!.incomingCallData.callId);
                      widget.services.store.closeIncomingCallScreen(widget.params!.incomingCallData.callId);
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
          ),
          ..._listScheduledOptions(context)
        ],
      ),
    );

    return alert;
  }

  dynamic _listScheduledOptions(BuildContext context) {
    var ret = [];

    /// translator不显示schedule options
    if (widget.services.user.isTranslator) {
      ret.add(Center(child: Text(''),));
      return ret;
    }

    if (!widget.services.user.isDoctor) {
      ret.add(Center(child: Text(''),));
      return ret;
    }

    /*var scheduledOptions = widget.services.store.shceduledOptions;
    if (!widget.services.user.isDoctor || scheduledOptions.isEmpty) {
      ret.add(Center(child: Text(''),));
    }*/

    var scheduledOptions = [];
    scheduledOptions.add(ScheduledOption(id: 1, time: 10));
    scheduledOptions.add(ScheduledOption(id: 2, time: 20));
    scheduledOptions.add(ScheduledOption(id: 3, time: 30));

    for (var i = 0; i < scheduledOptions.length; i++) {
      ret.add(_scheduledOptionItem(scheduledOptions[i], context));
    }
    return ret;
  }

  Widget _scheduledOptionItem(ScheduledOption option, BuildContext context) {
    var mins = option.time!; // 2 mins

    return TapDebouncer(
      onTap: () async {
        var sharedPreferences = await SharedPreferences.getInstance();
        await sharedPreferences.setString('doctor-or-translator-state', 'busy');

        await widget.services.store.rescheduleCall(widget.params!.incomingCallData.callId, option.time!,);
        widget.services.store.closeIncomingCallScreen(widget.params!.incomingCallData.callId,);

      },
      builder: (context, onTap) => OutlinedButton(
        onPressed: onTap,
        child: Text('${S.of(context).availableAfterMin(mins)}', style: GoogleFonts.rubik(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.k0CC58F,
        ),)
      ),
    );
  }
}
