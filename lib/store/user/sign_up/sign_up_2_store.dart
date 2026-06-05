import 'package:country_code_picker/country_code_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

part 'sign_up_2_store.g.dart';

@injectable
class SignUp2Store = _SignUp2Store with _$SignUp2Store;

abstract class _SignUp2Store with Store {
  _SignUp2Store(this.api);

  final ApiProvider api;

  @observable
  ObservableList<Language> languages = ObservableList<Language>();

  @observable
  ObservableList<Gender> genders = ObservableList<Gender>();

  @observable
  DateTime? selectedDate;

  @observable
  CountryCode selectedCountry = CountryCode.fromCountryCode('CN');

  @observable
  Language? selectedLanguage;

  @observable
  List<Language> selectedLanguages = [];

  @observable
  Gender? selectedGender;

  @observable
  int doctorPreference = 0; // 0: any, 1: male, 2: female

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
}
