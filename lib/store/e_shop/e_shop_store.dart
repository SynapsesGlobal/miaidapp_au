import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/main.dart';
import 'package:miaid/model/map_marker.dart';
import 'package:miaid/utils/geolocation.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:math' as math;

part 'e_shop_store.g.dart';

@injectable
class EShopStore = _EShopStore with _$EShopStore;

abstract class _EShopStore with Store {
  LatLng mapDefaultCenter = LatLng(-33.4567, 146.3796);
  TextEditingController searchController = TextEditingController();
  Position? currentLocation;
  bool shouldGoToCurrentLocation = false;
  int page = 1;
  int itemsPerPage = 50;
  static const distanceOptions = ["5km", "10km", "Cancel"];

  @observable
  List<PharmacyLocation> pharmacyList = []; // get from request, not changed

  @observable
  int showPharmacyDetailDialog =
      0; // we need a observable that we'll listen to as a Reaction, and everytime it should change state

  @observable
  int showPharmacyOnMap =
      0; // we need a observable that we'll listen to as a Reaction, and everytime it should change state

  // filter search input
  @observable
  List<PharmacyLocation> searchPharmacies = [];
  List<PharmacyLocation> _searchPharmaciesOriginal = [];

  @observable
  bool searchingAPharmacy = false;

  @observable
  PharmacyLocation? selectedPharmacy;

  @observable
  DeliveryFee? deliveryFee;

  @observable
  List<Product> products = [];

  @observable
  bool isLoading = false;

  @observable
  int viewType = 0; // 0 for listView, 1 for mapView

  @observable
  ObservableList<MapMarker> pinMarkers = ObservableList();

  @observable
  String filterText = '';

  @action
  void setFilterText(String text) {
    filterText = text;
  }

  @action
  void changeView(int value) {
    viewType = value;
    if (value == 0) {
      setFilterText('');
    }
  }

  @action
  dynamic getCurrentUserLocation(BuildContext context) async {
    var p = await MyGeoLocation().determinePosition(context);
    //developer.log('current position: ${p.latitude}');
    currentLocation = p;
    shouldGoToCurrentLocation = true;
    mapDefaultCenter = LatLng(p.latitude, p.longitude);

    addCurrentLocationIcon();
  }

  @action
  dynamic fetchPharmacies(ApiProvider apiProvider, BuildContext context,
      {String? country, String? city}) async {
    currentLocation = await MyGeoLocation().determinePosition(context);
    isLoading = true;
    Response<EShopLocationsFilterLocationsResponse> pharmacyListResponse;
    if (country != null && city != null) {
      pharmacyListResponse =
          await apiProvider.apiClient.eShopLocationsGetFilterLocations(
        country: country,
        city: city,
        per_page: itemsPerPage,
        page: page,
      );
    } else if (currentLocation != null) {
      pharmacyListResponse =
          await apiProvider.apiClient.eShopLocationsGetFilterLocations(
        latitude: currentLocation?.latitude,
        longitude: currentLocation?.longitude,
        per_page: itemsPerPage,
        page: page,
      );
    } else {
      pharmacyListResponse =
          await apiProvider.apiClient.eShopLocationsGetFilterLocations(
        latitude: currentLocation?.latitude,
        longitude: currentLocation?.longitude,
        per_page: itemsPerPage,
        page: page,
      );
    }

    if (ApiSuccessParser.isSuccessfulWithPayload(pharmacyListResponse)) {
      final pharmacyList = await ApiSuccessParser.payloadOrThrowWithMessage(
          pharmacyListResponse);
      updatePharmacyList(pharmacyList);
    }
    isLoading = false;
  }

  @action
  void updateProducts(List<Product> list) {
    //developer.log('updating products: $list');
    products = list;
  }

  @action
  void updatePharmacyList(List<PharmacyLocation> list) {
    if (page > 1) {
      pharmacyList.addAll(list);
    } else {
      pharmacyList = list;
    }

    if (searchingAPharmacy) {
      searchPharmacies = pharmacyList
          .where((element) => (element.pharmacy!.name ?? '')
              .toLowerCase()
              .contains(searchController.text.toLowerCase()))
          .toList();
      _searchPharmaciesOriginal = searchPharmacies;
    }

    setMapPins();
  }

  @action
  void searchPharmacy() {
    // developer.log('searching a pharmacy now');
    if (searchController.text.isEmpty) {
      // notify user that no pharmacy found
      HttpExceptionNotifyUser.showInfo(
          S.of(navigatorKey.currentContext!).emptyPharmacySearchText);

      return;
    }

    // trim the search text
    if (searchController.text.trim().isEmpty) {
      // notify user that no pharmacy found
      HttpExceptionNotifyUser.showInfo(
          S.of(navigatorKey.currentContext!).emptyPharmacySearch);

      return;
    }

    searchingAPharmacy = true;
    searchPharmacies = pharmacyList
        .where((element) => (element.pharmacy!.name ?? '')
            .toLowerCase()
            .contains(searchController.text.toLowerCase()))
        .toList();
    _searchPharmaciesOriginal = searchPharmacies;

    setMapPins();

    if (searchPharmacies.isEmpty) {
      // notify user that no pharmacy found
      HttpExceptionNotifyUser.showInfo(S
          .of(navigatorKey.currentContext!)
          .noPharmacyFound(searchController.text));

      return;
    }
    animateMapToSearchedPharmacy();
  }

  @action
  void stoppedSearching() {
    searchingAPharmacy = false;
    searchPharmacies.clear();
    _searchPharmaciesOriginal.clear();

    // searchPharmacies = searchPharmacies;
    setMapPins();
    animateMapToSearchedPharmacy();
  }

  @action
  void addCurrentLocationIcon() {
    //developer.log('adding current marker: ${currentLocation?.latitude}');
    try {
      pinMarkers.removeWhere((element) => element.id == 'myCurrentLocation');
      pinMarkers.add(
        MapMarker(
          id: 'myCurrentLocation',
          marker: Marker(
            point: LatLng(
              currentLocation!.latitude,
              currentLocation!.longitude,
            ),
            builder: (context) {
              return Icon(
                Icons.location_on_rounded,
                size: 30,
                color: Colors.blue,
              );
            },
          ),
        ),
      );
      pinMarkers = pinMarkers;
      //developer.log('adding current marker legth: ${pinMarkers.length}');
    } catch (e) {
      //developer.log(e.toString());
    }
  }

  @action
  void setMapPins() {
    // updating pins
    pinMarkers.clear();

    // sometimes, setMapPins is called by distance filter, so we need to filter the pharmacies
    // from the original list of searched pharmacies. searchPharmacies is updated everytime the user
    // searches a pharmacy or select the distance filter
    var markerPharmacies =
        searchingAPharmacy ? _searchPharmaciesOriginal : pharmacyList;

    // to save the pharmacies in the radius
    List<PharmacyLocation> pharmacies = [];

    if (filterText == distanceOptions[0] || filterText == distanceOptions[1]) {
      var myPlace = LatLng(
        currentLocation!.latitude,
        currentLocation!.longitude,
      );
      pharmacies = markerPharmacies.where((element) {
        var latLng = LatLng(
            element.latitude != null ? element.latitude! : 0.000000,
            element.longitude != null ? element.longitude! : 0.000000);

        var p = 0.017453292519943295;
        var c = math.cos;
        var a = 0.5 -
            c((myPlace.latitude - latLng.latitude) * p) / 2 +
            c(myPlace.latitude * p) *
                c(latLng.latitude * p) *
                (1 - c((myPlace.longitude - latLng.longitude) * p)) /
                2;
        var distance = 12742 * math.asin(math.sqrt(a));

        if (filterText == distanceOptions[1]) {
          if (distance > 10) {
            return false;
          }
        }

        if (filterText == distanceOptions[0]) {
          if (distance > 5) {
            return false;
          }
        }

        return true;
      }).toList();
    } else {
      pharmacies = markerPharmacies;
    }

    if (searchingAPharmacy) {
      searchPharmacies = pharmacies;
    }

    pharmacies.forEach(
      (pharmacy) {
        var mapMarker = MapMarker(
            id: pharmacy.pharmacy!.id.toString(),
            marker: Marker(
                height: 24,
                width: 24,
                point: LatLng(
                    pharmacy.latitude != null
                        ? pharmacy.latitude!
                        : 0.000000, // some pharmacies have location null, hence we are giving them a dummy location
                    pharmacy.longitude != null
                        ? pharmacy.longitude!
                        : 0.000000),
                builder: (context) {
                  return GestureDetector(
                    onTap: () {
                      // selected pharmacy
                      _mapMarkerClicked(pharmacy);
                    },
                    child: Image.asset(
                      'assets/images/ic_mappin_clinic.png', // this is source icon
                      fit: BoxFit.fitHeight,
                    ),
                  );
                }));
        pinMarkers.add(mapMarker);
      },
    );
    addCurrentLocationIcon();
  }

  void _mapMarkerClicked(PharmacyLocation pharmacy) {
    // selected pharmacy
    selectedPharmacy = pharmacyList
        .firstWhere((element) => element.address == pharmacy.address);
    //developer.log('markers on Map Length: ${pinMarkers.length}');

    // update the icon here
    pinMarkers.removeWhere((MapMarker element) {
      if (element.id == pharmacy.pharmacy!.id.toString()) {
        return true;
      }
      return false;
    });

    pinMarkers = pinMarkers;

    var m = MapMarker(
        id: pharmacy.id.toString(),
        marker: Marker(
            height: 24,
            width: 24,
            point: LatLng(
              pharmacy.latitude != null
                  ? pharmacy.latitude!
                  : 0.000000, // some pharmacies have location null, hence we are giving them a dummy location
              pharmacy.longitude != null ? pharmacy.longitude! : 0.000000,
            ),
            builder: (context) {
              return Image.asset(
                'assets/images/ic_mappin_clinic_selected.png', // this is source icon
                fit: BoxFit.fitHeight,
              );
            }));

    pinMarkers.add(m);

    // showing the bottom sheet dialog here
    showPharmacyDetailDialog = showPharmacyDetailDialog + 1;
  }

  @action
  void animateMapToSearchedPharmacy() {
    showPharmacyOnMap = showPharmacyOnMap + 1;

    // if (searchPharmacies.isNotEmpty && searchingAPharmacy) {
    //   print('animating map camera 1');
    // }
  }
}
