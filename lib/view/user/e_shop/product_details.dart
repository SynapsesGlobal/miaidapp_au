import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/cart_store.dart';
import 'package:miaid/store/product/product_details_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/widget/custom_dialog.dart';
import 'package:miaid/widget/image_widget.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class ProductDetailsParams {
  final int productId;
  final int locationId;
  final String currency;
  ProductDetailsParams(this.productId, this.currency, this.locationId);
}

@injectable
class ProductDetailsServices {
  ProductDetailsServices(this.api, this.store, this.appSettings);

  final ApiProvider api;
  final ProductDetailsStore store;
  final AppSettings appSettings;
}

@injectable
class ProductDetails extends StatefulWidget {
  ProductDetails({
    @factoryParam this.params,
    required this.services,
  }) : super();

  final ProductDetailsParams? params;
  final ProductDetailsServices services;

  @override
  _ProductDetailsState createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  late ProductDetailsStore productDetailsStore;

  @override
  void initState() {
    super.initState();
    productDetailsStore = widget.services.store;

    productDetailsStore.getProductDetails(
      widget.services.api,
      widget.params!.productId,
      widget.params!.locationId,
      widget.params!.currency,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.kffffff,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.kffffff,
          centerTitle: true,
          title: Text(
            S.of(context).viewDetails,
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
                  Navigator.pop(context);
                },
                child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
              );
            },
          ),
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      child: Observer(builder: (context) {
        return productDetailsStore.isLoading
            ? Container(
                height: MediaQuery.of(context).size.height,
                child: Align(
                  alignment: Alignment.center,
                  child: progressIndicator(),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TapDebouncer(
                        onTap: () async {
                          updatePreviousImageIndex();
                        },
                        builder: (context, onTap) => InkWell(
                          onTap: onTap,
                          child: Image(
                            image: AssetImage(
                                'assets/images/bnt_previous_next.png'),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                      ),
                      Container(
                        height: 160,
                        width: 160,
                        child: imageContainer(
                          productPhotoUrl: productDetailsStore
                                          .productDetails?.productImages ==
                                      null ||
                                  productDetailsStore
                                      .productDetails!.productImages!.isEmpty
                              ? Image.asset(
                                  'assets/images/default_shop_image.png',
                                  height: 160,
                                  width: 160,
                                )
                              : ImageWidget(
                                  imageUrl: productDetailsStore
                                      .productDetails!
                                      .productImages![
                                          productDetailsStore.currentImageIndex]
                                      .image!),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                      ),
                      TapDebouncer(
                        onTap: () async {
                          updateNextImageIndex();
                        },
                        builder: (context, onTap) => InkWell(
                          onTap: onTap,
                          child: Image(
                            image: AssetImage(
                                'assets/images/bnt_medicine_next.png'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 24,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: AppColors.k0cbcc5,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${widget.params?.currency} ',
                                  style: TextStyle(
                                    color: AppColors.kffffff,
                                  ),
                                ),
                                Text(
                                  productDetailsStore.productDetails!.unitPrice
                                      .toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppColors.kffffff,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Row(
                        //   mainAxisSize: MainAxisSize.min,
                        //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        //   children: [
                        //     InkWell(
                        //       onTap: () {
                        //         setState(() {
                        //           if (productDetailsStore.quantity > 1) {
                        //             productDetailsStore.decrementQuantity();
                        //           }
                        //         });
                        //       },
                        //       child: buttonContainer(
                        //         Image.asset(productDetailsStore.quantity <= 1
                        //             ? 'assets/images/btn_medicine_quantity_minus_disabled.png'
                        //             : 'assets/images/btn_medicine_quantity_minus.png'),
                        //       ),
                        //     ),
                        //     Padding(
                        //       padding:
                        //           const EdgeInsets.only(left: 15, right: 15),
                        //       child: Observer(
                        //         builder: (_) {
                        //           return Text(
                        //             productDetailsStore.quantity.toString(),
                        //             style: TextStyle(
                        //               color: AppColors.k010101,
                        //               fontWeight: FontWeight.bold,
                        //               fontSize: 14,
                        //             ),
                        //           );
                        //         },
                        //       ),
                        //     ),
                        //     InkWell(
                        //       onTap: () {
                        //         productDetailsStore.incrementQuantity();
                        //       },
                        //       child: buttonContainer(
                        //         Image.asset(
                        //             'assets/images/btn_medicine_quantity_add.png'),
                        //       ),
                        //     ),
                        //   ],
                        // )
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 17,
                    ),
                    child: Text(
                      productDetailsStore.productDetails?.name ?? '',
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: Text(
                      productDetailsStore.productDetails!.pharmacy!.name!,
                      style: GoogleFonts.rubik(
                        color: AppColors.k5e5e5e,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Container(
                    color: AppColors.k0cbcc5.withOpacity(0.1),
                    child: TabBar(
                      onTap: (index) {
                        productDetailsStore.tabindex = index;
                      },
                      labelColor: AppColors.k0cbcc5,
                      indicatorColor: AppColors.k0cbcc5,
                      unselectedLabelColor: AppColors.k5e5e5e,
                      labelStyle: GoogleFonts.rubik(
                        fontSize: 12,
                      ),
                      labelPadding: EdgeInsets.zero,
                      tabs: [
                        Tab(
                          text: S.of(context).general,
                        ),
                        Tab(
                          text: S.of(context).warning,
                        ),
                        Tab(
                          text: S.of(context).ingredient,
                        ),
                        Tab(
                          text: S.of(context).direction,
                        ),
                      ],
                    ),
                  ),
                  IndexedStack(
                    index: productDetailsStore.tabindex,
                    children: [
                      generalTab(),
                      warningTab(),
                      ingredientTab(),
                      directionTab(),
                    ],
                  ),
                  SizedBox(
                    height: 15,
                  ),
                  divider(),
                  SizedBox(
                    height: 15,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TapDebouncer(
                        onTap: () async {
                          if (!widget.services.api.userProvider.isLoggedIn) {
                            showAlertDialog(context);

                            return;
                          }

                          var cartEShopStore = getIt<CartEShopStore>();

                          setState(() {
                            cartEShopStore.addItem(
                              productDetailsStore.productDetails!,
                              curr: widget.params?.currency,
                              quantity: productDetailsStore.quantity,
                            );
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.k0cbcc5,
                              content: Text(
                                'Item added to Cart.',
                              ),
                            ),
                          );
                        },
                        builder: (context, onTap) => InkWell(
                          onTap: onTap,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 30),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  width: 0.5,
                                  color: AppColors.k0cbcc5,
                                )),
                            child: Text(
                              S.of(context).addToCart,
                              style: GoogleFonts.rubik(
                                color: AppColors.k0cbcc5,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (!widget.services.api.userProvider.isLoggedIn) {
                            showAlertDialog(context);

                            return;
                          }

                          var cartEShopStore = getIt<CartEShopStore>();
                          setState(() {
                            cartEShopStore.addItem(
                              productDetailsStore.productDetails!,
                              curr: widget.params?.currency,
                              quantity: productDetailsStore.quantity,
                            );
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => getIt<CartEShop>(),
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 16, horizontal: 40),
                          decoration: BoxDecoration(
                            color: AppColors.k0cbcc5,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            S.of(context).buyNow,
                            style: GoogleFonts.rubik(
                              color: AppColors.kffffff,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
                ],
              );
      }),
    );
  }

  Widget buttonContainer(Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: AppColors.kffffff,
        boxShadow: [
          BoxShadow(
            color: AppColors.k003f51.withOpacity(0.1),
            offset: Offset(
              0,
              4,
            ),
            blurRadius: 15,
            spreadRadius: 0,
          )
        ],
      ),
      child: child,
    );
  }

  Widget imageContainer({required Widget productPhotoUrl}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: productPhotoUrl,
    );
  }

  Widget generalTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data: productDetailsStore.productDetails?.generalInformation ?? '',
          ),
          // Text(
          //   productDetailsStore.productDetails?.generalInformation ?? '',
          //   style: GoogleFonts.rubik(
          //     letterSpacing: -0.09,
          //     color: AppColors.k010101,
          //     fontSize: 14,
          //   ),
          // ),
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }

  Widget warningTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data: productDetailsStore.productDetails?.warnings ?? '',
          ),
          // Text(
          //   productDetailsStore.productDetails?.warnings ?? '',
          //   style: GoogleFonts.rubik(
          //     letterSpacing: -0.09,
          //     color: AppColors.k010101,
          //     fontSize: 14,
          //   ),
          // ),
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }

  Widget ingredientTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data: productDetailsStore.productDetails?.ingredients ?? '',
          ),
          // Text(
          //   productDetailsStore.productDetails?.ingredients ?? '',
          //   style: GoogleFonts.rubik(
          //     letterSpacing: -0.09,
          //     color: AppColors.k010101,
          //     fontSize: 14,
          //   ),
          // ),
          SizedBox(
            height: 5,
          ),
        ],
      ),
    );
  }

  Widget directionTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 19,
      ),
      child: Column(
        children: [
          Html(
            data: productDetailsStore.productDetails?.directions ?? '',
          ),
          // Text(
          //   productDetailsStore.productDetails?.directions ?? '',
          //   style: GoogleFonts.rubik(
          //     letterSpacing: -0.09,
          //     color: AppColors.k010101,
          //     fontSize: 14,
          //   ),
          // ),
          SizedBox(
            height: 5,
          ),
        ],
      ),
    );
  }

  Widget divider() {
    return Container(
      height: 0.5,
      width: MediaQuery.of(context).size.width,
      color: AppColors.k5e5e5e.withOpacity(0.3),
    );
  }

  void updateNextImageIndex() {
    if (productDetailsStore.currentImageIndex <
        productDetailsStore.productDetails!.productImages!.length - 1) {
      // ++currentImageIndex;
      productDetailsStore.incrementImageIndex();
    } else if (productDetailsStore.currentImageIndex ==
        productDetailsStore.productDetails!.productImages!.length - 1) {
      productDetailsStore.resetImageIndex();
      // setState(() {
      //   currentImageIndex = 0;
      // });
    }
  }

  void updatePreviousImageIndex() {
    if (productDetailsStore.currentImageIndex > 0) {
      productDetailsStore.decrementImageIndex();
    } else if (productDetailsStore.currentImageIndex == 0) {
      productDetailsStore.lastImageIndex();
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
