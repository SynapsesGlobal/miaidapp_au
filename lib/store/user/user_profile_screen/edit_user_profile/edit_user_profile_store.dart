import 'package:country_code_picker/country_code_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

import '../user_profile_screen_store.dart';

part 'edit_user_profile_store.g.dart';

@injectable
class EditUserProfileStore = _EditUserProfileStore with _$EditUserProfileStore;

abstract class _EditUserProfileStore with Store {
  _EditUserProfileStore(this.api, this.user)
      : selectedDate = DateTime.tryParse(user.user!.customer!.dob!),
        userPhoneCountry = extractCountryCodeFromPhoneNumber(user.user?.phone),
        nextOfKinPhoneCountry = extractCountryCodeFromPhoneNumber(
            user.user?.customer?.nextOfKinMobile),
        selectedLanguage = user.user?.customer?.language,
        selectedLanguages = user.user?.customer?.languages ?? [],
        selectedGender = user.user?.customer?.gender,
        doctorPreference = user.user?.customer?.doctorPreference ?? 0,
        subscribeEmail =
            user.user?.customer?.subscribeEmail == 0 ? false : true;

  final ApiProvider api;
  final UserProvider user;

  @observable
  ObservableList<Language> languages = ObservableList<Language>();

  @observable
  ObservableList<Gender> genders = ObservableList<Gender>();

  @observable
  List<Language> selectedLanguages;

  @observable
  DateTime? selectedDate;

  @observable
  CountryCode userPhoneCountry;

  @observable
  CountryCode nextOfKinPhoneCountry;

  @observable
  Language? selectedLanguage;

  @observable
  Gender? selectedGender;

  @observable
  int doctorPreference;

  @observable
  bool subscribeEmail;

  @action
  Future<void> fetchOnInit() async {
    await Future.wait([
      fetchLanguages(),
      fetchGenders(),
    ]);
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
  Future<void> refreshUser() async {
    final response = await api.apiClient.profileGetMyProfile();
    final payload = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    user.onUserUpdated(payload);
  }

  @action
  void onSubscribeEmailChanged(bool value) {
    subscribeEmail = value;
  }
}
