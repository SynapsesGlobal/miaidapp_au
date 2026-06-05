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
    dobController.text = language == 'zh' || language == 'zh_hans' ? DateFormat('yyyy年MM月d日').format(dob!) : DateFormat('d MMM yyyy').format(dob!);

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
      backgroundColor: Colors.white,
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 20),
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white),
                    child: Stack(
                      children: [
                        Container(
                          height: 84,
                          width: 84,
                          margin: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.k0cbcc5),
                            shape: BoxShape.circle,
                            image: profileDecorationImage(
                                context,
                                widget.services.user.user!,
                                getIt<ApiSettings>()),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 30,
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
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15, top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.services.user.user?.fullName ?? '',
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          widget.services.user.user?.email ?? '',
                          style: GoogleFonts.rubik(
                            color: AppColors.k696969,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        Text(
                          widget.services.user.user?.phone ?? '',
                          style: GoogleFonts.rubik(
                            color: AppColors.k696969,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
            SizedBox(
              height: 36.1,
            ),
            generalDetails(),
            nextOfKin(),
            regularDoctor(),
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 16),
              child: Text(
                S.of(context).otherSettings,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 15,
                bottom: 15,
              ),
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 44,
                child: TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColors.kffffff),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    side: MaterialStateProperty.all(
                      BorderSide(color: AppColors.k0cbcc5),
                    ),
                    overlayColor: MaterialStateProperty.all(
                        AppColors.k0cbcc5.withOpacity(0.2)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => getIt<ChangePassword>(),
                      ),
                    );
                  },
                  child: Text(
                    S.of(context).changePass,
                    style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 15,
                bottom: 80,
              ),
              child: Container(
                height: 44,
                width: MediaQuery.of(context).size.width,
                child: TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColors.kffffff),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    side: MaterialStateProperty.all(
                      BorderSide(color: AppColors.kfa0020),
                    ),
                    overlayColor: MaterialStateProperty.all(
                        AppColors.kfa0020.withOpacity(0.2)),
                  ),
                  onPressed: () {
                    showDeleteAlertDialog(context);
                  },
                  child: Text(
                    S.of(context).deleteAccount,
                    style: GoogleFonts.rubik(
                      color: AppColors.kfa0020,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
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

  Widget generalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 20),
                child: Text(
                  S.of(context).generalDetail,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                height: 19,
              ),
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              S.of(context).dob,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.rubik(
                                color: AppColors.k696969,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextFormField(
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.only(left: 10),
                            ),
                            onChanged: (value) {
                              // Nop
                            },
                            enabled: false,
                            controller: dobController,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              S.of(context).preLanguage,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.rubik(
                                color: AppColors.k696969,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          TextFormField(
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.only(left: 10),
                            ),
                            enabled: false,
                            controller: languageController,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              S.of(context).gender,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.rubik(
                                color: AppColors.k696969,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          TextFormField(
                            onChanged: (value) {
                              // Nop
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.only(left: 10),
                            ),
                            enabled: false,
                            controller: genderController,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              S.of(context).doctorPre,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.rubik(
                                color: AppColors.k696969,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          TextFormField(
                            onChanged: (value) {
                              // Nop
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.only(left: 10),
                            ),
                            enabled: false,
                            controller: doctorPreferenceController,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              S.of(context).medicareNumber,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.rubik(
                                color: AppColors.k696969,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          TextFormField(
                            onChanged: (value) {
                              // Nop
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.only(left: 10),
                            ),
                            enabled: false,
                            controller: medicareNumberController,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              S.of(context).travelAgencyName,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.rubik(
                                color: AppColors.k696969,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 6,
                          ),
                          TextFormField(
                            onChanged: (value) {
                              // Nop
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.only(left: 10),
                            ),
                            enabled: false,
                            controller: travelAgencyNameController,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget nextOfKin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 20),
                child: Text(
                  S.of(context).nextOfKin,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                height: 19,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        S.of(context).fullName,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color: AppColors.k696969,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextFormField(
                      onChanged: (value) {
                        // Nop
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                      ),
                      enabled: false,
                      controller: nokFullNameController,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 10,
        ),
        Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        S.of(context).email,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color: AppColors.k696969,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextFormField(
                      onChanged: (value) {
                        // Nop
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                      ),
                      enabled: false,
                      controller: nokEmailController,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 10,
        ),
        Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        S.of(context).phone,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color: AppColors.k696969,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextFormField(
                      onChanged: (value) {
                        // Nop
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                      ),
                      enabled: false,
                      controller: nokPhoneController,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 10,
        ),
      ],
    );
  }

  Widget regularDoctor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 20),
                child: Text(
                  S.of(context).regularDoctor,
                  style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 17,
                      fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(
                height: 19,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        S.of(context).fullName,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color: AppColors.k696969,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextFormField(
                      onChanged: (value) {
                        // Nop
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                      ),
                      enabled: false,
                      controller: regularDoctorFullNameController,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 10,
        ),
        Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        S.of(context).email,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.rubik(
                          color: AppColors.k696969,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextFormField(
                      onChanged: (value) {
                        // Nop
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                      ),
                      enabled: false,
                      controller: regularDoctorEmailController,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
