import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart' as pick;
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/google_logo.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/social_account_service.dart';
import 'package:miaid/store/user/user_profile_screen/user_profile_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/password/change_password.dart';
import 'package:miaid/view/user/password/set_password.dart';
import 'package:miaid/view/user/user_profile_screen/edit_user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileScreenParams {
  const UserProfileScreenParams(this.key);

  final Key key;
}

@injectable
class UserProfileScreenServices {
  UserProfileScreenServices(this.api, this.store, this.user);

  final ApiProvider api;
  final UserProfileScreenStore store;
  final UserProvider user;
}

@injectable
class UserProfileScreen extends StatefulWidget {
  UserProfileScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final UserProfileScreenParams? params;
  final UserProfileScreenServices services;

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final dobController = TextEditingController();
  final languageController = TextEditingController();
  final genderController = TextEditingController();
  final doctorPreferenceController = TextEditingController();
  final travelAgencyNameController = TextEditingController();
  final medicareNumberController = TextEditingController();
  final nokFullNameController = TextEditingController();
  final nokEmailController = TextEditingController();
  final nokPhoneController = TextEditingController();
  final regularDoctorFullNameController = TextEditingController();
  final regularDoctorEmailController = TextEditingController();

  late final SocialAccountService _socialAccountService =
      SocialAccountService(widget.services.api);

  /// 登录方式概览（是否已设置密码、绑定的第三方账号）；加载失败保持 null，相关区块不显示
  SocialAccountSummary? _loginMethods;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) => refreshScreenState());
    _loadLoginMethods();
  }

  Future<void> _loadLoginMethods() async {
    try {
      final summary = await _socialAccountService.fetch();
      if (mounted) setState(() => _loginMethods = summary);
    } on SocialAccountException catch (e) {
      debugPrint('加载登录方式失败: ${e.message}');
    }
  }

  Future<void> _openSetPassword() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => SetPasswordScreen(service: _socialAccountService),
      ),
    );
    if (done == true) await _loadLoginMethods();
  }

  Future<void> _unlink(LinkedSocialAccount account) async {
    final confirmed = await _showConfirmDialog(
      title: S.of(context).unlink,
      message: S.of(context).unlinkProviderConfirm(account.label),
      confirmLabel: S.of(context).unlink,
    );
    if (confirmed != true) return;

    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.black,
    );
    try {
      final summary = await _socialAccountService.unlink(account.provider);
      await EasyLoading.dismiss();
      if (!mounted) return;
      setState(() => _loginMethods = summary);
      await HttpExceptionNotifyUser.showInfo(S.of(context).unlinkSuccess);
    } on SocialAccountException catch (e) {
      await EasyLoading.dismiss();
      if (!mounted) return;
      // 后端会说明原因，如"请先设置密码"
      await HttpExceptionNotifyUser.showError(
        e.message.isNotEmpty ? e.message : S.of(context).somethingWentWrong,
      );
    }
  }

  Future<void> refreshScreenState() async {
    final user = widget.services.user.user;

    var dob = DateTime.tryParse(user!.customer!.dob!);
    var sharedPreferences = await SharedPreferences.getInstance();
    var language = sharedPreferences.getString('languageCode') ?? 'zh';
    dobController.text = language == 'zh' || language == 'zh_Hant' ? DateFormat('yyyy年MM月d日').format(dob!) : DateFormat('d MMM yyyy').format(dob!);

    languageController.text = user.customer!.languages!.map((e) => e.language!).join(', ');
    genderController.text = user.customer!.gender!.name! == 'Female' ? S.of(context).female : user.customer!.gender!.name! == 'Male'
            ? S.of(context).male
            : S.of(context).selectGender;
    doctorPreferenceController.text = getDoctorPreference(context, user);
    travelAgencyNameController.text = user.customer?.travelAgencyName ?? '';
    medicareNumberController.text = user.customer?.medicareNumber ?? '';
    nokFullNameController.text = user.customer?.nextOfKinName ?? '';
    nokEmailController.text = user.customer?.nextOfKinEmail ?? '';
    nokPhoneController.text = user.customer?.nextOfKinMobile ?? '';

    regularDoctorFullNameController.text = user.customer?.regularDoctorName ?? '';
    regularDoctorEmailController.text = user.customer?.regularDoctorEmail ?? '';

    setState(() {});
  }

  void askImageSource() {
    final action = CupertinoActionSheet(
      message: Text(
        S.of(context).pickPictureFrom,
        style: TextStyle(
          fontSize: 13.0,
          color: AppColors.k8f8e94,
        ),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () async {
            await pickProfilePicture(pick.ImageSource.camera);
          },
          child: Text(
            S.of(context).camera,
            style: TextStyle(
              color: AppColors.k0cbcc5,
              fontSize: 24,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () async {
            await pickProfilePicture(pick.ImageSource.gallery);
          },
          child: Text(
            S.of(context).gallery,
            style: TextStyle(
              color: AppColors.k0cbcc5,
              fontSize: 24,
            ),
          ),
        )
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text(
          S.of(context).cancel,
          style: TextStyle(
            color: AppColors.k0cbcc5,
            fontSize: 20,
          ),
        ),
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> pickProfilePicture(pick.ImageSource source) async {
    Navigator.pop(context);
    final picker = pick.ImagePicker();

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      try {
        await EasyLoading.show(
          status: S.of(context).uploading,
          maskType: EasyLoadingMaskType.clear,
        );
        await widget.services.store.updateProfilePicture(pickedFile);
        await HttpExceptionNotifyUser.showInfo(S.of(context).uploadSuccess);

        refreshScreenState();
      } catch (e) {
        await HttpExceptionNotifyUser.showError(S.of(context).uploadFailed);
      } finally {
        await EasyLoading.dismiss();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      drawer: getDrawer(widget.services.store.user),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).myProfile,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 13),
            child: Container(
              alignment: Alignment.centerRight,
              height: 36,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => getIt<EditUserProfile>(),
                    ),
                  ).then((value) => refreshScreenState());
                },
                child: Text(
                  S.of(context).editProfile,
                  style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileHeaderCard(),
            const SizedBox(height: 16),
            _sectionCard(
              title: S.of(context).generalDetail,
              children: [
                _infoRow(S.of(context).dob, dobController.text),
                _infoRow(S.of(context).preLanguage, languageController.text),
                _infoRow(S.of(context).gender, genderController.text),
                _infoRow(
                    S.of(context).doctorPre, doctorPreferenceController.text),
                _infoRow(S.of(context).medicareNumber,
                    medicareNumberController.text),
                _infoRow(S.of(context).travelAgencyName,
                    travelAgencyNameController.text,
                    isLast: true),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: S.of(context).nextOfKin,
              children: [
                _infoRow(S.of(context).fullName, nokFullNameController.text),
                _infoRow(S.of(context).email, nokEmailController.text),
                _infoRow(S.of(context).phone, nokPhoneController.text,
                    isLast: true),
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              title: S.of(context).regularDoctor,
              children: [
                _infoRow(S.of(context).fullName,
                    regularDoctorFullNameController.text),
                _infoRow(S.of(context).email, regularDoctorEmailController.text,
                    isLast: true),
              ],
            ),
            if (_loginMethods != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                title: S.of(context).loginMethods,
                children: _loginMethodRows(_loginMethods!),
              ),
            ],
            const SizedBox(height: 16),
            _sectionCard(
              title: S.of(context).otherSettings,
              children: [
                // 通过 Apple 登录创建、尚未设置密码的用户显示"设置密码"
                if (_loginMethods?.hasPassword == false)
                  _actionTile(
                    icon: Icons.lock_outline,
                    label: S.of(context).setPassword,
                    color: AppColors.k0cbcc5,
                    onTap: _openSetPassword,
                  )
                else
                  _actionTile(
                    icon: Icons.lock_outline,
                    label: S.of(context).changePass,
                    color: AppColors.k0cbcc5,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute<void>(
                        builder: (context) => getIt<ChangePassword>(),
                      ),);
                    },
                  ),
                Divider(height: 1, color: Colors.grey.shade200),
                _actionTile(
                  icon: Icons.delete_outline,
                  label: S.of(context).deleteAccount,
                  color: AppColors.kfa0020,
                  onTap: () => showDeleteAlertDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 顶部个人信息卡：头像 + 姓名 + 联系方式
  Widget _profileHeaderCard() {
    final user = widget.services.user.user;
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
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.k0cbcc5, width: 2),
                  shape: BoxShape.circle,
                  image: profileDecorationImage(
                    context,
                    user!,
                    getIt<ApiSettings>(),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: askImageSource,
                  child: Image(
                    image: AssetImage(
                      'assets/images/ic_profile_uploadpicture.png',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.mail_outline,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        user.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rubik(
                          color: AppColors.k696969,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        user.phone ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rubik(
                          color: AppColors.k696969,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 白色圆角分区卡：主题色小竖条标题 + 内容行
  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.k0cbcc5,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  // 登录方式：邮箱密码一行（未设置密码时给"设置密码"入口）+ 已绑定的第三方账号各一行
  List<Widget> _loginMethodRows(SocialAccountSummary summary) {
    final accounts = summary.accounts;
    return [
      _loginMethodRow(
        leading: Icon(Icons.mail_outline, size: 20, color: AppColors.k010101),
        title: S.of(context).emailAndPassword,
        subtitle: widget.services.user.user?.email ?? '',
        trailing: summary.hasPassword
            ? _statusChip(S.of(context).passwordSetLabel)
            : _linkButton(S.of(context).setPassword, _openSetPassword),
        isLast: accounts.isEmpty,
      ),
      for (var i = 0; i < accounts.length; i++)
        _loginMethodRow(
          leading: _providerIcon(accounts[i].provider),
          title: accounts[i].label,
          subtitle: accounts[i].email ?? '',
          trailing: _linkButton(
            S.of(context).unlink,
            () => _unlink(accounts[i]),
            color: AppColors.kfa0020,
          ),
          isLast: i == accounts.length - 1,
        ),
    ];
  }

  Widget _providerIcon(String provider) {
    switch (provider) {
      case LinkedSocialAccount.providerGoogle:
        return const GoogleLogo(size: 20);
      case LinkedSocialAccount.providerApple:
      default:
        return Icon(Icons.apple, size: 20, color: AppColors.k010101);
    }
  }

  Widget _loginMethodRow({
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget trailing,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 20, child: Center(child: leading)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rubik(
                          color: AppColors.k8f8e94,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _statusChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.k0cbcc5.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.rubik(
          color: AppColors.k0cbcc5,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _linkButton(String text, VoidCallback onTap, {Color? color}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: GoogleFonts.rubik(
          color: color ?? AppColors.k0cbcc5,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 信息行：小号灰标签在上，值在下，行间细分隔线
  Widget _infoRow(String label, String value, {bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.rubik(
                  color: AppColors.k8f8e94,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  // 操作行：图标 + 文案 + 右箭头
  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.rubik(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.kb1b1b1),
          ],
        ),
      ),
    );
  }

  // showDeleteAlertDialog
  void showDeleteAlertDialog(BuildContext context) {
    _showConfirmDialog(
      title: S.of(context).deleteAccount,
      message: S.of(context).deleteAccountAlertMessage,
      confirmLabel: S.of(context).deleteAccount,
    ).then((confirmed) async {
      if (confirmed ?? false) {
        await deleteUser(context, widget.services.user);
      }
    });
  }

  /// 危险操作确认弹框（删除账户、解除绑定共用）：
  /// 标题居中加粗，说明文字居中，下方一个占满宽度的品牌色"取消"按钮，再下面是红色文字的确认操作。
  /// 确认返回 true，取消或点击遮罩返回 false / null。
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.rubik(
              color: AppColors.k010101, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.rubik(fontSize: 13),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(dialogContext).size.width,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.k0cbcc5.withOpacity(0.2),
                        blurRadius: 10.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      S.of(context).cancel,
                      style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(
                      confirmLabel,
                      style: GoogleFonts.rubik(
                        color: AppColors.kfa0020,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
