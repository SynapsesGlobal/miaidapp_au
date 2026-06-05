import 'dart:async';
import 'dart:core';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:mobx/mobx.dart';
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

part 'map_screen_store.g.dart';

@injectable
class MapScreenStore = _MapScreenStore with _$MapScreenStore;

abstract class _MapScreenStore with Store {
  _MapScreenStore(this.user, this.api);

  final UserProvider user;
  final ApiProvider api;

  final searchController = TextEditingController();
  final mapController = MapController();
  final panelController = PanelController();

  @observable
  PlaceType? selectedPlaceType;

  @observable
  ObservableList<PlaceType> placeTypes = ObservableList<PlaceType>();

  @observable
  ObservableList<Place> places = ObservableList<Place>();

  @observable
  Place? selectedPlace;

  // Sidney's coordinates by default
  @observable
  LatLng latLng = LatLng(-33.86785, 151.20732);

  @observable
  bool isMapReady = false;

  Future<void>? ongoingDelayedSearchFuture;

  // StreamSubscription<MapEvent>? mapStreamEvents;

  StreamSubscription? subscription;

  late Completer<MapController> controllerCompleter = Completer();

  @action
  Future<void> initState() async {
    final placeTypesResponseFuture = api.apiClient.placesGetPlaceTypesList();

    //FIXME: This is a hack to make sure the map is ready before we try to move it
    // await mapController.onReady;

    await controllerCompleter.future;

    isMapReady = true;

    subscription = mapController.mapEventStream.listen((MapEvent mapEvent) {
      if (mapEvent is MapEventMoveStart) {
        print(DateTime.now().toString() + ' [MapEventMoveStart] START');
        // do something
      }
      if (mapEvent is MapEventMoveEnd) {
        print(DateTime.now().toString() + ' [MapEventMoveStart] END');
        // do something
        search();
      }
    });

    try {
      // Try to move the map to the last known user position
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        latLng = LatLng(lastPosition.latitude, lastPosition.longitude);
        mapController.move(latLng, 13.0);
      }
    } catch (e) {
      // NOP
      // print('Could not get last known user location: $e');
    }

    Future<void>? searchFuture;

    try {
      // Move the map to the last user position if we can get it
      final position =
          await determinePosition(desiredAccuracy: LocationAccuracy.high);
      latLng = LatLng(position.latitude, position.longitude);
      mapController.move(latLng, 13.0);

      searchFuture = search();
    } catch (e) {
      // NOP
    }

    final placeTypesResponse = await placeTypesResponseFuture;
    final placeTypesList =
        await ApiSuccessParser.payloadOrThrowWithMessage(placeTypesResponse);
    placeTypes.clear();
    placeTypes.addAll(placeTypesList);

    if (searchFuture != null) {
      await searchFuture;
    }

    // await search();
  }

  Future<void> dispose() async {
    // final future = mapStreamEvents?.cancel();
    // mapStreamEvents = null;
    // await future;

    subscription?.cancel();
  }

  @action
  Future<void> search() async {
    await EasyLoading.show(
        status: 'loading...', maskType: EasyLoadingMaskType.clear);
    final center = mapController.center;
    final response = await api.apiClient.placesGetListPlaces(
      q: searchController.text.trim(),
      latitude: center.latitude,
      longitude: center.longitude,
      place_type_id: selectedPlaceType?.id,
    );
    final placesList =
        await ApiSuccessParser.payloadOrThrowWithMessage(response);
    places.clear();
    places.addAll(placesList);
    await EasyLoading.dismiss();
  }

  @action
  Future<void> searchWithDelay() async {
    if (ongoingDelayedSearchFuture == null) {
      try {
        ongoingDelayedSearchFuture =
            Future.delayed(Duration(milliseconds: 1500));
        await ongoingDelayedSearchFuture;
        await search();
      } finally {
        ongoingDelayedSearchFuture = null;
      }
    }
  }

  @action
  Future<void> toggleSelectedPlaceType(PlaceType placeType) async {
    if (selectedPlaceType == placeType) {
      selectedPlaceType = null;
      await search();
    } else {
      selectedPlaceType = placeType;
      await search();
    }
  }

  @action
  Future<void> toggleSelectedPlace(Place? place) async {
    if (selectedPlace == place) {
      selectedPlace = null;
      // await panelController.hide();
      await panelController.close();
    } else {
      selectedPlace = place;
      // await panelController.show();
      await panelController.open();
    }
  }
}
