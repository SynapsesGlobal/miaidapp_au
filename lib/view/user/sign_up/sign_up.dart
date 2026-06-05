import 'package:country_code_picker/country_code_picker.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/custom_segmented_control.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/notifications/notifications_token_provider.dart';
import 'package:miaid/store/user/sign_up/sign_up_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/drawer/privacy_and_policy.dart';
import 'package:miaid/view/drawer/terms_and_cond.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/view/user/sign_up/otp_screen.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';

class SignUpParams {
  const SignUpParams(this.key);

  final Key key;
}

@injectable
class SignUpServices {
  SignUpServices(this.api, this.store, this.user);

  final ApiProvider api;
  final SignUpStore store;
  final UserProvider user;
}

@injectable
class SignUp extends StatefulWidget {
  SignUp({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final SignUpParams? params;
  final SignUpServices services;

  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final invitationCodeController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return Scaffold(
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
            ),
            child: Container(
              alignment: Alignment.centerRight,
              height: 36,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Text(
                  S.of(context).signIn,
                  style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Observer(
          builder: (context) => Column(
            children: [
              Container(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 5,
                    right: 5,
                    top: 10,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: MiAidCupertinoSegmentedControl<bool>(
                      selectedColor: AppColors.k0cbcc5,
                      unselectedColor: Colors.white,
                      borderColor: AppColors.k0cbcc5,
                      children: {
                        true: Container(
                          decoration: BoxDecoration(
                            color: store.showIndividualUserTab
                                ? AppColors.k0cbcc5
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(10),
                              topLeft: Radius.circular(10),
                            ),
                            border: Border.all(
                              color: AppColors.k0cbcc5,
                            ),
                          ),
                          width: MediaQuery.of(context).size.width,
                          padding: EdgeInsets.all(8),
                          child: Text(
                            S.of(context).individual,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rubik(
                                fontSize: 17,
                                color: store.showIndividualUserTab
                                    ? AppColors.kffffff
                                    : AppColors.k0cbcc5),
                          ),
                        ),
                        false: Container(
                          decoration: BoxDecoration(
                            color: !store.showIndividualUserTab
                                ? AppColors.k0cbcc5
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                            border: Border.all(
                              color: AppColors.k0cbcc5,
                            ),
                          ),
                          width: MediaQuery.of(context).size.width,
                          padding: EdgeInsets.all(8),
                          child: Text(
                            S.of(context).corporate,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rubik(
                                fontSize: 17,
                                color: !store.showIndividualUserTab
                                    ? AppColors.kffffff
                                    : AppColors.k0cbcc5),
                          ),
                        ),
                      },
                      onValueChanged: (value) {
                        store.showIndividualUserTab = value;
                      },
                      groupValue: store.showIndividualUserTab,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              store.showIndividualUserTab ? individualUser() : corporateUser(),
            ],
          ),
        ),
      ),
    );
  }

  Widget individualUser() {
    final store = widget.services.store;
    return Form(
      key: formKey,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).fname + ' *',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: firstNameController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    autovalidateMode: store.autovalidateMode,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return S.of(context).signupEmptyFirstName;
                      } else {
                        return null;
                      }
                    },
                    controller: firstNameController,
                    onChanged: (value) {
                      // Nop
                    },
                    decoration: InputDecoration(
                      hintText: 'John',
                      hintStyle: GoogleFonts.rubik(
                        color: AppColors.kb1b1b1,
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.only(
                        left: 16,
                        top: 5,
                        bottom: 5,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.yellow),
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).lName + ' *',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: lastNameController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    autovalidateMode: store.autovalidateMode,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return S.of(context).signupEmptyLastName;
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {
                      // Nop
                    },
                    controller: lastNameController,
                    decoration: InputDecoration(
                      hintText: 'Doe',
                      hintStyle: GoogleFonts.rubik(
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).email + ' *',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: emailController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    autovalidateMode: store.autovalidateMode,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return S.of(context).signupEmptyEmail;
                      } else if (!EmailValidator.validate(value.trim())) {
                        return S.of(context).entVEmain;
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {
                      // Nop
                    },
                    keyboardType: TextInputType.emailAddress,
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'yourname@example.com',
                      hintStyle: GoogleFonts.rubik(
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).phone + ' *',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: phoneController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    autovalidateMode: store.autovalidateMode,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return S.of(context).signupEmptyPhone;
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {
                      // Nop
                    },
                    keyboardType: TextInputType.phone,
                    controller: phoneController,
                    decoration: InputDecoration(
                      hintText: '1 23456 7890',
                      hintStyle: GoogleFonts.rubik(
                        color: AppColors.kb1b1b1,
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.only(
                        left: 0,
                        top: 5,
                        bottom: 5,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.kb1b1b1.withOpacity(0.5),
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                      prefixIconConstraints: BoxConstraints(
                        maxWidth: 120,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: CountryCodePicker(
                          headerText: S.of(context).country,
                          showDropDownButton: true,
                          alignLeft: false,
                          textStyle: GoogleFonts.rubik(
                            color: AppColors.kb1b1b1,
                            fontSize: 14,
                          ),
                          onChanged: (value) {
                            store.selectedCountry = value;
                          },
                          onInit: (value) {
                            store.selectedCountry = value;
                          },
                          initialSelection: 'AU',
                          favorite: ['AU'],
                          showCountryOnly: false,
                          closeIcon: Icon(
                            Icons.close,
                            color: AppColors.k0cbcc5,
                          ),
                          showOnlyCountryWhenClosed: false,
                          padding: EdgeInsets.zero,
                          builder: (country) {
                            return Row(
                              children: [
                                Image.asset(
                                  country!.flagUri!,
                                  package: 'country_code_picker',
                                  width: 32,
                                ),
                                SizedBox(
                                  width: 3.69,
                                ),
                                Text(
                                  country.dialCode!,
                                  style: GoogleFonts.rubik(
                                    color: AppColors.kb1b1b1,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(
                                  width: 6,
                                ),
                                Image.asset(
                                    'assets/images/ic_pharmacy_location_expand.png'),
                                SizedBox(
                                  width: 6,
                                ),
                                Container(
                                  height: 35,
                                  width: 1,
                                  color: AppColors.kb1b1b1.withOpacity(0.1),
                                )
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).password + ' *',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: passwordController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    autovalidateMode: store.autovalidateMode,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return S.of(context).entPass;
                      } else if (value.length < 8) {
                        return S.of(context).passLength;
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {
                      // Nop
                    },
                    controller: passwordController,
                    obscureText: store.obscurePasswordText,
                    decoration: InputDecoration(
                      hintText: S.of(context).passHint,
                      hintStyle: GoogleFonts.rubik(
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
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
                ],
              ),
            ),
            SizedBox(
              height: 30,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).confirmPass + ' *',
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: confirmPasswordController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    autovalidateMode: store.autovalidateMode,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return S.of(context).entConfrmPass;
                      } else if (passwordController.text !=
                          confirmPasswordController.text) {
                        return S.of(context).passNotMatch;
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {
                      // Nop
                    },
                    controller: confirmPasswordController,
                    obscureText: store.obscureConfirmPasswordText,
                    decoration: InputDecoration(
                      hintText: S.of(context).rePass,
                      hintStyle: GoogleFonts.rubik(
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                      suffixIcon: Padding(
                        padding: EdgeInsets.all(0),
                        child: InkWell(
                          onTap: () {
                            store.obscureConfirmPasswordText = !store.obscureConfirmPasswordText;
                          },
                          child: passwordEye(store.obscureConfirmPasswordText),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20,),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).invitation_code,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: invitationCodeController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    autovalidateMode: store.autovalidateMode,
                    controller: invitationCodeController,
                    obscureText: false,
                    decoration: InputDecoration(
                      hintText: S.of(context).invitation_code_hint,
                      hintStyle: GoogleFonts.rubik(
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 0, right: 0),
              child: RichText(
                textAlign: TextAlign.start,
                text: TextSpan(
                  style: GoogleFonts.rubik(
                    color: AppColors.k5e5e5e,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(text: S.of(context).bySubmit),
                    TextSpan(
                      text: '${S.of(context).tandc} ',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => getIt<TermsConditions>(),
                            ),
                          );
                        },
                      style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: S.of(context).and),
                    TextSpan(
                      text: ' ${S.of(context).privacy}',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => getIt<PrivacyPolicy>(),
                            ),
                          );
                        },
                      style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: S.of(context).bySubmit2)
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 22,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 44,
                child: TapDebouncer(
                  onTap: () async {
                    store.autovalidateMode = AutovalidateMode.onUserInteraction;
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        final timeZone = await FlutterNativeTimezone.getLocalTimezone();
                        final tokenProvider = getIt<NotificationsTokenProvider>();

                        await EasyLoading.show(
                          status: S.of(context).loading,
                          maskType: EasyLoadingMaskType.black,
                        );
                        var registerResponse = await widget.services.api.apiClient.authPostRegister(
                          device_id: widget.services.user.deviceId.deviceId,
                          device_push_token: tokenProvider.token,
                          device_type: widget.services.user.deviceId.deviceType,
                          first_name: firstNameController.text,
                          last_name: lastNameController.text,
                          email: emailController.text,
                          phone: store.selectedCountry!.dialCode! + '-' + phoneController.text,
                          password: passwordController.text,
                          password_confirmation: confirmPasswordController.text,
                          timezone: timeZone,
                          invitationCode: invitationCodeController.text
                        );

                        await EasyLoading.dismiss();

                        if (ApiSuccessParser.isSuccessfulWithPayload(registerResponse)) {
                          widget.services.api.userProvider.onLogIn(registerResponse.body!.payload!);
                          await Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => getIt<OtpScreen>(),
                            ),
                            (route) => false,
                          );
                        } else if (registerResponse.statusCode == 422) {
                          var message = invitationCodeController.text.isNotEmpty ? S.of(context).signupValidateError : S.of(context).signupExistingAccount;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.k0cbcc5,
                              content: Text(message),
                            ),
                          );
                        } else {
                          final message = ApiErrorParser.message(registerResponse.error) ?? '';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.k0cbcc5,
                              content: Text(
                                S.of(context).signupError(message),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        await EasyLoading.dismiss();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.k0cbcc5,
                            content: Text(
                              S.of(context).signUpFailed,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  builder: (context, onTap) => TextButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(AppColors.k0cbcc5),
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    onPressed: onTap,
                    child: Text(
                      S.of(context).signUp,
                      style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
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
      ),
    );
  }

  OutlineInputBorder get kErrorFocusedOutlineInputBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: AppColors.kff3b30,
    ),
  );

  OutlineInputBorder get kErrorOutlineInputBorder => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: AppColors.kff3b30,
      width: 0.5,
    ),
  );

  Widget corporateUser() {
    return Container(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 73.58,
            right: 72.57,
            top: 143,
          ),
          child: Image(
            image: AssetImage('assets/images/Img_signin_corporateuser.png'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 62,
            right: 61,
            top: 21,
          ),
          child: Text(
            S.of(context).corporateText,
            textAlign: TextAlign.justify,
            style: GoogleFonts.rubik(
              color: AppColors.k5e5e5e,
              fontSize: 17,
            ),
          ),
        ),
      ]),
    );
  }
}
