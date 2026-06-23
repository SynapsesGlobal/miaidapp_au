import 'dart:ui';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/user/password/forgot_password/forgot_password_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';

class ForgotPasswordParams {
  const ForgotPasswordParams({
    this.key,
    this.userType,
  });

  final Key? key;
  final String? userType;
}

@injectable
class ForgotPasswordServices {
  ForgotPasswordServices(this.api, this.store);

  final ApiProvider api;
  final ForgotPasswordStore store;
}

@injectable
class ForgotPassword extends StatefulWidget {
  ForgotPassword({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final ForgotPasswordParams? params;
  final ForgotPasswordServices services;

  @override
  _ForgotPasswordState createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final forgotEmailController = TextEditingController();

  final formKey = GlobalKey<FormState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).forgotPass,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 51.42,
              ),
              Container(
                height: 117,
                width: 117,
                child: Image(
                  image: AssetImage('assets/images/logo_forgot Password.png'),
                ),
              ),
              SizedBox(
                height: 36.6,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  child: Text(
                    S.of(context).forgotPassMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 33,
              ),
              Form(
                key: formKey,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).email,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color: forgotEmailController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      TextFormField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return S.of(context).entEmail;
                          } else if (!EmailValidator.validate(value.trim())) {
                            return S.of(context).entVEmain;
                          }
                          return null;
                        },
                        onChanged: (value) {},
                        controller: forgotEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'yourname@example.com',
                          hintStyle: TextStyle(
                            color: AppColors.kb1b1b1,
                            fontSize: 14,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: 16,
                            top: 5,
                            bottom: 5,
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.kfa0020,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.kfa0020,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.kb1b1b1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.kb1b1b1,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 30,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: 44,
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(AppColors.k0cbcc5),
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    onPressed: () async {
                      widget.services.store.autovalidateMode =
                          AutovalidateMode.onUserInteraction;

                      if (formKey.currentState?.validate() ?? false) {
                        await EasyLoading.show(
                          status: S.of(context).loading,
                          maskType: EasyLoadingMaskType.black,
                        );

                        // if widget.params.userType is null or equals to 'customer', then request to sub server
                        var apiClient = widget.params?.userType == null ||
                                widget.params?.userType == 'customer'
                            ? widget.services.api.apiClientSub
                            : widget.services.api.apiClientMain;

                        final response =
                            await apiClient.forgotpasswordPostResetPassword(
                          email: forgotEmailController.text,
                        );

                        await EasyLoading.dismiss();

                        if (!mounted) return;

                        if (ApiSuccessParser.isSuccessfulWithPayload(
                            response)) {
                          showAlertDialog(context);
                        } else if (response.statusCode == 422) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.k010101,
                              content: Text(
                                S.of(context).forgotPasswordCheckEmail,
                              ),
                            ),
                          );
                        } else {
                          var message =
                              ApiErrorParser.message(response.error) ?? '';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.k010101,
                              content: Text(
                                S.of(context).forgotPasswordCheckError(
                                    response.statusCode, message),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      S.of(context).resetPass,
                      style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showAlertDialog(BuildContext context) {
  Widget okButton = Padding(
    padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
    child: Container(
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
            offset: Offset(
              0.0, // Move to right 10  horizontally
              4, // Move to bottom 10 Vertically
            ),
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
        onPressed: () {
          Navigator.pushReplacement(context,
              MaterialPageRoute<void>(builder: (context) => getIt<SignIn>()));
          // Navigator.pop(context);
        },
        child: Text(
          S.of(context).okay,
          style: GoogleFonts.rubik(
            color: AppColors.kffffff,
            fontSize: 17,
          ),
        ),
      ),
    ),
  );

  var alert = AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    title: Text(
      S.of(context).linkSent,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(
        fontWeight: FontWeight.w500,
        fontSize: 17,
        color: AppColors.k010101,
      ),
    ),
    content: Text(
      S.of(context).linkSentMessage,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(
        fontSize: 13,
        color: AppColors.k010101,
      ),
    ),
    actions: [okButton],
  );

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
