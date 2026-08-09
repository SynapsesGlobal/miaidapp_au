import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart' as ml;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/map/map_screen_store.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api_utils/consts.dart';

class MapScreenParams {
  const MapScreenParams(this.key);

  final Key key;
}

@injectable
class MapScreenServices {
  MapScreenServices(
    this.api,
    this.store,
  );

  final ApiProvider api;
  final MapScreenStore store;
}

@injectable
class MapScreen extends StatefulWidget {
  MapScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final MapScreenParams? params;
  final MapScreenServices services;

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  void initState() {
    super.initState();
    widget.services.store.initState();
  }

  @override
  void dispose() {
    widget.services.store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.kffffff,
      drawer: getDrawer(store.user),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).eandc,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: navBarIcon(iconAssetName: 'ic_nb_menu.png'),
            );
          },
        ),
      ),
      body: SlidingUpPanel(
        backdropEnabled: true,
        panelSnapping: false,
        // minHeight: store.selectedPlace == null ? 0 : 180,
        minHeight: 0,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        maxHeight: MediaQuery.of(context).size.height * 0.58,
        controller: store.panelController,
        panelBuilder: (scrollController) => ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Observer(
            builder: (context) => _activeLocationDetails(
              context,
              scrollController,
              widget.services.store,
            ),
          ),
        ),
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height,
              child: Observer(
                builder: (context) => _mapbox(context),
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                height: 110,
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.kffffff,
                      AppColors.kffffff,
                      Colors.white10,
                    ],
                    begin: FractionalOffset.topCenter,
                    end: FractionalOffset.bottomCenter,
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 50,
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(child: TextField(
                      controller: store.searchController,
                      onChanged: (value) {},
                      decoration: InputDecoration(
                        hintText: S.of(context).search,
                        hintStyle: GoogleFonts.rubik(
                          color: AppColors.kb1b1b1,
                          fontSize: 14,
                        ),
                        contentPadding: EdgeInsets.only(
                          left: 16,
                          top: 5,
                          bottom: 5,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.yellow),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.k010101,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.kb1b1b1,
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),),
                    SizedBox(width: 12,),
                    TapDebouncer(
                      onTap: () async => await store.search(),
                      builder: (context, onTap) => GestureDetector(
                        onTap: onTap,
                        child: Image.asset('assets/images/btn_search.png'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 50,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 60,
                child: Observer(
                  builder: (context) => ListView(
                    padding: const EdgeInsets.only(
                      left: 18,
                      right: 18,
                      top: 10,
                      bottom: 10,
                    ),
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    physics: BouncingScrollPhysics(),
                    children: [
                      for (var placeType in widget.services.store.placeTypes) ...[
                        Observer(
                          builder: (context) => _placeTypeFilter(
                            context, widget.services.store, placeType
                          ),
                        ),
                        SizedBox(width: 10,)
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              right: 8,
              child: Container(
                width: 40,
                height: 40,
                child: FloatingActionButton(
                  onPressed: () {
                    widget.services.store.mapController.move(
                      widget.services.store.latLng,
                      13.0,
                    );
                    widget.services.store.search();
                  },
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.my_location_rounded,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapbox(BuildContext context) {
    return FlutterMap(
      mapController: widget.services.store.mapController,
      options: MapOptions(
        center: widget.services.store.latLng,
        zoom: 13.0,
        maxZoom: 18.0,
        onMapReady: () {
          widget.services.store.controllerCompleter.complete(widget.services.store.mapController);
        },
        onPositionChanged: (position, hasGesture) {
          print("position changed");
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://api.mapbox.com/styles/v1/abdullahriaz95/ckrx2pafw27bh17ryrlaoy65r/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
          additionalOptions: {
            'accessToken': dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
          },
        ),
        MarkerLayer(
          markers: [
            if (widget.services.store.isMapReady)
              Marker(
                point: widget.services.store.latLng,
                builder: (context) => Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: Colors.red,
                )
              ),
            for (final place in widget.services.store.places)
              Marker(
                point: LatLng(place.latitude!, place.longitude!),
                builder: (context) => GestureDetector(
                  onTap: () => widget.services.store.toggleSelectedPlace(place),
                  child: Observer(
                    builder: (context) => _markerWidget(context, widget.services.store, place),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _activeLocationDetails(BuildContext context, ScrollController scrollController, MapScreenStore store) {
    if (store.selectedPlace == null) {
      return Container();
    }

    final place = store.selectedPlace;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(
        top: 0,
        left: 20,
        right: 20,
      ),
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      children: [
        SizedBox(height: 10,),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 53,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.k010101.withOpacity(0.09),
              borderRadius: BorderRadius.circular(2.5)
            ),
          ),
        ),
        SizedBox(height: 10,),
        Text(store.selectedPlace?.name ?? '', style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),),
        SizedBox(height: 15,),
        Row(children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: MediaQuery.of(context).size.width - 40,
                child: Text(
                  store.selectedPlace?.address ?? '',
                  style: GoogleFonts.rubik(
                    color: AppColors.k747474,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          )
        ],),
        SizedBox(height: 18,),
        Row(children: [
          GestureDetector(
            onTap: () {
              if (place?.phone != null) {
                launch('tel://${place!.phone!}');
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 45),
              decoration: BoxDecoration(
                color: AppColors.k0cbcc5,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(S.of(context).call, style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),),
            ),
          ),
          SizedBox(width: 10,),
          TapDebouncer(
            onTap: () async {
              if (place?.latitude != null && place?.longitude != null) {
                final availableMaps = await ml.MapLauncher.installedMaps;
                if (availableMaps.isNotEmpty) {
                  await availableMaps.first.showMarker(
                      coords: ml.Coords(place!.latitude!, place.longitude!),
                      title: place.name ?? '',
                      description: place.address ?? ''
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).installMap),),
                  );
                }
              }
            },
            builder: (context, onTap) => GestureDetector(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    width: 0.5,
                    color: AppColors.k0cbcc5,
                  )
                ),
                child: Text(S.of(context).getDirection, style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),),
              ),
            ),
          ),
        ],),
        SizedBox(height: 15,),
        Padding(
          padding: const EdgeInsets.only(
            right: 0,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: 1,
            color: AppColors.k0cbcc5.withOpacity(0.2),
          ),
        ),
        SizedBox(height: 15,),
        Text(S.of(context).openingHr, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),),
        SizedBox(height: 14,),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(S.of(context).monday, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k696969,
                fontWeight: FontWeight.w500,
              ),),
            ),
            SizedBox(width: 38,),
            Column(children: _placeAvailability(context, place!, 0).map((e) {
              return Text(e, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k5e5e5e,
                fontWeight: FontWeight.w500,
              ),);
            }).toList(),)
          ],
        ),
        SizedBox(height: 11,),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(S.of(context).tuesday, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k696969,
                fontWeight: FontWeight.w500,
              ),),
            ),
            SizedBox(width: 38,),
            Column(children: _placeAvailability(context, place, 1).map((e) {
              return Text(e, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k5e5e5e,
                fontWeight: FontWeight.w500,
              ),);
            }).toList(),)
          ],
        ),
        SizedBox(height: 11,),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(S.of(context).wednesday, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k696969,
                fontWeight: FontWeight.w500,
              ),),
            ),
            SizedBox(width: 38,),
            Column(children: _placeAvailability(context, place, 2).map((e) {
              return Text(e, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k5e5e5e,
                fontWeight: FontWeight.w500,
              ),);
            }).toList(),)
          ],
        ),
        SizedBox(height: 11,),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(S.of(context).thursday, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k696969,
                fontWeight: FontWeight.w500,
              ),),
            ),
            SizedBox(width: 38,),
            Column(children: _placeAvailability(context, place, 3).map((e) {
              return Text(e, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k5e5e5e,
                fontWeight: FontWeight.w500,
              ),);
            }).toList(),)
          ],
        ),
        SizedBox(height: 11,),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(S.of(context).friday, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k696969,
                fontWeight: FontWeight.w500,
              ),),
            ),
            SizedBox(width: 38,),
            Column(children: _placeAvailability(context, place, 4).map((e) {
              return Text(e, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k5e5e5e,
                fontWeight: FontWeight.w500,
              ),);
            }).toList(),)
          ],
        ),
        SizedBox(height: 11,),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(S.of(context).saturday, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k696969,
                fontWeight: FontWeight.w500,
              ),),
            ),
            SizedBox(width: 38,),
            Column(children: _placeAvailability(context, place, 5).map((e) {
              return Text(e, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k5e5e5e,
                fontWeight: FontWeight.w500,
              ),);
            }).toList(),)
          ],
        ),
        SizedBox(height: 11,),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(S.of(context).sunday, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k696969,
                fontWeight: FontWeight.w500,
              ),),
            ),
            SizedBox(width: 38,),
            Column(children: _placeAvailability(context, place, 6).map((e) {
              return Text(e, style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k5e5e5e,
                fontWeight: FontWeight.w500,
              ),);
            }).toList(),)
          ],
        ),
        SizedBox(height: 20,),
      ],
    );
  }

  // 地点类型名称由后端返回（固定为英文），这里按名称翻译；
  // 未知类型回落到后端原文，避免新增类型时显示空白
  String _placeTypeLabel(BuildContext context, String? name) {
    switch ((name ?? '').trim().toLowerCase()) {
      case 'pharmacy':
        return S.of(context).pharmacy;
      case 'clinic':
        return S.of(context).clinic;
      case 'ed location':
        return S.of(context).emergencys;
      case 'dentist':
        return S.of(context).dentist;
      case 'physiotherapy':
        return S.of(context).physiotherapy;
      default:
        return name ?? '';
    }
  }

  Widget _placeTypeFilter(BuildContext context, MapScreenStore store, PlaceType placeType) {
    var colour = AppColors.fromHex(placeType.hexColour) ?? AppColors.k0cbcc5;
    var backgroundColour = Colors.white;
    var fontColour = Colors.black;
    if (store.selectedPlaceType == placeType) {
      backgroundColour = colour;
      colour = Colors.white;
      fontColour = Colors.white;
    }

    return TapDebouncer(
      onTap: () async {
        await store.toggleSelectedPlaceType(placeType);
      },
      builder: (context, onTap) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColour,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              width: 0.5,
              color: colour,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.k003f51.withOpacity(0.1),
                offset: Offset(0, 4,),
                blurRadius: 10,
                spreadRadius: 0,
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 10,
              bottom: 10,
            ),
            child: Row(children: [
              Container(
                height: 9,
                width: 9,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: colour.withOpacity(0.1),
                      offset: Offset(0, 4,),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ],
                ),
              ),
              SizedBox(width: 6),
              Text(_placeTypeLabel(context, placeType.name), style: GoogleFonts.rubik(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: fontColour,
              ),),
            ],),
          ),
        ),
      ),
    );
  }

  ImageProvider imageWidget(String? url) {
    if (url != null) {
      return CachedNetworkImageProvider(
        url,
      );
    }
    return AssetImage('assets/images/Img_signin_corporateuser.png');
  }

  Widget _markerWidget(BuildContext context, MapScreenStore store, Place place) {
    final isSelected = place == store.selectedPlace;

    var colour = AppColors.fromHex(place.placeType?.hexColour) ?? AppColors.k0cbcc5;
    var dotColour = Colors.white;
    var markerSize = 20.0;
    if (isSelected) {
      markerSize = 27.0;
      dotColour = colour;
      colour = Colors.white;
    }

    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          color: colour,
        ),
        width: markerSize,
        height: markerSize,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColour,
            ),
            width: 8,
            height: 8,
          ),
        ),
      ),
    );
  }

  /*String _placeAvailability(BuildContext context, Place place, int dayIndex) {
    final availability = place.placeAvailabilities
            ?.where((element) => element.dayId == dayIndex) ??
        [];
    if (availability.isEmpty) {
      return S.of(context).closed;
    }
    return '${availability.first.startAt} - ${availability.first.endAt}';
  }*/

  List _placeAvailability(BuildContext context, Place place, int dayIndex) {
    var times = [];
    final availabilities = place.placeAvailabilities?.where((element) => element.dayId == dayIndex) ?? [];
    if (availabilities.isEmpty) {
      times.add(S.of(context).closed);
      return times;
    }
    if (availabilities.length == 1) {
      var time = '${availabilities.first.startAt} - ${availabilities.first.endAt}';
      times.add(time);
      return times;
    }

    return availabilities.map((a)=> '${a.startAt} - ${a.endAt}').toList();
  }
}
