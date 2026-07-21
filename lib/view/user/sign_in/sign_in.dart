import 'dart:async';
import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/notifications/notifications_token_provider.dart';
import 'package:miaid/services/location_upload_service.dart';
import 'package:miaid/store/user/sign_in/sign_in_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/password/forgot_password.dart';
import 'package:miaid/view/user/sign_up/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

import '../../../main.dart';
import '../../../services/FCMTokenService.dart';

class SignInParams {
  const SignInParams(this.key);

  final Key key;
}

@injectable
class SignInServices {
  SignInServices(this.api, this.store);

  final ApiProvider api;
  final SignInStore store;
}

@injectable
class SignIn extends StatefulWidget {
  SignIn({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final SignInParams? params;
  final SignInServices services;

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).signIn,
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 13,
              top: 10,
              bottom: 10,
            ),
            child: InkWell(
              onTap: () {
                final action = CupertinoActionSheet(
                  message: Text(
                    S.of(context).changeLanguage,
                    style: TextStyle(
                      fontSize: 13.0,
                      color: AppColors.k8f8e94,
                    ),
                  ),
                  actions: <Widget>[
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'en' ? true : false,
                      onPressed: () async {
                        await store.setLocale(Locale('en'));
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text(
                        'English',
                        style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'zh' ? true : false,
                      onPressed: () async {
                        await store.setLocale(Locale('zh'));
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text(
                        '简体中文',
                        style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'zh_Hant' ? true : false,
                      onPressed: () async {
                        await store.setLocale(AppSettings.localeFromCode('zh_Hant'));
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text(
                        '繁体中文',
                        style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'ko' ? true : false,
                      onPressed: () async {
                        await store.setLocale(Locale('ko'));
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('한국인', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 24,
                      ),),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'id' ? true : false,
                      onPressed: () async {
                        await store.setLocale(Locale('id'));
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('Indonesia', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 24,
                      ),),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'el' ? true : false,
                      onPressed: () async {
                        await store.setLocale(Locale('el'));
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('Ελληνικά', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 24,
                      ),),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      S.of(context).cancel,
                      style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 20,
                      ),
                    ),
                  ),
                );
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => action,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.keefeff,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k003f51.withOpacity(0.1),
                      blurRadius: 10.0,
                      spreadRadius: 0.0, //extend the shadow
                      offset: Offset(0, 4,),
                    ),
                  ],
                ),
                child: Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0,),
                  child: Observer(
                    builder: (context) => Text(
                      store.locale.languageCode == 'zh' ? '简' : (store.locale.languageCode == 'zh_Hant' ? '繁' : (store.locale.languageCode ?? 'en')).toUpperCase(),
                      style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),),
              ),
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          child: Observer(
            builder: (context) => Column(
              children: [
                SizedBox(height: 46,),
                Container(
                  height: 117,
                  width: 117,
                  child: Image(
                    image: AssetImage('assets/images/logo_auth.png'),
                  ),
                ),
                SizedBox(height: 46,),
                if (store.signInFailed)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 19,),
                    child: Container(
                      color: AppColors.kfa0020.withOpacity(0.1),
                      child: Row(children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 11, top: 19, bottom: 18),
                          child: Image(
                            image: AssetImage('assets/images/ic_signin_error.png',),
                          ),
                        ),
                        Expanded(child: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 9, top: 10, bottom: 10),
                          child: RichText(
                            textAlign: TextAlign.left,
                            text: TextSpan(
                              style: GoogleFonts.rubik(
                                color: AppColors.kff3b30,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(text: S.of(context).resetPassMessage),
                                TextSpan(
                                  text: ' ${S.of(context).resetPass}',
                                  recognizer: TapGestureRecognizer()..onTap = () {
                                    var params = ForgotPasswordParams(
                                      userType: widget.services.store.userType,
                                    );
                                    Navigator.push(context, MaterialPageRoute<void>(
                                      builder: (context) => getIt<ForgotPassword>(param1: params,),
                                    ),);
                                  },
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k0cbcc5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: S.of(context).orcreate),
                                TextSpan(
                                  text: S.of(context).newAccount,
                                  recognizer: TapGestureRecognizer()..onTap = () {
                                    Navigator.push(context, MaterialPageRoute<void>(
                                      builder: (context) => getIt<SignUp>(),
                                    ),);
                                  },
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k0cbcc5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),),
                      ],),
                    ),
                  ),
                Form(
                  key: formKey,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).role,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.rubik(
                            color: emailController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8,),
                        DropdownButtonFormField<String>(
                          value: store.userType,
                          onChanged: (String? newValue) {
                            store.userType = newValue!;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null) {
                              return S.of(context).emptyGender;
                            } else {
                              return null;
                            }
                          },
                          isExpanded: true,
                          isDense: false,
                          icon: Image.asset('assets/images/ic_pharmacy_location_expand.png'),
                          iconSize: 24,
                          elevation: 16,
                          style: GoogleFonts.rubik(color: AppColors.k5e5e5e),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(left: 16, right: 16),
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
                          ),
                          items: store.userTypes.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'doctor' ? S.of(context).doctorType : value == 'translator' ? S.of(context).translatorType : S.of(context).customerType,
                              style: GoogleFonts.rubik(
                                color: AppColors.k5e5e5e,
                                fontSize: 14,
                              ),
                            ),
                          )).toList(),
                        ),
                        SizedBox(height: 20,),
                        Text(
                          S.of(context).email,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.rubik(
                            color: emailController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8,),
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: store.autovalidateMode,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return S.of(context).entEmail;
                            } else if (!EmailValidator.validate(value.trim())) {
                              return S.of(context).entVEmain;
                            }
                            return null;
                          },
                          controller: emailController,
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
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.k010101,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.kfa0020,
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
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                // color: AppColors.kfa0020,
                                color: Colors.red,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        SizedBox(height: 20,),
                        Text(
                          S.of(context).password,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.rubik(
                            color: passwordController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8,),
                        TextFormField(
                          controller: passwordController,
                          obscureText: store.obscurePasswordText,
                          autovalidateMode: store.autovalidateMode,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return S.of(context).entPass;
                            } else {
                              return null;
                            }
                          },
                          decoration: InputDecoration(
                            hintText: S.of(context).passHint,
                            hintStyle: TextStyle(
                              color: AppColors.kb1b1b1,
                              fontSize: 14,
                            ),
                            contentPadding: EdgeInsets.only(left: 16, top: 5, bottom: 5,),
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
                                  store.obscurePasswordText = !store.obscurePasswordText;
                                },
                                child: passwordEye(store.obscurePasswordText),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30,),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 44,
                    child: TapDebouncer(
                      onTap: () async {
                        store.signInFailed = false;
                        store.autovalidateMode = AutovalidateMode.onUserInteraction;
                        final userEmail = emailController.text;
                        final userPassword = passwordController.text;

                        if (formKey.currentState?.validate() ?? false) {
                          final tokenProvider = getIt<NotificationsTokenProvider>();
                          if (tokenProvider.token.isEmpty) {
                            try {
                              final token = await FCMTokenService.instance.getToken();
                              tokenProvider.token = token!;
                            } catch (e) {
                              debugPrint('获取token失败: $e.toString()');
                            }
                          }
                          debugPrint('设备token:${tokenProvider.token}');

                          var apiClient = store.userType == 'customer' ? widget.services.api.apiClientSub : widget.services.api.apiClientMain;
                          try {
                            await EasyLoading.show(
                              status: S.of(context).signingIn,
                              maskType: EasyLoadingMaskType.black,
                            );

                            var loginResponse = await apiClient.authPostLogin(
                              device_id: widget.services.api.userProvider.deviceId.deviceId,
                              device_push_token: tokenProvider.token,
                              device_type: widget.services.api.userProvider.deviceId.deviceType,
                              email: userEmail,
                              password: userPassword,
                            );

                            if (ApiSuccessParser.isSuccessfulWithPayload(loginResponse)) {
                              widget.services.api.userProvider.onLogIn(loginResponse.body!.payload!);

                              // 登录接口在响应顶层返回 open_position_tracking（生成的
                              // User 模型没有该字段，从原始 JSON 里取）：写入缓存后
                              // 立即恢复定位上传服务，不必等首页的 position/index 查询。
                              // restoreIfEnabled 内部会做客户角色检查并写入上传凭据。
                              try {
                                final rawPayload = jsonDecode(loginResponse.bodyString)['payload'];
                                final trackingOpened =
                                    rawPayload?['open_position_tracking'] == true;
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('open_position_tracking', trackingOpened);
                                if (trackingOpened) {
                                  unawaited(LocationUploadSerhvice.restoreIfEnabled());
                                }
                              } catch (e) {
                                // 解析失败不影响登录流程；首页的后端同步会兜底启动服务。
                                debugPrint('解析登录追踪开关失败: $e');
                              }

                              final nextScreen = getHomeFromUser(loginResponse.body!.payload!);
                              await EasyLoading.dismiss();
                              await Navigator.pushAndRemoveUntil(context,
                                MaterialPageRoute<void>(
                                  settings: RouteSettings(name: '/'),
                                  builder: (context) => nextScreen,
                                ),
                                (route) => false,
                              );
                            } else {
                              await EasyLoading.dismiss();

                              store.signInFailed = true;
                              var message = ApiErrorParser.message(loginResponse.error);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message ?? S.of(context).loginFailed,),),
                              );
                            }
                          } catch (e) {
                            print('登陆报错了吗');
                            print(e);
                            await EasyLoading.dismiss();
                            store.signInFailed = true;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(S.of(context).loginFailed,),),
                            );
                          }
                        }
                      },
                      builder: (context, onTap) => TextButton(
                        onPressed: onTap,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.k0cbcc5,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: Text(S.of(context).signIn),
                      )
                    ),
                  ),
                ),
                SizedBox(height: 25,),
                InkWell(
                  onTap: () {
                    var params = ForgotPasswordParams(
                      userType: widget.services.store.userType,
                    );
                    Navigator.push(context, MaterialPageRoute<void>(
                      builder: (context) => getIt<ForgotPassword>(param1: params),
                    ),);
                  },
                  child: Text(
                    S.of(context).forgotPasswordQuestion,
                    style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(height: 45,),
                Text(
                  S.of(context).dontHaveAccount,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 54,),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 44,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                          side: BorderSide(
                            color: AppColors.k30bee6,
                          ),
                        ),
                        backgroundColor: AppColors.kffffff,
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute<void>(
                          builder: (context) => getIt<SignUp>(),
                        ),);
                      },
                      child: Text(
                        S.of(context).signUp,
                        style: GoogleFonts.rubik(
                          color: AppColors.k0cbcc5,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget passwordEye(bool obscurePasswordText) {
  if (obscurePasswordText) {
    return Image(
      image: AssetImage(
        'assets/images/ic_signin_hide_password_inactive.png',
      ),
    );
  }

  return Image(
    image: AssetImage(
      'assets/images/ic_signin_hide_password_active.png',
    ),
  );
}
