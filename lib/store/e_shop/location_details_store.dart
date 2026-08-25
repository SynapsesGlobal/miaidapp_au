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

  /// 选国家后拉取城市列表的独立 loading：不复用 [isLoading]，
  /// 否则整页表单（含已显示的国家选择框）会被整体替换成 loading
  @observable
  bool isCityLoading = false;

  @observable
  String? citySelected;

  @observable
  int? cityIdSelected;

  @observable
  String? stateSelected;

  @observable
  String? countrySelected;

  @observable
  int? countryIdSelected;

  @observable
  List<Country> countryList = [];

  @observable
  List<CityOption> cityList = [];

  @observable
  bool showNoLocationsInCountryError = false;

  /// Locale the cached [countryList] was fetched for, so a language change
  /// re-fetches instead of showing names in the previous language.
  String? _loadedLocale;

  @action
  void changeSelectedCountry(String value, {int? countryId}) {
    countrySelected = value;
    countryIdSelected = countryId;
    isFilterSelected = false;
    citySelected = null;
    cityIdSelected = null;
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
    cityIdSelected = null;
    stateSelected = value;
  }

  @action
  void changeSelectedCity(String value, {int? cityId}) {
    citySelected = value;
    cityIdSelected = cityId;
    changeIsFilterSelected(true);
    fetchPharmaciesAgain();
  }

  @action
  void changeIsFilterSelected(bool value) {
    isFilterSelected = value;
    if (value == false) {
      // user has selected current location
      citySelected = null;
      cityIdSelected = null;
      stateSelected = null;
      countrySelected = null;
      countryIdSelected = null;
      countryList.clear();
      cityList.clear();
      _loadedLocale = null;
      fetchPharmaciesAgain();
    }
  }

  @action
  dynamic fetchLocations(ApiProvider apiProvider, String country, {int? countryId}) async {
    isCityLoading = true;
    listLocationFilters.clear();
    cityList = [];
    citySelected = null;
    cityIdSelected = null;
    stateSelected = null;
    showNoLocationsInCountryError = false;
    try {
      var locale = Intl.getCurrentLocale();
      var locationsListResponse = await apiProvider.apiClient
          .eShopLocationsGetLocationList(country: country, country_id: countryId, lang: locale);
      if (ApiSuccessParser.isSuccessfulWithPayload(locationsListResponse)) {
        final pharmacyLocation = await ApiSuccessParser.payloadOrThrowWithMessage(locationsListResponse);
        listLocationFilters.addAll(pharmacyLocation);
        cityList = _cityOptionsFrom(listLocationFilters);
      } else {
        showNoLocationsInCountryError = true;
      }
    } catch (e) {
      // 网络异常/超时也走错误卡片，用户可重选国家重试；
      // 不能让 loading 标志卡在 true（否则城市区域永远转圈）
      showNoLocationsInCountryError = true;
    } finally {
      isCityLoading = false;
    }
  }

  /// The backend returns `city_list` with ids; `cities` holds the same names
  /// without them and is only there for clients older than that change.
  List<CityOption> _cityOptionsFrom(List<LocationFilter> filters) {
    final options = <CityOption>[];
    for (final filter in filters) {
      final withIds = filter.cityList ?? [];
      if (withIds.isNotEmpty) {
        options.addAll(withIds);
      } else {
        options.addAll((filter.cities ?? []).map((name) => CityOption(name: name)));
      }
    }
    return options;
  }

  @action
  dynamic fetchCountries(ApiProvider apiProvider) async {
    var locale = Intl.getCurrentLocale();
    if (countryList.isEmpty || _loadedLocale != locale) {
      isLoading = true;
      listLocationFilters.clear();
      countryList.clear();
      countrySelected = null;
      countryIdSelected = null;
      citySelected = null;
      cityIdSelected = null;
      stateSelected = null;
      cityList = [];

      try {
        var countriesListResponse = await apiProvider.apiClient.countriesGetCountriesList(lang: locale);
        if (ApiSuccessParser.isSuccessfulWithPayload(countriesListResponse)) {
          final cList = await ApiSuccessParser.payloadOrThrowWithMessage(countriesListResponse);
          countryList.addAll(cList);
          _loadedLocale = locale;
        } else {
          // parsing this here, it means it'll throw an error and display the error to the user
          await ApiSuccessParser.payloadOrThrowWithMessage(countriesListResponse);
        }
      } finally {
        // 请求本身抛异常（如超时）时也要复位，避免整页永远 loading
        isLoading = false;
      }
    }
  }

  @action
  void resetLocationDetailsStore() {
    isFilterSelected = false;
    citySelected = null;
    cityIdSelected = null;
    stateSelected = null;
    countrySelected = null;
    countryIdSelected = null;
    countryList.clear();
    cityList = [];
    _loadedLocale = null;
  }
}
