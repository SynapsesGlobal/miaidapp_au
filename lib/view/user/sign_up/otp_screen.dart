import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/user/otp/otp_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/sign_up/sign_up_2.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class OtpScreenParams {
  const OtpScreenParams(this.key);

  final Key key;
}

@injectable
class OtpScreenServices {
  OtpScreenServices(this.api, this.store, this.user);

  final ApiProvider api;
  final OtpStore store;
  final UserProvider user;
}

@injectable
class OtpScreen extends StatefulWidget {
  OtpScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final OtpScreenParams? params;
  final OtpScreenServices services;

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  final otpController = TextEditingController();
  final errorController = StreamController<ErrorAnimationType>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    errorController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).signUp,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        /*leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
            );
          },
        ),*/
        actions: [
          TapDebouncer(
            onTap: () async => await logout(context, widget.services.user),
            builder: (context, onTap) => InkWell(
              onTap: onTap,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    S.of(context).logout,
                    style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.only(top: 24.1, left: 41.5, right: 41.5),
              child: Center(
                child: Text(
                  '${S.of(context).verifyAccountText} \n ${S.of(context).continues}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(top: 24.1, left: 41.5, right: 41.5),
              child: Center(
                child: Text(
                  '${S.of(context).veryfyOTPText} \n ${S.of(context).dedicatedEmail}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Form(
              key: formKey,
              child: Padding(
                padding: const EdgeInsets.only(top: 40, left: 43, right: 42),
                child: PinCodeTextField(
                  appContext: context,
                  pastedTextStyle: TextStyle(
                    color: AppColors.k0cbcc5,
                    fontWeight: FontWeight.bold,
                  ),
                  length: 4,
                  animationType: AnimationType.scale,
                  // validator: (v) {
                  //   if (v.length < 3) {
                  //     return 'Invalid OTP';
                  //   } else {
                  //     return null;
                  //   }
                  // },
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(10),
                    fieldHeight: 70,
                    fieldWidth: 50,
                    inactiveColor: AppColors.k0cbcc5,
                    inactiveFillColor: AppColors.k0cbcc5.withOpacity(0.1),
                    activeColor: AppColors.k0cbcc5.withOpacity(0.1),
                    activeFillColor: AppColors.k0cbcc5.withOpacity(0.1),
                    selectedColor: AppColors.k0cbcc5.withOpacity(0.1),
                    selectedFillColor: AppColors.k0cbcc5.withOpacity(0.1),
                  ),
                  cursorColor: AppColors.k0cbcc5,
                  animationDuration: Duration(milliseconds: 300),
                  textStyle: TextStyle(
                    fontSize: 20,
                    height: 1.6,
                    color: AppColors.k0cbcc5,
                  ),
                  enableActiveFill: true,
                  errorAnimationController: errorController,
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  onCompleted: (v) async {
                    await verifyOtp();
                  },
                  beforeTextPaste: (text) {
                    //if you return true then it will show the paste confirmation dialog. Otherwise if false, then nothing will happen.
                    //but you can show anything you want here, like your pop up saying wrong paste format or etc
                    return true;
                  },
                  onChanged: (String value) {
                    //NOP
                  },
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(top: 24.1, left: 41.5, right: 41.5),
              child: Center(
                child: Text(
                  S.of(context).dontHaveCode,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(
                    color: AppColors.k5e5e5e,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () async {
                  await EasyLoading.show(
                    status: S.of(context).loading,
                    maskType: EasyLoadingMaskType.black,
                  );

                  otpController.clear();
                  var verifyOtpResendResponse = await widget
                      .services.api.apiClient
                      .authPostOtpVerificationReSend();

                  await EasyLoading.dismiss();

                  if (verifyOtpResendResponse.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.k0cbcc5,
                        content: Text(S.of(context).resendOtpSuccess),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.k0cbcc5,
                        content: Text(S.of(context).resendOtpFailed),
                      ),
                    );
                    var message =
                        ApiErrorParser.message(verifyOtpResendResponse.error);
                  }
                },
                child: Text(
                  S.of(context).resendOtp,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> verifyOtp() async {
    if ((formKey.currentState?.validate() ?? false) &&
        otpController.text.isNotEmpty) {
      var otp = int.parse(otpController.text);
      var verifyOtpResponse =
          await widget.services.api.apiClient.authPostOtpVerification(
        otp_code: otp,
      );

      if (ApiSuccessParser.isSuccessfulWithPayload(verifyOtpResponse)) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => getIt<SignUp2>(),
          ),
        );
      } else {
        var message = ApiErrorParser.message(verifyOtpResponse.error);
        verifyOtpResponse.statusCode == 422
            ? message = S.of(context).invalidOtp
            : message = message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.k0cbcc5,
            content: Text(
              message ?? '',
            ),
          ),
        );
      }
    } else if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.k0cbcc5,
          content: Text(
            'Please enter an OTP.',
          ),
        ),
      );
    }
  }
}
