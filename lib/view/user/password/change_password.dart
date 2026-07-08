import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/user/user_profile_screen/change_password/change_password_store.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';

class ChangePasswordParams {
  const ChangePasswordParams(this.key);

  final Key key;
}

@injectable
class ChangePasswordServices {
  ChangePasswordServices(this.store, this.api);

  final ChangePasswordStore store;
  final ApiProvider api;
}

@injectable
class ChangePassword extends StatefulWidget {
  ChangePassword({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final ChangePasswordParams? params;
  final ChangePasswordServices services;

  @override
  _ChangePasswordState createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final currentPasswordController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).changePass,
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
        padding: const EdgeInsets.all(16),
        child: Container(
          child: Observer(
            builder: (context) => Column(
              children: [
                _formCard(
                  child: Form(
                  key: formKey,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).currPass,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.rubik(
                            color:
                                currentPasswordController.text.trim().isNotEmpty
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
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return S.of(context).entCurrPass;
                            } else {
                              return null;
                            }
                          },
                          controller: currentPasswordController,
                          obscureText: store.obscureCurrentPasswordText,
                          decoration: InputDecoration(
                            hintText: '********',
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
                                  store.obscureCurrentPasswordText =
                                      !store.obscureCurrentPasswordText;
                                },
                                child: passwordEye(
                                    store.obscureCurrentPasswordText),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Text(
                          S.of(context).password,
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
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: store.obscureConfirmPasswordText,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      ],
                    ),
                  ),
                ),
                ),
                SizedBox(
                  height: 24,
                ),
                Container(
                    width: MediaQuery.of(context).size.width,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [const Color(0xFF12CCD6), AppColors.k0cbcc5],
                      ),
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.k0cbcc5.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton(
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.transparent),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          await EasyLoading.show(
                            status: S.of(context).loading,
                            maskType: EasyLoadingMaskType.black,
                          );

                          var changePasswordResponse = await widget
                              .services.api.apiClient
                              .authPostUpdatePassword(
                            current_password: currentPasswordController.text,
                            password: passwordController.text,
                            password_confirmation:
                                confirmPasswordController.text,
                          );

                          await EasyLoading.dismiss();

                          if (ApiSuccessParser.isSuccessfulWithPayload(
                              changePasswordResponse)) {
                            formKey.currentState?.reset();
                            showAlertDialog(context);
                          } else if (changePasswordResponse.statusCode == 422) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.k0cbcc5,
                                content: Text(
                                  S.of(context).currentPasswordIncorrect,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.k0cbcc5,
                                content: Text(
                                  S.of(context).unableToChangePassword,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 白色圆角分区卡
  Widget _formCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.k010101.withOpacity(0.04),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
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
        S.of(context).passwordChangeMessageLabel,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontWeight: FontWeight.w500,
          fontSize: 17,
          color: AppColors.k010101,
        ),
      ),
      content: Text(
        S.of(context).passwordChangeMessage,
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
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
