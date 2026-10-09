import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/social_account_service.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';

/// 为没有密码的用户（通过 Apple 登录创建）设置密码。
///
/// 与修改密码页的区别：不需要输入当前密码，调用的是 /password/set。
/// 设置成功后以 `true` 返回上一页，个人页据此刷新"登录方式"。
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({Key? key, required this.service}) : super(key: key);

  final SocialAccountService service;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.black,
    );
    try {
      await widget.service.setPassword(
        passwordController.text,
        confirmPasswordController.text,
      );
      await EasyLoading.dismiss();
      if (!mounted) return;
      await _showSuccessDialog();
      if (mounted) Navigator.of(context).pop(true);
    } on SocialAccountException catch (e) {
      await EasyLoading.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.k0cbcc5,
          content: Text(
            e.message.isNotEmpty
                ? e.message
                : S.of(context).unableToChangePassword,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).setPassword,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () => Navigator.pop(context),
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _formCard(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).setPasswordHint,
                      style: GoogleFonts.rubik(
                        color: AppColors.k8f8e94,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label(S.of(context).password),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return S.of(context).entPass;
                        } else if (value.length < 8) {
                          return S.of(context).passLength;
                        }
                        return null;
                      },
                      decoration: _decoration(
                        hint: S.of(context).passHint,
                        obscured: _obscurePassword,
                        onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label(S.of(context).confirmPass),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return S.of(context).entConfrmPass;
                        } else if (value != passwordController.text) {
                          return S.of(context).passNotMatch;
                        }
                        return null;
                      },
                      decoration: _decoration(
                        hint: S.of(context).rePass,
                        obscured: _obscureConfirmPassword,
                        onToggle: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _submitButton(),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.rubik(
        color: AppColors.k010101,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // 与修改密码页一致的输入框样式
  InputDecoration _decoration({
    required String hint,
    required bool obscured,
    required VoidCallback onToggle,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderSide: BorderSide(color: color),
          borderRadius: BorderRadius.circular(10),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.kb1b1b1, fontSize: 14),
      contentPadding: const EdgeInsets.only(left: 16, top: 5, bottom: 5),
      focusedBorder: border(AppColors.k010101),
      enabledBorder: border(AppColors.kb1b1b1),
      errorBorder: border(AppColors.kfa0020),
      focusedErrorBorder: border(AppColors.kfa0020),
      suffixIcon: InkWell(
        onTap: onToggle,
        child: passwordEye(obscured),
      ),
    );
  }

  Widget _submitButton() {
    return Container(
      width: double.infinity,
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
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
          ),
        ),
        onPressed: _submit,
        child: Text(
          S.of(context).savePass,
          style: GoogleFonts.rubik(
            color: AppColors.kffffff,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        title: Text(
          S.of(context).setPassword,
          textAlign: TextAlign.center,
          style: GoogleFonts.rubik(
            fontWeight: FontWeight.w500,
            fontSize: 17,
            color: AppColors.k010101,
          ),
        ),
        content: Text(
          S.of(context).setPasswordSuccess,
          textAlign: TextAlign.center,
          style: GoogleFonts.rubik(fontSize: 13, color: AppColors.k010101),
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  S.of(context).okay,
                  style:
                      GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
