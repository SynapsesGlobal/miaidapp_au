import 'dart:convert';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

part 'user_doctor_translator_profile_screen_store.g.dart';

@injectable
class UserDoctorTranslatorProfileScreenStore = _UserDoctorTranslatorProfileScreenStore
    with _$UserDoctorTranslatorProfileScreenStore;

abstract class _UserDoctorTranslatorProfileScreenStore with Store {
  _UserDoctorTranslatorProfileScreenStore(this.api, this.user);

  final ApiProvider api;
  final UserProvider user;

  @action
  Future<void> updateProfilePicture(XFile pickedFile) async {
    // TODO swagger -> dart does not currently work with multipart file uploads
    var request = http.MultipartRequest(
        'POST', Uri.parse(api.apiClient.client.baseUrl + '/avatar'));
    request.files
        .add(await http.MultipartFile.fromPath('image', pickedFile.path));
    request.headers['x-access-token'] = api.userProvider.user!.accessToken!;
    request.headers['x-api-key'] = api.apiKey;
    var response = await api.apiClient.client.httpClient.send(request);
    if (response.statusCode == 200) {
      await refreshUser();
    } else {
      final body = await response.stream.bytesToString();
      final Map<String, dynamic> bodyJson = json.decode(body);
      final message = bodyJson['message'] ?? '';
      await HttpExceptionNotifyUser.showError(message);
      throw HttpException(response.statusCode, message);
    }
  }

  @action
  Future<void> refreshUser() async {
    final response = await api.apiClient.profileGetMyProfile();
    final payload = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    user.onUserUpdated(payload);
  }
}

String getDoctorPreference(BuildContext context, User user) {
  if (user.customer?.doctorPreference == null) {
    return S.of(context).doctorAny;
  }

  if (user.customer?.doctorPreference == 0) {
    return S.of(context).doctorAny;
  } else if (user.customer?.doctorPreference == 1) {
    return S.of(context).doctorMale;
  }
  return S.of(context).doctorFemale;
}

String extractPhoneWithoutCountryCode(String? phone) {
  if (phone == null) {
    return '';
  }

  if (phone.contains('-')) {
    return phone.split('-')[1];
  }

  return phone;
}

CountryCode extractCountryCodeFromPhoneNumber(String? phone) {
  final defaultCountryCode = CountryCode.fromCountryCode('CN');
  if (phone == null) {
    return defaultCountryCode;
  }

  CountryCode? countryCode;
  if (phone.contains('-')) {
    final dialCode = phone.split('-')[0];
    try {
      countryCode = CountryCode.fromDialCode(dialCode);
    } catch (e) {
      // Nop
    }
  }

  return countryCode ?? defaultCountryCode;
}
