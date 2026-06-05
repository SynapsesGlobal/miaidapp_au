import 'package:country_code_picker/country_code_picker.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/doctor_interpreter/edit_user_doctor_translator_profile_store.dart';
import 'package:miaid/store/user/user_profile_screen/user_profile_screen_store.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class EditUserDoctorTranslatorProfileParams {
  const EditUserDoctorTranslatorProfileParams(this.key);

  final Key key;
}

@injectable
class EditUserDoctorTranslatorProfileServices {
  EditUserDoctorTranslatorProfileServices(this.api, this.store, this.user);

  final ApiProvider api;
  final EditUserDoctorTranslatorProfileStore store;
  final UserProvider user;
}

@injectable
class EditUserDoctorTranslatorProfile extends StatefulWidget {
  EditUserDoctorTranslatorProfile({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final EditUserDoctorTranslatorProfileParams? params;
  final EditUserDoctorTranslatorProfileServices services;

  @override
  _EditUserDoctorTranslatorProfileState createState() =>
      _EditUserDoctorTranslatorProfileState();
}

class _EditUserDoctorTranslatorProfileState
    extends State<EditUserDoctorTranslatorProfile> {
  final accountFirstNameController = TextEditingController();
  final accountLastNameController = TextEditingController();
  final accountEmailController = TextEditingController();
  final accountPhoneController = TextEditingController();

  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final countryController = TextEditingController();
  final languageController = TextEditingController();
  final genderController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    widget.services.store.fetchOnInit();
    WidgetsBinding.instance?.addPostFrameCallback((_) => refreshScreenState());
  }

  void refreshScreenState() {
    final user = widget.services.user.user;

    accountFirstNameController.text = user?.firstName ?? '';
    accountLastNameController.text = user?.lastName ?? '';
    accountEmailController.text = user?.email ?? '';
    accountPhoneController.text = extractPhoneWithoutCountryCode(user?.phone);

    if (widget.services.user.isDoctor) {
      addressController.text = user?.doctor?.address ?? '';
      cityController.text = user?.doctor?.city ?? '';
      countryController.text = user?.doctor?.doctorCountry?.name ?? '';
      final languages = user?.doctor?.doctorLanguages ?? [];
      if (languages.isNotEmpty) {
        languageController.text = languages.first.language!;
      }
      genderController.text = user!.doctor!.gender?.name ?? '';
    } else if (widget.services.user.isTranslator) {
      addressController.text = user?.translator?.address ?? '';
      cityController.text = user?.translator?.city ?? '';
      countryController.text = user?.translator?.translatorCountry?.name ?? '';
      final languages = user?.translator?.translatorLanguages ?? [];
      if (languages.isNotEmpty) {
        languageController.text = languages.first.language!;
      }
      genderController.text = user!.translator!.gender?.name ?? '';
    } else {
      throw Exception('Invalid user type for profile page');
    }
  }

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
          S.of(context).editProfile,
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
        child: Observer(
          builder: (context) => Form(
            key: formKey,
            child: Column(
              children: [
                accountDetails(),
                generalDetails(),
                Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 30, bottom: 44),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 44,
                    child: TapDebouncer(
                      onTap: () async {
                        if (formKey.currentState!.validate()) {
                          await EasyLoading.show(
                            status: S.of(context).loading,
                            maskType: EasyLoadingMaskType.black,
                          );

                          var EditUserDoctorTranslatorProfileResponse =
                              await widget.services.api.apiClient
                                  .profilePutUpdateDoctorOrTranslatorProfile(
                            first_name: accountFirstNameController.text,
                            last_name: accountLastNameController.text,
                            email: accountEmailController.text,
                            phone: store.userPhoneCountry.dialCode! +
                                '-' +
                                accountPhoneController.text,
                            address: addressController.text,
                            city: cityController.text,
                            gender_id: store.selectedGender!.id,
                            country_id: store.selectedCountry?.id,
                            language_id: store.selectedLanguage?.id,
                          );

                          if (ApiSuccessParser.isSuccessfulWithPayload(
                              EditUserDoctorTranslatorProfileResponse)) {
                            await store.refreshUser();
                            await EasyLoading.dismiss();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.k0cbcc5,
                                content: Text(
                                  S.of(context).profileUpdateSuccess,
                                ),
                              ),
                            );

                            Navigator.pop(context);
                          } else {
                            await EasyLoading.dismiss();

                            final message = ApiErrorParser.message(
                                EditUserDoctorTranslatorProfileResponse.error);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.k0cbcc5,
                                content: Text(
                                  S.of(context).profileUpdateError(
                                      EditUserDoctorTranslatorProfileResponse
                                          .statusCode,
                                      message ?? ''),
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
                          S.of(context).saveChanges,
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
        ),
      ),
    );
  }

  Widget accountDetails() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    S.of(context).accountDetails,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 19,
                ),
                Text(
                  S.of(context).fname + " *",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: AppColors.kb1b1b1,
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
                      return S.of(context).signupEmptyFirstName;
                    } else {
                      return null;
                    }
                  },
                  onChanged: (value) {
                    // Nop
                  },
                  controller: accountFirstNameController,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
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
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 25,
          ),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).lName,
                  textAlign: TextAlign.left,
                  style: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                  height: 8,
                ),
                TextFormField(
                  onChanged: (value) {
                    // Nop
                  },
                  controller: accountLastNameController,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
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
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 25,
          ),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).email + " *",
                  textAlign: TextAlign.left,
                  style: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
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
                  controller: accountEmailController,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
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
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 25,
          ),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).phone,
                  textAlign: TextAlign.left,
                  style: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                  height: 8,
                ),
                TextFormField(
                  // validator: (value) {
                  //   if (value.trim().isEmpty) {
                  //     return 'please Enter an Email';
                  //   } else {
                  //     return null;
                  //   }
                  // },
                  keyboardType: TextInputType.phone,
                  controller: accountPhoneController,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.only(
                      left: 0,
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
                    prefixIconConstraints: BoxConstraints(
                      maxWidth: 120,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: CountryCodePicker(
                        showDropDownButton: true,
                        alignLeft: false,
                        textStyle: GoogleFonts.rubik(
                          color: AppColors.kb1b1b1,
                          fontSize: 14,
                        ),
                        initialSelection:
                            widget.services.store.userPhoneCountry.dialCode,
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
                        onChanged: (value) {
                          widget.services.store.userPhoneCountry = value;
                        },
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

  Widget generalDetails() {
    final store = widget.services.store;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    S.of(context).generalDetail,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 19,
                ),
                Text(
                  S.of(context).address + " *",
                  textAlign: TextAlign.left,
                  style: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
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
                      return S.of(context).emptyAddress;
                    } else {
                      return null;
                    }
                  },
                  onChanged: (value) {
                    // Nop
                  },
                  controller: addressController,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
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
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  S.of(context).city + " *",
                  textAlign: TextAlign.left,
                  style: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
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
                      return S.of(context).emptyCity;
                    } else {
                      return null;
                    }
                  },
                  onChanged: (value) {
                    // Nop
                  },
                  controller: cityController,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
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
                  ),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  S.of(context).country + " *",
                  textAlign: TextAlign.left,
                  style: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                  height: 8,
                ),
                DropdownButtonFormField<Country>(
                  value: store.selectedCountry,
                  onChanged: (Country? newValue) {
                    store.selectedCountry = newValue;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null) {
                      return S.of(context).emptyCountry;
                    } else {
                      return null;
                    }
                  },
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
                  isExpanded: true,
                  isDense: true,
                  icon: Image.asset(
                      'assets/images/ic_pharmacy_location_expand.png'),
                  iconSize: 24,
                  elevation: 16,
                  style: GoogleFonts.rubik(color: AppColors.k5e5e5e),
                  items: store.countries
                      .map<DropdownMenuItem<Country>>((Country value) {
                    return DropdownMenuItem<Country>(
                      value: value,
                      child: Text(
                        value.name ?? S.of(context).selectCountry,
                        style: GoogleFonts.rubik(
                          color: AppColors.k5e5e5e,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 25,
          ),
          Text(
            S.of(context).preLanguage + " *",
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: AppColors.kb1b1b1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          DropdownButtonFormField<Language>(
            value: store.selectedLanguage,
            onChanged: (Language? newValue) {
              store.selectedLanguage = newValue;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null) {
                return S.of(context).emptyLanguage;
              } else {
                return null;
              }
            },
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
            isExpanded: true,
            isDense: true,
            icon: Image.asset('assets/images/ic_pharmacy_location_expand.png'),
            iconSize: 24,
            elevation: 16,
            style: GoogleFonts.rubik(color: AppColors.k5e5e5e),
            items: store.languages
                .map<DropdownMenuItem<Language>>((Language value) {
              return DropdownMenuItem<Language>(
                value: value,
                child: Text(
                  value.language ?? S.of(context).selectALanguage,
                  style: GoogleFonts.rubik(
                    color: AppColors.k5e5e5e,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(
            height: 25,
          ),
          Text(
            S.of(context).gender + " *",
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: AppColors.kb1b1b1,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(
            height: 8,
          ),
          DropdownButtonFormField<Gender>(
            value: store.selectedGender,
            onChanged: (Gender? newValue) {
              store.selectedGender = newValue;
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
            items: store.genders.map<DropdownMenuItem<Gender>>((Gender value) {
              return DropdownMenuItem<Gender>(
                value: value,
                child: Text(
                  value.name == 'Female'
                      ? S.of(context).female
                      : value.name == 'Male'
                          ? S.of(context).male
                          : S.of(context).selectGender,
                  style: GoogleFonts.rubik(
                    color: AppColors.k5e5e5e,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(
            height: 25,
          ),
        ],
      ),
    );
  }
}
