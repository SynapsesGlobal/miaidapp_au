import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart' as pick;
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/doctor_interpreter/user_doctor_translator_profile_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/password/change_password.dart';

import 'edit_user_doctor_translator_profile.dart';

class UserDoctorTranslatorProfileScreenParams {
  const UserDoctorTranslatorProfileScreenParams(this.key);

  final Key key;
}

@injectable
class UserDoctorTranslatorProfileScreenServices {
  UserDoctorTranslatorProfileScreenServices(this.api, this.store, this.user);

  final ApiProvider api;
  final UserDoctorTranslatorProfileScreenStore store;
  final UserProvider user;
}

@injectable
class UserDoctorTranslatorProfileScreen extends StatefulWidget {
  UserDoctorTranslatorProfileScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final UserDoctorTranslatorProfileScreenParams? params;
  final UserDoctorTranslatorProfileScreenServices services;

  @override
  _UserDoctorTranslatorProfileScreenState createState() =>
      _UserDoctorTranslatorProfileScreenState();
}

class _UserDoctorTranslatorProfileScreenState
    extends State<UserDoctorTranslatorProfileScreen> {
  final languageController = TextEditingController();
  final genderController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) => refreshScreenState());
  }

  void refreshScreenState() {
    final user = widget.services.user.user!;

    if (widget.services.user.isDoctor) {
      addressController.text = user.doctor!.address ?? '';
      cityController.text = user.doctor!.city ?? '';
      countryController.text = user.doctor!.doctorCountry?.name ?? '';
      languageController.text = user.doctor!.doctorLanguages!.first.language!;
      genderController.text = user.doctor!.gender!.name!;
    } else if (widget.services.user.isTranslator) {
      addressController.text = user.translator!.address ?? '';
      cityController.text = user.translator!.city ?? '';
      countryController.text = user.translator!.translatorCountry?.name ?? '';
      languageController.text =
          user.translator!.translatorLanguages!.first.language!;
      genderController.text = user.translator!.gender!.name!;
    } else {
      throw Exception('Invalid user type for profile page');
    }

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
                      builder: (context) =>
                          getIt<EditUserDoctorTranslatorProfile>(),
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
                bottom: 54,
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
                              S.of(context).address,
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
                            controller: addressController,
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
                              S.of(context).city,
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
                            controller: cityController,
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
                              S.of(context).country,
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
                            controller: countryController,
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
            ],
          ),
        ),
      ],
    );
  }
}
