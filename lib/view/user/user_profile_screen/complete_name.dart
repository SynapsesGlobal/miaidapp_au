import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/services/social_account_service.dart';

/// 补填姓名页，从首页问候语的"设置姓名"进入。
///
/// 通过 Apple / Google 创建的账号可能没有姓名（Apple 只在首次授权时返回）。
/// 新用户在补全资料页（SignUp2）里一并填写；已补全资料但没有姓名的老用户走这里。
/// 保存走 `/profile/name`，只改姓名，成功后以 `true` 回到上一页。
class CompleteNameScreen extends StatefulWidget {
  const CompleteNameScreen({Key? key, required this.service})
      : super(key: key);

  final SocialAccountService service;

  @override
  State<CompleteNameScreen> createState() => _CompleteNameScreenState();
}

class _CompleteNameScreenState extends State<CompleteNameScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = widget.service.api.userProvider.user;
    firstNameController.text = user?.firstName ?? '';
    lastNameController.text = user?.lastName ?? '';
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.black,
    );
    try {
      await widget.service.updateName(
        firstName: firstName,
        lastName: lastName,
      );
    } on SocialAccountException catch (e) {
      await EasyLoading.dismiss();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.k0cbcc5,
          content: Text(
            e.message.isNotEmpty ? e.message : S.of(context).somethingWentWrong,
          ),
        ),
      );
      return;
    }

    // 本地用户信息只改姓名，保留令牌和其它资料；首页问候语通过 UserInfoStore 跟着更新
    final userProvider = widget.service.api.userProvider;
    final updatedUser = userProvider.user?.copyWith(
      firstName: firstName,
      lastName: lastName,
    );
    if (updatedUser != null) {
      userProvider.onUserUpdated(updatedUser);
    }

    await EasyLoading.dismiss();
    if (!mounted) return;
    Navigator.of(context).pop(true);
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
          S.of(context).completeNameTitle,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
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
                      S.of(context).completeNameHint,
                      style: GoogleFonts.rubik(
                        color: AppColors.k8f8e94,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _label(S.of(context).fname),
                    const SizedBox(height: 8),
                    _nameField(
                      controller: firstNameController,
                      emptyMessage: S.of(context).signupEmptyFirstName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    _label(S.of(context).lName),
                    const SizedBox(height: 8),
                    _nameField(
                      controller: lastNameController,
                      emptyMessage: S.of(context).signupEmptyLastName,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
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

  // 与设置密码页一致的输入框样式；长度上限与后端校验一致
  Widget _nameField({
    required TextEditingController controller,
    required String emptyMessage,
    required TextInputAction textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderSide: BorderSide(color: color),
          borderRadius: BorderRadius.circular(10),
        );
    return TextFormField(
      controller: controller,
      maxLength: 100,
      textCapitalization: TextCapitalization.words,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? emptyMessage : null,
      style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14),
      decoration: InputDecoration(
        counterText: '',
        contentPadding: const EdgeInsets.only(left: 16, top: 5, bottom: 5),
        focusedBorder: border(AppColors.k010101),
        enabledBorder: border(AppColors.kb1b1b1),
        errorBorder: border(AppColors.kfa0020),
        focusedErrorBorder: border(AppColors.kfa0020),
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
          S.of(context).saveChanges,
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
}
