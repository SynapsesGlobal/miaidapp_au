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
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/user/user_profile_screen/user_profile_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/password/change_password.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) => refreshScreenState());
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
            const SizedBox(height: 16),
            _sectionCard(
              title: S.of(context).otherSettings,
              children: [
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
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
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
                Navigator.pop(context);
              },
              child: Text(
                S.of(context).cancel,
                style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Center(
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context, true);
              },
              child: Text(
                S.of(context).deleteAccount,
                style: GoogleFonts.rubik(
                  color: AppColors.kfa0020,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).deleteAccount,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
            color: AppColors.k010101, fontWeight: FontWeight.w700),
      ),
      content: Text(
        S.of(context).deleteAccountAlertMessage,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 13,
        ),
      ),
      actions: [okButton],
    );

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        }).then((value) async {
      if (value ?? false) {
        await deleteUser(context, widget.services.user);
      }
    });
  }
}
