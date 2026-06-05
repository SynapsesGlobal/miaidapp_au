import 'package:country_code_picker/country_code_picker.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/user/sign_up/sign_up_2_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class SignUp2Params {
  const SignUp2Params(this.key);

  final Key key;
}

@injectable
class SignUp2Services {
  SignUp2Services(this.api, this.user, this.store);

  final ApiProvider api;
  final UserProvider user;
  final SignUp2Store store;
}

@injectable
class SignUp2 extends StatefulWidget {
  SignUp2({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final SignUp2Params? params;
  final SignUp2Services services;

  @override
  _SignUp2State createState() => _SignUp2State();
}

class _SignUp2State extends State<SignUp2> {
  final dobController = TextEditingController();
  final languageController = TextEditingController();
  final genderController = TextEditingController();
  final doctorPreferenceController = TextEditingController();
  final travelAgencyNameController = TextEditingController();
  final medicareNumberController = TextEditingController();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final regularDoctorFullNameController = TextEditingController();
  final regularDoctorEmailController = TextEditingController();

  final formKey = GlobalKey<FormState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late bool language_validated = true;

  @override
  void initState() {
    widget.services.store.fetchOnInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).completeYourProfile,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
        actions: [
          TapDebouncer(
            onTap: () async => await logout(context, widget.services.user),
            builder: (context, onTap) => InkWell(
              onTap: onTap,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(S.of(context).logout, style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Observer(
          builder: (context) => Form(
            key: formKey,
            child: Column(
              children: [
                generalDetails(),
                nextOfKin(),
                regularDoctor(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 64, left: 20, right: 20, top: 40,),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: 44,
                    child: TextButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          String? mobile;
                          if (phoneController.text.trim().isNotEmpty) {
                            mobile = store.selectedCountry.dialCode! + '-' + phoneController.text;
                          }

                          if (store.selectedLanguages.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: AppColors.k0cbcc5,
                              content: Text(
                                S.of(context).selectAtLeastOneLanguage,
                              ),
                            ));
                            return;
                          }

                          await EasyLoading.show(
                            status: S.of(context).loading,
                            maskType: EasyLoadingMaskType.black,
                          );

                          var response = await widget.services.api.apiClient.profilePostCompleteProfile(
                            dob: DateFormat('y-MM-d').format(store.selectedDate!),
                            language_id: store.selectedLanguage!.id,
                            language_ids: store.selectedLanguages.map((e) => e.id!).toList(),
                            gender_id: store.selectedGender!.id,
                            doctor_preference: store.doctorPreference,
                            travel_agency_name: travelAgencyNameController.text,
                            medicare_number: medicareNumberController.text,
                            next_of_kin_name: fullNameController.text,
                            next_of_kin_email: emailController.text,
                            next_of_kin_mobile: mobile,
                            regular_doctor_email: regularDoctorEmailController.text,
                            regular_doctor_name: regularDoctorFullNameController.text,
                            customer_type_id: 1,
                          );

                          await EasyLoading.dismiss();

                          if (ApiSuccessParser.isSuccessfulWithPayload(response)) {
                            final user = await ApiSuccessParser.payloadOrThrowWithMessage(response);
                            widget.services.user.onUserUpdated(user);

                            await Navigator.pushAndRemoveUntil(
                              context,
                              // ignore: inference_failure_on_instance_creation
                              MaterialPageRoute(
                                settings: RouteSettings(name: "/"),
                                builder: (context) => getIt<HomeScreen>(),
                              ),
                              (route) => false,
                            );
                          } else {
                            final message = ApiErrorParser.message(response.error);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.k0cbcc5,
                                content: Text(
                                  'Unable to complete signup.\nPlease try again. ${response.statusCode} -$message',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(S.of(context).completeProfile, style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),),
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

  Widget generalDetails() {
    final store = widget.services.store;
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(S.of(context).generalDetail, style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),),
              ),
              SizedBox(height: 19,),
              Text(
                S.of(context).dob + ' *',
                textAlign: TextAlign.left,
                style: GoogleFonts.rubik(
                  color: dobController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8,),
              TextFormField(
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return S.of(context).emptyDateOfBirth;
                  } else {
                    return null;
                  }
                },
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    builder: (context) => cupertinoDatePicker(context),
                  );
                  if (store.selectedDate != null) {
                    var sharedPreferences = await SharedPreferences.getInstance();
                    var language = sharedPreferences.getString('languageCode') ?? 'zh';
                    final formattedDate = language == 'zh' ? DateFormat('yyyy年MM月d日').format(store.selectedDate!) : DateFormat('d MMM yyyy').format(store.selectedDate!);
                    dobController.text = formattedDate;
                  }
                },
                onChanged: (value) {
                  dobController.text = value;
                },
                readOnly: true,
                controller: dobController,
                decoration: InputDecoration(
                  hintText: 'Ex: 01 Jan 1990',
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
                      child: navBarIcon(iconAssetName: 'ic_nb_callhistory_date.png'),
                    ),
                  ),
                ),
              ),
            ],
          ),),
          SizedBox(height: 25,),
          Container(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context).preLanguage + ' *',
                textAlign: TextAlign.left,
                style: GoogleFonts.rubik(
                  color: store.selectedLanguage != null ? AppColors.kb1b1b1 : AppColors.k010101,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8,),
              MultiSelectDialogField(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: language_validated ? AppColors.kb1b1b1 : AppColors.kfa0020,
                    width: language_validated ? 0.5 : 1,
                  ),
                ),
                title: Text(
                  S.of(context).preLanguage,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                buttonIcon: Icon(
                  Icons.g_translate,
                  color: AppColors.k0cbcc5,
                  size: 24,
                ),
                items: store.languages.map((e) => MultiSelectItem(e, e.language!)).toList(),
                onConfirm: (List<Language> values) {
                  if (values.isNotEmpty) {
                    store.selectedLanguages = values;
                    store.selectedLanguage = values.first;
                  } else {
                    store.selectedLanguage = null;
                    store.selectedLanguages = values;
                  }
                },
                validator: (value) {
                  if (value!.isEmpty) {
                    setState(() => language_validated = false);
                    return S.of(context).selectLanguages;
                  } else {
                    setState(() => language_validated = true);
                    return null;
                  }
                },
              ),
            ],
          ),),
          SizedBox(height: 25,),
          Container(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context).gender + ' *',
                textAlign: TextAlign.left,
                style: GoogleFonts.rubik(
                  color: store.selectedGender != null ? AppColors.kb1b1b1 : AppColors.k010101,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8,),
              DropdownButtonFormField<Gender>(
                value: store.selectedGender,
                onChanged: (Gender? newValue) {
                  store.selectedGender = newValue;
                },
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
                      value.name == 'Female' ? S.of(context).female : value.name == 'Male' ? S.of(context).male : S.of(context).selectGender,
                      style: GoogleFonts.rubik(
                        color: AppColors.k5e5e5e,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),),
          SizedBox(height: 25,),
          Container(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context).doctorPre,
                textAlign: TextAlign.left,
                style: GoogleFonts.rubik(
                  color: doctorPreferenceController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8,),
              doctorPreference(),
            ],
          ),),
          SizedBox(height: 25,),
          Text(
            S.of(context).medicareNumber,
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: medicareNumberController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8,),
          TextFormField(
            onChanged: (value) {
              // Nop
            },
            controller: medicareNumberController,
            keyboardType: TextInputType.text,
            inputFormatters: [
              // FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(20),
            ],
            validator: (value) {
              if (value != null && value.isNotEmpty && value.trim().isEmpty) {
                return S.of(context).invalidMedicareNumberContainsBlank;
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: '1234567890',
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
            autocorrect: false,
            enableSuggestions: false,
          ),
          SizedBox(height: 25,),
          Text(
            S.of(context).travelAgencyName,
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: travelAgencyNameController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8,),
          TextFormField(
            onChanged: (value) {
              // Nop
            },
            controller: travelAgencyNameController,
            decoration: InputDecoration(
              hintText: 'Ex: Torps and Sons',
              hintStyle: GoogleFonts.rubik(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget nextOfKin() {
    final store = widget.services.store;
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20,),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(S.of(context).nextOfKin, style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),),
          ),
          SizedBox(height: 19,),
          Text(
            S.of(context).fullName,
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: fullNameController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8,),
          TextFormField(
            onChanged: (value) {
              // Nop
            },
            controller: fullNameController,
            decoration: InputDecoration(
              hintText: 'Ex: Kelly Babara',
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
          SizedBox(height: 25,),
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
            onChanged: (value) {
              // NOP
            },
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              } else if (!EmailValidator.validate(value.trim())) {
                return S.of(context).entVEmain;
              }
              return null;
            },
            controller: emailController,
            decoration: InputDecoration(
              hintText: 'samplemail@example.com',
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
                  color: AppColors.kfa0020,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 25,),
          Text(
            S.of(context).phone,
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: phoneController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8,),
          TextFormField(
            onChanged: (value) {
              // Nop
            },
            keyboardType: TextInputType.phone,
            controller: phoneController,
            decoration: InputDecoration(
              hintText: '1234567890',
              hintStyle: GoogleFonts.rubik(
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
                  initialSelection: store.selectedCountry.dialCode,
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
                        SizedBox(width: 3.69,),
                        Text(
                          country.dialCode!,
                          style: GoogleFonts.rubik(
                            color: AppColors.kb1b1b1,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 6,),
                        Image.asset(
                            'assets/images/ic_pharmacy_location_expand.png'),
                        SizedBox(width: 6,),
                        Container(
                          height: 35,
                          width: 1,
                          color: AppColors.kb1b1b1.withOpacity(0.1),
                        )
                      ],
                    );
                  },
                  onChanged: (value) {
                    store.selectedCountry = value;
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget regularDoctor() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20,),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(S.of(context).regularDoctor, style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),),
          ),
          SizedBox(height: 19,),
          Text(
            S.of(context).fullName,
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: regularDoctorFullNameController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8,),
          TextFormField(
            onChanged: (value) {
              // NOP
            },
            controller: regularDoctorFullNameController,
            decoration: InputDecoration(
              hintText: 'Ex: Kelly Babara',
              hintStyle: GoogleFonts.rubik(
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
            ),
          ),
          SizedBox(height: 25,),
          Text(
            S.of(context).email,
            textAlign: TextAlign.left,
            style: GoogleFonts.rubik(
              color: regularDoctorEmailController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8,),
          TextFormField(
            onChanged: (value) {
              // Nop
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              } else if (!EmailValidator.validate(value.trim())) {
                return S.of(context).entVEmain;
              }
              return null;
            },
            keyboardType: TextInputType.emailAddress,
            controller: regularDoctorEmailController,
            decoration: InputDecoration(
              hintText: 'samplemail@example.com',
              hintStyle: GoogleFonts.rubik(
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
                  color: AppColors.kfa0020,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget doctorPreference() {
    final store = widget.services.store;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () => store.doctorPreference = 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
            decoration: BoxDecoration(
              color: store.doctorPreference == 0 ? AppColors.k0cbcc5 : AppColors.kffffff,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: store.doctorPreference == 0 ? Colors.transparent : AppColors.k0cbcc5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.2),
                  blurRadius: 10.0, // soften the shadow
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset( 0.0, 0.4,),
                )
              ],
            ),
            child: Text(
              S.of(context).anys,
              textAlign: TextAlign.left,
              style: GoogleFonts.rubik(
                color: store.doctorPreference == 0 ? AppColors.kffffff : AppColors.k0cbcc5,
                fontSize: 14
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => store.doctorPreference = 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.2),
                  blurRadius: 10.0, // soften the shadow
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset( 0.0, 0.4,),
                )
              ],
              color: store.doctorPreference == 1 ? AppColors.k0cbcc5 : AppColors.kffffff,
              border: Border.all(
                color: store.doctorPreference == 1 ? Colors.transparent : AppColors.k0cbcc5,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(S.of(context).male, style: GoogleFonts.rubik(
              color: store.doctorPreference == 1 ? AppColors.kffffff : AppColors.k0cbcc5,
              fontSize: 14
            ),)
          ),
        ),
        GestureDetector(
          onTap: () => store.doctorPreference = 2,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 6),
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.2),
                  blurRadius: 10.0, // soften the shadow
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset( 0.0, 0.4,),
                )
              ],
              color: store.doctorPreference == 2 ? AppColors.k0cbcc5 : AppColors.kffffff,
              border: Border.all(
                color: store.doctorPreference == 2 ? Colors.transparent : AppColors.k0cbcc5,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(S.of(context).female, style: GoogleFonts.rubik(
              color: store.doctorPreference == 2 ? AppColors.kffffff : AppColors.k0cbcc5,
              fontSize: 14
            ),),
          ),
        ),
      ],
    );
  }

  Widget cupertinoDatePicker(BuildContext context) {
    final now = DateTime.now();

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(left: 20, right: 20),
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Text(S.of(context).cancel, style: GoogleFonts.rubik(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: Color.fromRGBO(12, 188, 197, 1)
                  ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Text(S.of(context).done, style: GoogleFonts.rubik(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color.fromRGBO(12, 188, 197, 1)
                  ),),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            child: CupertinoDatePicker(
              initialDateTime: widget.services.store.selectedDate,
              maximumYear: now.year,
              minimumYear: 1930,
              // end of the date
              maximumDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
              use24hFormat: false,
              mode: CupertinoDatePickerMode.date,
              onDateTimeChanged: (dateTime) {
                widget.services.store.selectedDate = dateTime;
              },
            ),
          ),
        ],
      ),
    );
  }
}
