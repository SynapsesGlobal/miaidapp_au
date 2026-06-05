import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

part 'location_details_store.g.dart';

@singleton
class LocationDetailsStore = _LocationDetailsStore with _$LocationDetailsStore;

abstract class _LocationDetailsStore with Store {
  TextEditingController searchController = TextEditingController();
  List<LocationFilter> listLocationFilters =
      []; // this is the original list, it'll have all the location filter objects in it at all times

  @observable
  int fetch = 0;

  @observable
  bool isFilterSelected =
      false; // this is to differentiate, if the some city is selected or my location to display on the eshop

  @observable
  bool isLoading = false;

  @observable
  String? citySelected;

  @observable
  String? stateSelected;

  @observable
  String? countrySelected;

  @observable
  List<Country> countryList = [];

  @observable
  List<String> cityList = [];

  @observable
  bool showNoLocationsInCountryError = false;

  @action
  void changeSelectedCountry(String value) {
    countrySelected = value;
    isFilterSelected = false;
    citySelected = null;
    stateSelected = null;
    // fetchPharmaciesAgain();
  }

  @action
  void fetchPharmaciesAgain() {
    fetch = fetch + 1;
  }

  @action
  void changeSelectedState(String value) {
    isFilterSelected = false;
    citySelected = null;
    stateSelected = value;
  }

  @action
  void changeSelectedCity(String value) {
    citySelected = value;
    changeIsFilterSelected(true);
    fetchPharmaciesAgain();
  }

  @action
  void changeIsFilterSelected(bool value) {
    isFilterSelected = value;
    if (value == false) {
      // user has selected current location
      citySelected = null;
      stateSelected = null;
      countrySelected = null;
      countryList.clear();
      cityList.clear();
      fetchPharmaciesAgain();
    }
  }

  @action
  dynamic fetchLocations(ApiProvider apiProvider, String country) async {
    isLoading = true;
    listLocationFilters.clear();
    cityList.clear();
    citySelected = null;
    stateSelected = null;
    var locale = Intl.getCurrentLocale();
    var locationsListResponse = await apiProvider.apiClient.eShopLocationsGetLocationList(country: country, lang: locale);
    if (ApiSuccessParser.isSuccessfulWithPayload(locationsListResponse)) {
      final pharmacyLocation = await ApiSuccessParser.payloadOrThrowWithMessage(locationsListResponse);
      listLocationFilters.addAll(pharmacyLocation);
      showNoLocationsInCountryError = false;
      isLoading = false;
    } else {
      showNoLocationsInCountryError = true;
      isLoading = false;
    }
  }

  @action
  dynamic fetchCountries(ApiProvider apiProvider) async {
    if (countryList.isEmpty) {
      isLoading = true;
      listLocationFilters.clear();
      countryList.clear();
      countrySelected = null;
      citySelected = null;
      stateSelected = null;
      cityList.clear();

      var locale = Intl.getCurrentLocale();
      var countriesListResponse = await apiProvider.apiClient.countriesGetCountriesList(lang: locale);
      isLoading = false;
      if (ApiSuccessParser.isSuccessfulWithPayload(countriesListResponse)) {
        final cList = await ApiSuccessParser.payloadOrThrowWithMessage(countriesListResponse);
        countryList.addAll(cList);
      } else {
        // parsing this here, it means it'll throw an error and display the error to the user
        await ApiSuccessParser.payloadOrThrowWithMessage(countriesListResponse);
      }
    }
  }

  @action
  void resetLocationDetailsStore() {
    isFilterSelected = false;
    citySelected = null;
    stateSelected = null;
    countrySelected = null;
    countryList.clear();
    cityList.clear();
  }
}
