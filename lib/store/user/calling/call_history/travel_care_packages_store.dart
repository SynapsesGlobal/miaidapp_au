import 'dart:core';

import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:mobx/mobx.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

part 'travel_care_packages_store.g.dart';

@injectable
class TravelCarePackagesStore = _TravelCarePackagesStore
    with _$TravelCarePackagesStore;

abstract class _TravelCarePackagesStore with Store {
  _TravelCarePackagesStore(this.user, this.api);

  final UserProvider user;
  final ApiProvider api;

  @observable
  ObservableList<SubscriptionDetail> availableSubscriptions = <SubscriptionDetail>[].asObservable();

  @action
  Future<void> fetchAvailableSubscriptions() async {
    final countryCode = await getCountryCode();

    final response = await api.apiClient.subscriptionsGetList(country_code: countryCode);
    final subscriptions = await ApiSuccessParser.payloadOrThrowWithMessage(response);
    availableSubscriptions.clear();
    availableSubscriptions.addAll(subscriptions);
  }
}
