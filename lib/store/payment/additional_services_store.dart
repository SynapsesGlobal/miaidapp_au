import 'dart:core';

import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/store/payment/payment_store.dart';
import 'package:mobx/mobx.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

part 'additional_services_store.g.dart';

@injectable
class AdditionalServicesStore = _AdditionalServicesStore
    with _$AdditionalServicesStore;

class ServiceWithType {
  ServiceWithType(this.service, this.purchaseType);

  final Service service;
  final PurchaseType purchaseType;
}

abstract class _AdditionalServicesStore with Store {
  _AdditionalServicesStore(this.user, this.api);

  final UserProvider user;
  final ApiProvider api;

  @observable
  ObservableList<ServiceWithType> services = <ServiceWithType>[].asObservable();

  @action
  Future<void> fetchServices() async {
    final countryCode = await getCountryCode();

    final response = await api.apiClient
        .subscriptionsGetAdditionalVideoConsultation(country_code: countryCode);
    await ApiSuccessParser.isSuccessfulOrThrowWithMessage(response);
    final additionalConsultation = response.body?.payload;

    final response2 = await api.apiClient
        .subscriptionsGetListServices(country_code: countryCode);
    final List<Service> servicesResponse =
        await ApiSuccessParser.payloadOrThrowWithMessage(response2);
    this.services.clear();
    if (additionalConsultation != null) {
      services.addAll(additionalConsultation
          .map((service) => ServiceWithType(service, PurchaseType.services)));
    }
    this.services.addAll(servicesResponse
        .map((service) => ServiceWithType(service, PurchaseType.services)));
  }
}
