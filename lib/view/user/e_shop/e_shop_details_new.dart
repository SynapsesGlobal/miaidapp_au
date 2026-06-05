import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/cart_store.dart';
import 'package:miaid/store/e_shop/e_shop_details_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/utils.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/product_details.dart';
import 'package:miaid/view/user/e_shop/purchase.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/widget/custom_dialog.dart';
import 'package:miaid/widget/image_widget.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class EShopDetailsParams {
  final int pharmacyId;
  final PharmacyLocation pharmacyLocation;

  EShopDetailsParams(this.pharmacyId, this.pharmacyLocation);
}

@injectable
class EShopDetailsServices {
  EShopDetailsServices(this.api, this.eShopDetailsStore, this.appSettings, this.cartEShopStore);

  final ApiProvider api;
  final EShopDetailsStore eShopDetailsStore;
  final AppSettings appSettings;
  final CartEShopStore cartEShopStore;
}

@injectable
class EShopDetails extends StatefulWidget {
  EShopDetails({
    @factoryParam this.params,
    required this.services,
  }) : super();

  final EShopDetailsParams? params;
  final EShopDetailsServices services;

  @override
  _EShopDetailsState createState() => _EShopDetailsState();
}

class _EShopDetailsState extends State<EShopDetails> {
  late EShopDetailsStore eShopDetailsStore;
  late CartEShopStore cartEShopStore;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    cartEShopStore = widget.services.cartEShopStore;
    eShopDetailsStore = widget.services.eShopDetailsStore;

    eShopDetailsStore.fetchShopDetails(widget.services.api, widget.params!.pharmacyId);
    eShopDetailsStore.getProductCategories(widget.services.api, widget.params!.pharmacyId, widget.params!.pharmacyLocation.id ?? 0);

    _scrollController.addListener(() {
      eShopDetailsStore.scrollPosition = _scrollController.position.pixels;
      var isBottom = _scrollController.position.atEdge && _scrollController.position.pixels > 0;
      if (isBottom && eShopDetailsStore.has_more && !eShopDetailsStore.isProductByCategoryLoading) {
        eShopDetailsStore.getProductsByCategoryIds(
            widget.services.api,
            eShopDetailsStore.currentCategoryId,
            widget.params!.pharmacyLocation.id ?? 0,
            eShopDetailsStore.pharmacyDetails?.id ?? 0
        );
      }
    });
  }

  void _restoreScrollPosition() {
    if (eShopDetailsStore.scrollPosition > 0) {
      _scrollController.jumpTo(eShopDetailsStore.scrollPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kffffff,
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
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 13,),
            child: Container(
              alignment: Alignment.centerRight,
              height: 36,
              child: Row(children: [
                InkWell(
                  onTap: () {
                    if (!widget.services.api.userProvider.isLoggedIn) {
                      showAlertDialog(context);
                      return;
                    }

                    Navigator.push(context, MaterialPageRoute<void>(
                      builder: (context) => getIt<PurchaseItem>(),
                    ),);
                  },
                  child: navBarIcon(iconAssetName: 'ic_nb_purchases.png'),
                ),
                SizedBox(width: 23,),
                InkWell(
                  onTap: () async {
                    if (!widget.services.api.userProvider.isLoggedIn) {
                      showAlertDialog(context);
                      return;
                    }

                    await Navigator.push(context, MaterialPageRoute<void>(
                      builder: (context) => getIt<CartEShop>(),
                    ),);
                    setState(() {});
                  },
                  child: Container(
                    height: 25,
                    width: 25,
                    child: Stack(children: [
                      navBarIcon(iconAssetName: 'ic_nb_cart_normal.png'),
                      if (widget.services.api.userProvider.isLoggedIn)
                        Observer(builder: (_) => cartEShopStore.cartItems.isNotEmpty ? Align(
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
                                Text(
                                  cartEShopStore.cartItems.length.toString(),
                                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ),
                        ) : SizedBox(),)
                    ],),
                  ),
                ),
              ],),
            ),
          ),
        ],
      ),
      body: Observer(builder: (context){
        _restoreScrollPosition();
        return eShopDetailsStore.isLoading ? Center(
          child: progressIndicator(),
        ) : CustomScrollView(
          controller: _scrollController,
          slivers: [
            eShopDetailsStore.showHeader ? SliverAppBar(
              elevation: 0,
              expandedHeight: 190.0,
              automaticallyImplyLeading: false,
              floating: true,
              pinned: false,
              stretch: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Align(alignment: Alignment.center, child: _pharmacyHeader(context),),
              ),
            ) : SliverToBoxAdapter(child: Offstage(),),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                child: Column(children: [
                  _searchBar(context),
                  _categoryBar(context),
                ],),
              ),
            ),

            eShopDetailsStore.isProductByCategoryLoading ? SliverToBoxAdapter(
              child: Center(child: Container(
                margin: EdgeInsets.only(top: 30),
                child: progressIndicator(),
              ),),) : SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  var product = eShopDetailsStore.products[index];
                  return _listItem(index, context, product);
                },
                    childCount: eShopDetailsStore.products.length
                ))
          ],
        );
      }),
    );
  }

  Widget _categoryBar(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: 60,
      child: ListView.builder(
          padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 10,),
          itemCount: eShopDetailsStore.productCategoryList.length,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          physics: BouncingScrollPhysics(),
          itemBuilder: (BuildContext context, index) => Row(children: [
            InkWell(
              onTap: () {
                eShopDetailsStore.products = [];
                eShopDetailsStore.page = 1;
                eShopDetailsStore.isLoading = false;
                eShopDetailsStore.has_more = true;
                eShopDetailsStore.scrollPosition = 0.0;
                eShopDetailsStore.categoryIndex = eShopDetailsStore.productCategoryList[index].id ?? 0;
                eShopDetailsStore.categoryName = eShopDetailsStore.productCategoryList[index].name ?? '';
                eShopDetailsStore.getProductsByCategoryIds(
                    widget.services.api,
                    eShopDetailsStore.productCategoryList[index].id ?? 0,
                    widget.params!.pharmacyLocation.id ?? 0,
                    eShopDetailsStore.pharmacyDetails?.id ?? 0
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: eShopDetailsStore.categoryIndex == eShopDetailsStore.productCategoryList[index].id ? AppColors.k0cbcc5 : AppColors.kffffff,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      width: 0.5,
                      color: eShopDetailsStore.categoryIndex != eShopDetailsStore.productCategoryList[index].id ? AppColors.k0cbcc5 : Colors.transparent
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
                padding: const EdgeInsets.only(left: 10, right: 10,),
                alignment: Alignment.center,
                child: Text(
                  eShopDetailsStore.productCategoryList[index].name ?? '',
                  style: GoogleFonts.rubik(
                    color: eShopDetailsStore.categoryIndex == eShopDetailsStore.productCategoryList[index].id ? AppColors.kffffff : AppColors.k010101,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10,),
          ],
          )),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Container(
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
            autofocus: false,
            controller: eShopDetailsStore.searchController,
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
            onTap: () async {
              await eShopDetailsStore.searchShop(
                  widget.services.api,
                  widget.params!.pharmacyId,
                  widget.params!.pharmacyLocation.id ?? 0
              );
            },
            builder: (BuildContext context, onTap) => InkWell(
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
    );
  }

  Widget _pharmacyHeader(BuildContext context) {
    return Container(
      height: 200,
      padding: EdgeInsets.only(top: 10, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Color.fromRGBO(90, 177, 255, 0.1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10,),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eShopDetailsStore.pharmacyDetails?.name ?? '', style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            )),
            Padding(
              padding: const EdgeInsets.only(top: 8,),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  (eShopDetailsStore.pharmacyDetails?.coverUrl?.isEmpty ?? true) ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/default_shop_image.png',
                      height: 100,
                      width: 100,
                    ),
                  ) : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImageWidget(
                        height: 100,
                        width: 100,
                        imageUrl: eShopDetailsStore.pharmacyDetails?.coverUrl ?? ''
                    ),
                  ),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 5,),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14,),
                          child: Text(widget.params?.pharmacyLocation.address.toString() ?? '', style: GoogleFonts.rubik(
                            color: AppColors.k747474,
                            fontSize: 14,
                          ),),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eShopDetailsStore.pharmacyDetails?.isOpen == 0 ? S.of(context).closed : S.of(context).open,
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k25d000,
                                    fontSize: 14,
                                  ),
                                ),
                                if (eShopDetailsStore.pharmacyDetails?.openingHours?.isNotEmpty ?? false)
                                  Text(
                                    '(${eShopDetailsStore.pharmacyDetails?.openingHours?.first.startAt?.substring(0, 5) ?? ''} - ${eShopDetailsStore.pharmacyDetails?.openingHours?.first.endAt?.substring(0, 5) ?? ''})',
                                    style: GoogleFonts.rubik(
                                      color: AppColors.kb1b1b1,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            Row(children: [
                              TapDebouncer(
                                onTap: () async {
                                  try {
                                    var url = eShopDetailsStore.pharmacyDetails!.webSite!.trim();
                                    if (!url.startsWith('http')) {
                                      url = 'https://' + url;
                                    }

                                    Utils.launschURL(url);
                                  } catch (e) {}
                                },
                                builder: (BuildContext context, onTap) => InkWell(
                                  onTap: onTap,
                                  child: Image(
                                    image: AssetImage('assets/images/btn_pharmacy_web.png'),
                                  ),
                                ),
                              ),
                              TapDebouncer(
                                onTap: () async {
                                  try {
                                    Utils.launschURL('tel:${eShopDetailsStore.pharmacyDetails!.phone!}');
                                  } catch (e) {}
                                },
                                builder: (BuildContext context, onTap) => InkWell(
                                  onTap: onTap,
                                  child: Image(image: AssetImage('assets/images/btn_pharmacy_phone.png'),),
                                ),
                              ),
                            ],),
                          ],
                        )
                      ],
                    ),
                  ),)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _productsList(BuildContext context) {
    return Expanded(child: ListView.builder(
      controller: _scrollController,
      itemCount: eShopDetailsStore.products.length,
      itemBuilder: (context, index) {
        var product = eShopDetailsStore.products[index];
        return _listItem(index, context, product);
      },
    ));
  }

  Widget _listItem(int index, BuildContext context, Product product) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TapDebouncer(
          onTap: () async {
            if (!eShopDetailsStore.products[index].isPrescriptionItem!) {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (context) => getIt<ProductDetails>(
                param1: ProductDetailsParams(
                    eShopDetailsStore.products[index].id ?? 0,
                    eShopDetailsStore.pharmacyDetails!.pharmacyCurrency!,
                    eShopDetailsStore.pharmacyDetails!.id!
                ),
              ),),);
              setState(() {});
            }
          },
          builder: (BuildContext context, onTap) => InkWell(
            onTap: onTap,
            child: Card(
              elevation: 4,
              child: Container(
                padding: EdgeInsets.only(left: 12.0, right: 12.0, top: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    product.productImages!.isEmpty ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/default_shop_image.png',
                          height: 80,
                          width: 80,
                        )
                    ) : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImageWidget(
                        imageUrl: product.productImages![0].image ?? '',
                        height: 80,
                        width: 80,
                      ),
                    ),
                    SizedBox(width: 12,),
                    Expanded(child: Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name ?? '', style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                          ),),
                          SizedBox(height: 8,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (product.isPrescriptionItem != true)
                                Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4.0),
                                      color: AppColors.kb1b1b1.withOpacity(0.2)
                                  ),
                                  padding: EdgeInsets.all(6.0),
                                  child: RichText(
                                    text: TextSpan(
                                      text: '${eShopDetailsStore.pharmacyDetails?.currency?.currency} ',
                                      style: TextStyle(color: AppColors.k696969, fontSize: 12),
                                      children: [
                                        TextSpan(
                                          text: product.unitPrice!.toStringAsFixed(2),
                                          style: GoogleFonts.rubik(
                                              color: AppColors.k010101,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              if (product.isPrescriptionItem == true)
                                Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4.0),
                                      color: AppColors.kb1b1b1.withOpacity(0.0)
                                  ),
                                  padding: EdgeInsets.all(6.0),
                                ),
                              OutlinedButton(
                                onPressed: () {
                                  if (!widget.services.api.userProvider.isLoggedIn) {
                                    showAlertDialog(context);
                                    return;
                                  }
                                  var modifiedProduct = product;

                                  if (product.isPrescriptionItem == true) {
                                    modifiedProduct = product.copyWith(
                                        pharmacyId: eShopDetailsStore.pharmacyDetails!.id,
                                        pharmacy: eShopDetailsStore.pharmacyDetails
                                    );
                                  }

                                  var samePharmacy;
                                  setState(() {
                                    samePharmacy = cartEShopStore.addItem(
                                      modifiedProduct,
                                      curr: eShopDetailsStore.pharmacyDetails?.pharmacyCurrency,
                                    );
                                  });

                                  if (samePharmacy != null) {
                                    if (!samePharmacy) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(
                                          S.of(context).multiplePharmacyIssue,
                                        ),),
                                      );
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    width: 1.0,
                                    color: AppColors.k0cbcc5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                ),
                                child: Text(
                                  S.of(context).addToCart,
                                  style: TextStyle(color: AppColors.k0cbcc5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
            Navigator.push(context, MaterialPageRoute<void>(
              builder: (context) => getIt<SignIn>(),
            ),);
          },
        );
      },
    );
  }
}


class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: 0,
      child: child,
    );
  }

  @override
  double get maxExtent => 110; // 固定头部的高度
  @override
  double get minExtent => 110;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}