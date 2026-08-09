import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
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
              countryId: locationDetailsStore.countryIdSelected,
              cityId: locationDetailsStore.cityIdSelected,
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
      backgroundColor: const Color(0xFFF6F7F9),
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
          // 顶部搜索/筛选区:白底 + 轻投影,与灰色背景上的列表卡片区分层次
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
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
            ],),
          ),
          SizedBox(height: 8),
          Observer(
            builder: (context) {
              if (eShopStore.viewType == 1) {
                return _mapBox();
              } else {
                if (eShopStore.isLoading) {
                  return Expanded(
                    child: Center(
                      child: progressIndicator(),
                    ),
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

  /// 用户到店铺的直线距离（米）,定位或店铺坐标缺失时返回 null
  double? _distanceMeters(PharmacyLocation pharmacy) {
    final location = eShopStore.currentLocation;
    final lat = pharmacy.latitude;
    final lng = pharmacy.longitude;
    if (location == null || lat == null || lng == null) return null;

    return Geolocator.distanceBetween(
      location.latitude, location.longitude, lat, lng);
  }

  /// 距离文案,如 "850 m" / "1.2 km"
  String? _distanceLabel(double? meters) {
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Widget _eShopList(BuildContext context) {
    final source = eShopStore.searchingAPharmacy
        ? eShopStore.searchPharmacies
        : eShopStore.pharmacyList;

    if (source.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                S.of(context).noShopsAtLocation,
                style: GoogleFonts.rubik(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 有定位时按距离从近到远排序,无坐标的店铺排在最后
    final pharmacies = List<PharmacyLocation>.from(source);
    if (eShopStore.currentLocation != null) {
      pharmacies.sort((a, b) {
        final da = _distanceMeters(a);
        final db = _distanceMeters(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

    return Expanded(
      child: MasonryGridView.count(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
        crossAxisCount: Utils.isPad(context) ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: pharmacies.length,
        itemBuilder: (context, index) => _buildPharmacyCard(pharmacies[index]),
      ),
    );
  }

  Widget _buildPharmacyCard(PharmacyLocation pharmacy) {
    final distance = _distanceLabel(_distanceMeters(pharmacy));
    final name = pharmacy.pharmacy?.name ?? '';
    final phone = pharmacy.pharmacy?.phone ?? '';
    final address = pharmacy.address ?? '';
    final coverUrl = pharmacy.pharmacy?.coverUrl ?? '';
    final isOpen = pharmacy.pharmacy?.isOpen == 1;
    final hours = pharmacy.pharmacy?.openingHours;
    final startAt = (hours?.isNotEmpty ?? false) ? hours!.first.startAt : null;
    final endAt = (hours?.isNotEmpty ?? false) ? hours!.first.endAt : null;
    final hoursLabel =
        ((startAt?.length ?? 0) >= 5 && (endAt?.length ?? 0) >= 5)
            ? '${startAt!.substring(0, 5)} - ${endAt!.substring(0, 5)}'
            : null;

    Widget coverPlaceholder() => Image.asset(
          'assets/images/default_shop_image.png',
          fit: BoxFit.cover,
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute<void>(
            builder: (context) => getIt<EShopDetails>(
              param1: EShopDetailsParams(
                pharmacy.pharmacy!.id!,
                pharmacy,
              ),
            ),
          ),);
          setState(() {});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图内缩留白,避免图片贴边显得拥挤
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: coverUrl.isEmpty
                      ? coverPlaceholder()
                      : CachedNetworkImage(
                          fit: BoxFit.cover,
                          imageUrl: coverUrl,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFEDEFF2),
                            child: Icon(Icons.storefront_outlined,
                                size: 32, color: Colors.grey.shade400),
                          ),
                          errorWidget: (context, url, error) =>
                              coverPlaceholder(),
                        ),
                ),
                // 底部渐变压暗,保证图上的店名可读
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.55, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10, right: 10, bottom: 8,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (distance != null)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(distance, style: GoogleFonts.rubik(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),),
                        ],
                      ),
                    ),
                  ),
              ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 营业状态 + 营业时间
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOpen
                              ? AppColors.k25d000
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? S.of(context).open : S.of(context).closed,
                        style: GoogleFonts.rubik(
                          color: isOpen
                              ? AppColors.k25d000
                              : Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hoursLabel != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hoursLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              color: AppColors.k8f8e94,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(address, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              height: 1.3,
                            ),),
                        ),
                      ],
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 14, color: AppColors.k0cbcc5),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(phone, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 12,
                            ),),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
