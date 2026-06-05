import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/cart_store.dart';
import 'package:miaid/store/e_shop/e_shop_store.dart';
import 'package:miaid/store/e_shop/location_details_store.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/utils.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/e_shop/purchase.dart';
import 'package:miaid/view/user/location/location.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/widget/custom_dialog.dart';
import 'package:miaid/widget/image_widget.dart';
import 'package:miaid/widget/popover.dart';
import 'package:mobx/mobx.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'dart:math' as math;
import 'dart:developer' as developer;

import '../../../api_utils/consts.dart';

class EShopParams {
  const EShopParams(this.key);

  final Key key;
}

@injectable
class EShopServices {
  EShopServices(this.api, this.store, this.appSettings, this.cartEShopStore,
      this.locationDetailsStore, this.activeSubscriptionStore);

  final ApiProvider api;
  final EShopStore store;
  final AppSettings appSettings;
  final LocationDetailsStore locationDetailsStore;
  final CartEShopStore cartEShopStore;
  final ActiveSubscriptionStore activeSubscriptionStore;
}

@injectable
class EShop extends StatefulWidget {
  EShop({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final EShopParams? params;
  final EShopServices services;

  @override
  _EShopState createState() => _EShopState();
}

class _EShopState extends State<EShop> with SingleTickerProviderStateMixin {
  late EShopStore eShopStore;
  late CartEShopStore cartEShopStore;

  late LocationDetailsStore locationDetailsStore;
  late List<ReactionDisposer> _disposers;
  bool isBottomSheetOpen = false;
  late MapController mapController;
  bool showOnlyCompleted = false;
  // var filterText = '';

  void showPharmacyDetailSheet(BuildContext context) async {
    var pharmacy = eShopStore.selectedPharmacy;

    if (!isBottomSheetOpen) {
      isBottomSheetOpen = true;
      await showModalBottomSheet<int>(
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.0),
        context: context,
        builder: (context) {
          return Popover(
            child: _pharmacyDetailBottomSheetLayout(pharmacy),
          );
        },
      ).whenComplete(() {
        eShopStore.selectedPharmacy = null;
        eShopStore.setMapPins();
        isBottomSheetOpen = false;
      });
    }
  }

  Widget _pharmacyDetailBottomSheetLayout(PharmacyLocation? pharmacy) {
    return Container(
      height: 220,
      child: (pharmacy != null) ? Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pharmacy.pharmacy!.name ?? '',
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20,),
            Row(children: [
              pharmacy.pharmacy!.coverUrl?.isEmpty ?? false ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/default_shop_image.png',
                  height: 80,
                  width: 80,
                )
              ) : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImageWidget(
                  imageUrl: pharmacy.pharmacy!.coverUrl ?? '',
                  height: 80,
                  width: 80,
                ),
              ),
              SizedBox(width: 24,),
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pharmacy.address ?? '', style: GoogleFonts.rubik(
                    color: AppColors.k003f51,
                    fontSize: 16,
                  ),),
                  SizedBox(height: 8,),
                  Row(children: [
                    Text(
                      pharmacy.pharmacy?.isOpen == 1
                          ? S.of(context).open
                          : S.of(context).closed,
                      style: GoogleFonts.rubik(
                        color: AppColors.k25d000,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    if (pharmacy
                            .pharmacy?.openingHours?.isNotEmpty ??
                        false)
                      Text(
                        '${pharmacy.pharmacy?.openingHours?.first.startAt?.substring(0, 5)} - ${pharmacy.pharmacy?.openingHours?.first.endAt?.substring(0, 5)}',
                        style: GoogleFonts.rubik(
                          color: AppColors.k8f8e94,
                          fontSize: 14,
                        ),
                      ),
                  ],),
                ],
              ),)
            ],),
            Expanded(
              child: Container(
                  child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8.0),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.k0cbcc5,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => getIt<EShopDetails>(
                                  param1: EShopDetailsParams(
                                pharmacy.pharmacy!.id!,
                                pharmacy,
                              )),
                            ),
                          );
                        },
                        child: Text(
                          S.of(context).view,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8.0),
                      child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                width: 2, color: AppColors.k0cbcc5),
                          ),
                          onPressed: () {
                            try {
                              Utils.launschURL(
                                  pharmacy.pharmacy!.webSite!);
                            } catch (e) {
                              //developer.log(e.toString());
                            }
                          },
                          child: Text(
                            S.of(context).website,
                            style: TextStyle(color: AppColors.k0cbcc5),
                          )),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8.0),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              width: 2, color: AppColors.k0cbcc5),
                        ),
                        onPressed: () {
                          try {
                            Utils.launschURL(
                                'tel:${pharmacy.pharmacy!.contactPersonPhone!}');
                          } catch (e) {
                            //developer.log(e.toString());
                          }
                        },
                        child: Text(
                          S.of(context).call,
                          style: TextStyle(color: AppColors.k0cbcc5),
                        ),
                      ),
                    ),
                  ),
                ],
              )),
            ),
          ],
        ),
      )
    : Center(
      child: Text(
        S.of(context).somethingWentWrong,
      ),
    ),
    );
  }

  @override
  void dispose() {
    _disposers.forEach((d) => d());
    super.dispose();
  }

  @override
  void activate() {
    // TODO: implement activate
    super.activate();
  }

  @override
  void initState() {
    super.initState();

    eShopStore = widget.services.store;
    locationDetailsStore = widget.services.locationDetailsStore;

    eShopStore.isLoading = true;
    //print timestamp
    eShopStore.getCurrentUserLocation(context);
    eShopStore.fetchPharmacies(widget.services.api, context);

    if (widget.services.api.userProvider.isLoggedIn) {
      cartEShopStore = widget.services.cartEShopStore;
      cartEShopStore.fetchDeliveryFee(widget.services.api);
      cartEShopStore
          .setSubscriptionStatus(widget.services.activeSubscriptionStore);
    }

    _disposers = [
      reaction(
        // Tell the reaction which observable to observe
        (_) => eShopStore.showPharmacyDetailDialog,
        // Run some logic with the content of the observed field
        (int value) {
          try {
            showPharmacyDetailSheet(context);
          } catch (e) {}
        },
      ),
      reaction(
        // Tell the reaction which observable to observe
        (_) => eShopStore.showPharmacyOnMap,
        (int value) {
          try {
            moveCameraToPharmacy();
          } catch (e) {}
        },
      ),
      reaction(
        // Tell the reaction which observable to observe
        (_) => locationDetailsStore.fetch,
        (int value) async {
          try {
            developer.log('fetch: $value');
            await eShopStore.fetchPharmacies(
              widget.services.api,
              context,
              country: locationDetailsStore.countrySelected,
              city: locationDetailsStore.citySelected,
            );
            await moveCameraToLocation();
          } catch (e) {
            //developer.log(e.toString());
          }
        },
      ),
      reaction(
        (_) => eShopStore.filterText,
        (_) {
          eShopStore.setMapPins();
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).eShop,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () {
                widget.services.locationDetailsStore
                    .resetLocationDetailsStore();
                Navigator.pop(context);
              },
              child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 13,
            ),
            child: Container(
              alignment: Alignment.centerRight,
              height: 36,
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (!widget.services.api.userProvider.isLoggedIn) {
                        showAlertDialog(context);

                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => getIt<PurchaseItem>(),
                        ),
                      );
                    },
                    child: navBarIcon(iconAssetName: 'ic_nb_purchases.png'),
                  ),
                  SizedBox(
                    width: 23,
                  ),
                  InkWell(
                    onTap: () async {
                      if (!widget.services.api.userProvider.isLoggedIn) {
                        showAlertDialog(context);

                        return;
                      }

                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => getIt<CartEShop>(),
                        ),
                      );
                      setState(() {});
                    },
                    child: Container(
                      height: 25,
                      width: 25,
                      child: Stack(children: [
                        navBarIcon(iconAssetName: 'ic_nb_cart_normal.png'),
                        if (widget.services.api.userProvider.isLoggedIn)
                          Observer(
                            builder: (_)  => cartEShopStore.cartItems.isNotEmpty ? Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(40),
                                  color: AppColors.ke63030,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(cartEShopStore.cartItems.length.toString(),
                                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              ),
                            ) : SizedBox(),
                          )
                      ],),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
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
                Expanded(
                  child: TextField(
                    controller: eShopStore.searchController,
                    onChanged: (txt) {
                      if (txt.isEmpty) {
                        // setting again the pharmacy list in grid view here
                        eShopStore.stoppedSearching();
                        // FocusScope.of(context).requestFocus(FocusNode());
                      }
                    },
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
                  ),
                ),
                SizedBox(width: 8),
                TapDebouncer(
                  onTap: () async {
                    eShopStore.searchPharmacy();
                  },
                  builder: (context, onTap) => InkWell(
                    onTap: onTap,
                    child: Image(
                      height: 44,
                      width: 44,
                      image: AssetImage('assets/images/btn_search.png'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width,
            height: 50,
            padding: const EdgeInsets.only(
              left: 20,
              right: 4,
              top: 16,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => getIt<Locations>(),
                        ),
                      );
                    },
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          width: 1,
                          color: AppColors.k0cbcc5,
                        ),
                      ),
                      padding: EdgeInsets.only(
                        left: 10,
                      ),
                      child: Row(
                        children: [
                          Image(
                            image: AssetImage(
                              'assets/images/ic_pharmacy_currentlocation.png',
                            ),
                          ),
                          Observer(
                            builder: (context) {
                              return Expanded(
                                child: SizedBox(
                                  child: Text(
                                    locationDetailsStore.isFilterSelected ? locationDetailsStore.citySelected! : S.of(context).location,
                                    style: GoogleFonts.rubik(
                                      color: AppColors.k0cbcc5,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                              );
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                Observer(
                  builder: (context) {
                    return _toggleButtons();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Observer(
            builder: (context) {
              if (eShopStore.viewType == 1) {
                return _mapBox();
              } else {
                if (eShopStore.isLoading) {
                  return Align(
                    alignment: Alignment.center,
                    child: progressIndicator(),
                  );
                } else {
                  return _eShopList(context);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _eShopList(BuildContext context) {
    return (eShopStore.searchingAPharmacy && eShopStore.searchPharmacies.isEmpty) || eShopStore.pharmacyList.isEmpty ? Text(S.of(context).noShopsAtLocation) : Expanded(
      child: MasonryGridView.count(
        padding: EdgeInsets.all(10),
        crossAxisCount: Utils.isPad(context) ? 3 :2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: eShopStore.searchingAPharmacy ? eShopStore.searchPharmacies.length : eShopStore.pharmacyList.length,
        itemBuilder: (context, index) {
          var pharmacy = eShopStore.searchingAPharmacy ? eShopStore.searchPharmacies[index] : eShopStore.pharmacyList[index];
          return eShopCard(
            pharmacyName: pharmacy.pharmacy!.name ?? '',
            contactNo: pharmacy.pharmacy!.phone ?? '',
            containerColor: AppColors.kffffff,
            address: pharmacy.address ?? '',
            productPhotoUrl: ImageWidget(imageUrl: pharmacy.pharmacy!.coverUrl ?? ''),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (context) => getIt<EShopDetails>(
                param1: EShopDetailsParams(
                  pharmacy.pharmacy!.id!,
                  pharmacy,
                ),
              ),),);
              setState(() {});
            },
          );
        },
      ),
    );
  }

  Widget _toggleButtons() {
    return Container(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(
          right: 5,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CupertinoSegmentedControl<String>(
            selectedColor: AppColors.k0cbcc5,
            unselectedColor: Colors.white,
            borderColor: AppColors.k0cbcc5,
            children: {
              '0': Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 0.5,
                    color: AppColors.k0cbcc5,
                  ),
                  color: eShopStore.viewType == 0
                      ? AppColors.k0cbcc5
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(5),
                    topLeft: Radius.circular(5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 4,
                  ),
                  child: Image(
                    image: AssetImage(eShopStore.viewType == 0
                        ? 'assets/images/ic_eshop_listview_normal.png'
                        : 'assets/images/ic_eshop_listview_active.png'),
                  ),
                ),
              ),
              '1': Container(
                decoration: BoxDecoration(
                  color: eShopStore.viewType == 1
                      ? AppColors.k0cbcc5
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(5),
                    topRight: Radius.circular(5),
                  ),
                  border: Border.all(
                    width: 0.5,
                    color: AppColors.k0cbcc5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 4,
                  ),
                  child: Image(
                    image: AssetImage(eShopStore.viewType == 1
                        ? 'assets/images/ic_eshop_mapview_normal.png'
                        : 'assets/images/ic_eshop_mapview_active.png'),
                  ),
                ),
              ),
            },
            onValueChanged: (value) async {
              eShopStore.changeView(int.parse(value));
            },
            groupValue: eShopStore.viewType.toString(),
          ),
        ),
      ),
    );
  }

  Widget eShopCard({
    required String pharmacyName,
      required String contactNo,
      required String address,
      required Widget productPhotoUrl,
      required Color containerColor,
      VoidCallback? onTap
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.k003f51.withOpacity(0.15),
              offset: Offset(0, 4,),
              blurRadius: 15,
              spreadRadius: 0,
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 12, right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 133,
                height: 133,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.k0cbcc5,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: productPhotoUrl,
                ),
              ),
              SizedBox(height: 16,),
              Text(
                pharmacyName,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4,),
              Text(
                contactNo,
                style: GoogleFonts.rubik(
                  color: AppColors.k5e5e5e,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
              SizedBox(
                height: 4,
              ),
              Text(
                address,
                style: GoogleFonts.rubik(
                  color: AppColors.kb1b1b1,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapBox() {
    return Observer(
      builder: (context) {
        mapController = MapController();
        //developer.log('pin markers: ${eShopStore.pinMarkers}');

        return Expanded(
          child: Container(
            child: Stack(
              children: [
                Container(
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                        center: eShopStore.selectedPharmacy != null &&
                                locationDetailsStore.isFilterSelected &&
                                eShopStore.pinMarkers.isNotEmpty
                            ? LatLng(
                                eShopStore.selectedPharmacy!.latitude!,
                                eShopStore.selectedPharmacy!.longitude!,
                              )
                            : locationDetailsStore.isFilterSelected &&
                                    eShopStore.pinMarkers.isNotEmpty
                                ? eShopStore.pinMarkers[0].marker.point
                                : eShopStore.searchingAPharmacy &&
                                        eShopStore.searchPharmacies.isNotEmpty
                                    ? LatLng(
                                        eShopStore
                                            .searchPharmacies.first.latitude!,
                                        eShopStore
                                            .searchPharmacies.first.longitude!,
                                      )
                                    : eShopStore.selectedPharmacy != null
                                        ? LatLng(
                                            eShopStore
                                                .selectedPharmacy!.latitude!,
                                            eShopStore
                                                .selectedPharmacy!.longitude!,
                                          )
                                        : eShopStore.mapDefaultCenter,
                        zoom:
                            locationDetailsStore.isFilterSelected ? 13.0 : 10.0,
                        maxZoom: 18),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.mapbox.com/styles/v1/abdullahriaz95/ckrx2pafw27bh17ryrlaoy65r/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                        additionalOptions: {
                          'accessToken': dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
                        },
                      ),
                      MarkerLayer(
                        markers:
                            eShopStore.pinMarkers.map((e) => e.marker).toList(),
                      ),
                    ],
                  ),
                ),
                _buildFab(),
                Positioned(
                  bottom: 40,
                  right: 8,
                  child: Container(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      heroTag: 'myLocation',
                      onPressed: () {
                        var latlng = LatLng(
                          eShopStore.currentLocation!.latitude,
                          eShopStore.currentLocation!.longitude,
                        );
                        mapController.move(latlng, mapController.zoom);

                        // widget.services.store.mapController.move(widget.services.store.latLng, widget.services.store.mapController.zoom);
                        // widget.services.store.search();
                      },
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.my_location_rounded,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                // Align(
                //   alignment: Alignment.bottomLeft,
                //   child: Padding(
                //     padding: const EdgeInsets.all(12.0),
                //     child: Image.asset(
                //       'assets/images/mapbox_logo.png',
                //       width: 80,
                //       fit: BoxFit.fitWidth,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  var _imageHeight = 46.0;
  Widget _buildFab() {
    return Positioned(
        top: -40.0,
        left: -40.0,
        child: AnimatedFab(
          onClick: _changeFilterState,
        ));
  }

  void _changeFilterState(text) {
    showOnlyCompleted = !showOnlyCompleted;
    //developer.log('showOnlyCompleted: $showOnlyCompleted' + text);

    widget.services.store.setFilterText(text);
    // setState(() {
    //   filterText = text;
    // });

    // setState(() {
    //   locationDetailsStore.isFilterSelected = !locationDetailsStore.isFilterSelected;
    // });
  }

  // using this function to move camera for searching a pharmacy
  void moveCameraToPharmacy() {
    if (eShopStore.viewType == 1) {
      // if found in pharmacyList, moving camera to the first pharmacy
      if (eShopStore.searchingAPharmacy &&
          eShopStore.searchPharmacies.isNotEmpty) {
        mapController.move(
            LatLng(eShopStore.searchPharmacies.first.latitude!,
                eShopStore.searchPharmacies.first.longitude!),
            14);
        // exit search mode, moving camera to the default center
      } else if (!eShopStore.searchingAPharmacy) {
        mapController.move(eShopStore.mapDefaultCenter, 10.0);
      }
    }
  }

  Future moveCameraToLocation() async {
    if (eShopStore.viewType == 1) {
      if (eShopStore.pinMarkers.isNotEmpty) {
        if (locationDetailsStore.isFilterSelected) {
          mapController.move(eShopStore.pinMarkers.first.marker.point, 13);
        } else {
          mapController.move(eShopStore.mapDefaultCenter, 14.0);
        }
      } else {
        mapController.move(eShopStore.mapDefaultCenter, 14.0);
      }
    }
  }

  void showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomDialog(
          title: S.of(context).alert,
          content: S.of(context).pleaseSignInFirst,
          buttonText: S.of(context).signIn,
          showCancel: false,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => getIt<SignIn>(),
              ),
            );
          },
        );
      },
    );
  }
}

class AnimatedFab extends StatefulWidget {
  final Function(String val) onClick;

  const AnimatedFab({Key? key, required this.onClick}) : super(key: key);

  @override
  _AnimatedFabState createState() => new _AnimatedFabState();
}

class _AnimatedFabState extends State<AnimatedFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  final double expandedSize = 160.0;
  final double hiddenSize = 20.0;

  static const distanceOptions = ["5km", "10km", "Cancel"];

  String selectedOption = '';

  @override
  void initState() {
    super.initState();
    _animationController = new AnimationController(
        vsync: this, duration: Duration(milliseconds: 200));

    _colorAnimation = new ColorTween(begin: Colors.blue, end: Colors.red)
        .animate(_animationController);

    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expandedSize,
      height: expandedSize,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _buildExpandedBackground(),
              for (var i = 0; i < distanceOptions.length; i++)
                _buildOption(distanceOptions[i],
                    math.pi * (i + 1) / (distanceOptions.length)),
              _buildFabCore(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFabCore() {
    var scaleFactor = 2 * (_animationController.value - 0.5).abs();
    return FloatingActionButton(
      heroTag: 'fab',
      onPressed: _onFabTap,
      backgroundColor: _colorAnimation.value,
      child: Transform(
        alignment: Alignment.center,
        transform: new Matrix4.identity()..scale(1.0, scaleFactor),
        child: _animationController.value > 0.5
            ? Icon(
                Icons.close,
                color: Colors.white,
                size: 26.0,
              )
            : selectedOption == distanceOptions[0] ||
                    selectedOption == distanceOptions[1]
                ? Text(
                    '$selectedOption',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                    ),
                  )
                : Icon(
                    Icons.filter_list,
                    color: Colors.white,
                    size: 26.0,
                  ),
      ),
    );
  }

  Widget _buildExpandedBackground() {
    var size =
        hiddenSize + (expandedSize - hiddenSize) * _animationController.value;
    return Positioned(
      left: (expandedSize - size) / 2,
      top: (expandedSize - size) / 2,
      child: Container(
        height: size,
        width: size,
        decoration:
            new BoxDecoration(shape: BoxShape.circle, color: Colors.pink),
      ),
    );
  }

  open() {
    if (_animationController.isDismissed) {
      _animationController.forward();
    }
  }

  close() {
    if (_animationController.isCompleted) {
      _animationController.reverse();
    }
  }

  _onFabTap() {
    if (_animationController.isDismissed) {
      open();
    } else {
      close();
    }
  }

  Widget _buildOption(String text, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Container(
            child: _animationController.value > 0.8
                ? TextButton(
                    onPressed: () {
                      widget.onClick(text);
                      selectedOption = text;
                      close();
                    },
                    // style: TextButton.styleFrom(
                    //   shape: CircleBorder(),
                    //   backgroundColor: Colors.pink,
                    //   padding: EdgeInsets.all(16.0),
                    // ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                      ),
                    ))
                : Container(),
          ),

          // IconButton(
          //   onPressed: null,
          //   icon: Transform.rotate(
          //     angle: -angle,
          //     child: Icon(
          //       icon,
          //       color: Colors.white,
          //     ),
          //   ),
          //   iconSize: 26.0,
          //   alignment: Alignment.center,
          //   padding: EdgeInsets.all(0.0),
          // ),
        ),
      ),
    );
  }
}
