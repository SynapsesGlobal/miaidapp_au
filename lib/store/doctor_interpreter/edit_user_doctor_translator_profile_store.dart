import 'package:country_code_picker/country_code_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/doctor_interpreter/user_doctor_translator_profile_screen_store.dart';
import 'package:mobx/mobx.dart';

import 'user_doctor_translator_profile_screen_store.dart';

part 'edit_user_doctor_translator_profile_store.g.dart';

@injectable
class EditUserDoctorTranslatorProfileStore = _EditUserDoctorTranslatorProfileStore
    with _$EditUserDoctorTranslatorProfileStore;

abstract class _EditUserDoctorTranslatorProfileStore with Store {
  _EditUserDoctorTranslatorProfileStore(this.api, this.user)
      : userPhoneCountry = extractCountryCodeFromPhoneNumber(user.user?.phone),
        selectedLanguage = user.user?.customer?.language,
        selectedGender = user.user?.customer?.gender;

  final ApiProvider api;
  final UserProvider user;

  @observable
  ObservableList<Language> languages = ObservableList<Language>();

  @observable
  ObservableList<Gender> genders = ObservableList<Gender>();

  @observable
  ObservableList<Country> countries = ObservableList<Country>();

  @observable
  CountryCode userPhoneCountry;

  @observable
  Language? selectedLanguage;

  @observable
  Gender? selectedGender;

  @observable
  Country? selectedCountry;

  @action
  Future<void> fetchOnInit() async {
    await Future.wait([
      fetchLanguages(),
      fetchGenders(),
      fetchCountries(),
    ]);

    if (user.isDoctor) {
      final languages = user.user?.doctor?.doctorLanguages ?? [];
      selectedLanguage = languages.isEmpty ? null : languages.first;
      selectedGender = user.user?.doctor?.gender;
      selectedCountry = user.user?.doctor?.doctorCountry;
    } else if (user.isTranslator) {
      final languages = user.user?.translator?.translatorLanguages ?? [];
      selectedLanguage = languages.isEmpty ? null : languages.first;
      selectedGender = user.user?.translator?.gender;
      selectedCountry = user.user?.translator?.translatorCountry;
    }
  }

  @action
  Future<void> fetchLanguages() async {
    final response = await api.apiClient.languagesGetLanguagesList();
    final payload = await ApiSuccessParser.payloadOrThrowWithMessage(response);

    languages.clear();
    languages.addAll(payload);
  }

  @action
  Future<void> fetchGenders() async {
    final response = await api.apiClient.gendersGetGendersList();
    final payload = await ApiSuccessParser.payloadOrThrowWithMessage(response);

    genders.clear();
    genders.addAll(payload);
  }

  @action
  Future<void> fetchCountries() async {
    final response = await api.apiClient.countriesGetCountriesList();
    final payload = await ApiSuccessParser.payloadOrThrowWithMessage(response);

    countries.clear();
    countries.addAll(payload);
  }

  @action
  Future<void> refreshUser() async {
    final response = await api.apiClient.profileGetMyProfile();
    final payload = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    user.onUserUpdated(payload);
  }
}
