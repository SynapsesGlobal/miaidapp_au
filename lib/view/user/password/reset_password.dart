import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/user/password/reset_password/reset_password_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:uni_links/uni_links.dart';

class ResetPasswordParams {
  const ResetPasswordParams(
      {this.key, required this.email, required this.token});

  final Key? key;
  final String email;
  final String token;
}

@injectable
class ResetPasswordServices {
  ResetPasswordServices(this.store, this.api);

  final ResetPasswordStore store;
  final ApiProvider api;
}

@injectable
class ResetPassword extends StatefulWidget {
  ResetPassword({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final ResetPasswordParams? params;
  final ResetPasswordServices services;

  @override
  _ResetPasswordState createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final formKey = GlobalKey<FormState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String? token;
  String? email;

  @override
  void initState() {
    // Urls look like this
    // http://stage.mi-aid.com.au/password/reset/830214ad4215da8832b9214f05475b0f7414ebd50772c4a5142f0983b010def9?email=operator%40a.aa
    // getInitialUri().then((initialUri) {
    //   if (initialUri != null &&
    //       initialUri.path.startsWith('/password/reset/')) {
    //     token = initialUri.path.replaceAll('/password/reset/', '');
    //     email = initialUri.queryParameters['email'];
    //   }
    // });
    // if params contains email and token, then set the value
    if (widget.params?.email != null && widget.params?.token != null) {
      email = widget.params?.email;
      token = widget.params?.token;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).resetPass,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Form(
                key: formKey,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).password,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color: passwordController.text.trim().isNotEmpty
                              ? AppColors.kb1b1b1
                              : AppColors.k010101,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Observer(
                        builder: (context) => TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return S.of(context).entPass;
                            } else if (value.length < 8) {
                              return S.of(context).passLength;
                            } else {
                              return null;
                            }
                          },
                          onChanged: (value) {},
                          controller: passwordController,
                          obscureText: store.obscurePasswordText,
                          decoration: InputDecoration(
                            hintText: S.of(context).passHint,
                            hintStyle: TextStyle(
                              color: AppColors.kb1b1b1,
                              fontSize: 14,
                            ),
                            contentPadding: EdgeInsets.only(
                              left: 16,
                              top: 5,
                              bottom: 5,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.k010101,
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
                            suffixIcon: Padding(
                              padding: EdgeInsets.all(0),
                              child: InkWell(
                                onTap: () {
                                  store.obscurePasswordText =
                                      !store.obscurePasswordText;
                                },
                                child: passwordEye(store.obscurePasswordText),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Text(
                        S.of(context).confirmPass,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color:
                              confirmPasswordController.text.trim().isNotEmpty
                                  ? AppColors.kb1b1b1
                                  : AppColors.k010101,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Observer(
                        builder: (context) => TextFormField(
                          controller: confirmPasswordController,
                          obscureText: store.obscureConfirmPasswordText,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return S.of(context).entConfrmPass;
                            } else if (value.trim() !=
                                passwordController.text.trim()) {
                              return S.of(context).passNotMatch;
                            } else {
                              return null;
                            }
                          },
                          onChanged: (value) {},
                          decoration: InputDecoration(
                            hintText: S.of(context).rePass,
                            hintStyle: TextStyle(
                              color: AppColors.kb1b1b1,
                              fontSize: 14,
                            ),
                            contentPadding: EdgeInsets.only(
                              left: 16,
                              top: 5,
                              bottom: 5,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.k010101,
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
                            suffixIcon: Padding(
                              padding: EdgeInsets.all(0),
                              child: InkWell(
                                onTap: () {
                                  store.obscureConfirmPasswordText =
                                      !store.obscureConfirmPasswordText;
                                },
                                child: passwordEye(
                                    store.obscureConfirmPasswordText),
                              ),
                            ),
                          ),
                        ),
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
                      if (formKey.currentState?.validate() ?? false) {
                        var response = await widget.services.api.apiClient
                            .forgotpasswordPostSetNewPassword(
                          email: email,
                          password: passwordController.text,
                          password_confirmation: confirmPasswordController.text,
                          token: token,
                        );

                        if (response.isSuccessful) {
                          formKey.currentState?.reset();
                          await showAlertDialog(context);
                          await Navigator.pushReplacement(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => getIt<SignIn>(),
                            ),
                          );
                        } else if (response.statusCode == 422) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.k0cbcc5,
                              content: Text(
                                S.of(context).resetPassword422Error,
                              ),
                            ),
                          );
                        } else {
                          var message = ApiErrorParser.message(response.error);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.k0cbcc5,
                              content: Text(
                                '${S.of(context).resetPasswordError} $message (${response.statusCode})',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      S.of(context).savePass,
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

Future<void> showAlertDialog(BuildContext context) async {
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
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => getIt<SignIn>(),
            ),
          );
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
      S.of(context).success,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.k010101,
      ),
    ),
    content: Text(
      S.of(context).successMessage,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(
        fontSize: 13,
        color: AppColors.k010101,
      ),
    ),
    actions: [okButton],
  );

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
