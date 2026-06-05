import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/e_shop_payment_bottom_sheet.dart';
import 'package:miaid/services/facebook_service.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/cart_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/drawer/terms_and_cond.dart';
import 'package:miaid/widget/image_widget.dart';
import 'package:mobx/mobx.dart';
// import 'package:flutter_mapbox_autocomplete/flutter_mapbox_autocomplete.dart';
import 'package:flutter_mapbox_autocomplete/flutter_mapbox_autocomplete.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart' as pick;
import 'dart:developer' as developer;

import 'package:miaid/component/miaid_drawer.dart';

import '../../../api_utils/consts.dart';

class CartEShopParams {
  const CartEShopParams(this.key);

  final Key key;
}

@injectable
class CartEShopServices {
  CartEShopServices(this.api, this.store, this.appSettings);

  final ApiProvider api;
  final CartEShopStore store;
  final AppSettings appSettings;
}

@injectable
class CartEShop extends StatefulWidget {
  CartEShop({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final CartEShopParams? params;
  final CartEShopServices services;

  @override
  _CartEShopState createState() => _CartEShopState();
}

class _CartEShopState extends State<CartEShop> {
  late CartEShopStore cartStore;
  late List<ReactionDisposer> _disposers;
  late bool showNearCloseAlert;
  late IsDeliveryAvailableResponse? deliveryAvailableResponse;

  @override
  void initState() {
    cartStore = widget.services.store;
    deliveryAvailableResponse = null;

    showNearCloseAlert = cartStore.cartItems.isNotEmpty
        ? isNearCloseTime(
            cartStore.cartItems.first.keys.first.pharmacy!.openingHours!)
        : false;

    //developer.log('cart screen: ${cartStore.cartItems.length}');
    _disposers = [
      reaction((_) => widget.services.store.orderCreated, (_) async {
        var order = widget.services.store.order;
        if (order != null) {
          await showModalBottomSheet(
            backgroundColor: Colors.white,
            context: context,
            isDismissible: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            builder: (BuildContext context) => getIt<EShopPaymentBottomSheet>(
              param1: EShopPaymentBottomSheetParams(
                order: order,
                cartStore: cartStore,
              ),
            ),
          );
        }
      }),
      reaction((_) => widget.services.store.goBack, (_) async {
        //developer.log('going back');
        cartStore.resetEverything();
        Navigator.pop(context);
      }),
    ];

    if (cartStore.cartItems.isNotEmpty) {
      widget.services.api.apiClient
          .settingsCheckIsDeliveryAvailableForPharmacy(
              pharmacy: cartStore.cartItems.first.keys.first.pharmacy!.id!)
          .then((value) {
        setState(() {
          deliveryAvailableResponse = value.body!;
        });
      });

      LogEventService.viewCart(
        cart: cartStore.cartItems,
        currency: cartStore.currency ?? '',
        total: cartStore.subTotal,
      );
    }

    super.initState();
  }

  @override
  void dispose() {
    _disposers.forEach((d) => d());
    super.dispose();
  }

  bool isNearCloseTime(List<PharmacyHour> openHours) {
    var now = DateTime.now();
    var currentWeekday = now.weekday;

    var todayOpenHour = PharmacyHour();
    for (var day in openHours) {
      if (day.dayId == currentWeekday) {
        todayOpenHour = day;
        break;
      }
    }

    if (todayOpenHour.dayId != null) {
      var endTimeStr = todayOpenHour.endAt ?? '';
      var endDateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} $endTimeStr';
      var endDate = DateTime.parse(endDateStr);
      // 计算时间差
      var difference = endDate.difference(now);

      // 检查时间差是否在30分钟内
      if (difference.inMinutes <= 30) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Observer(
            builder: (context) {
              return cartStore.cartItems.isEmpty
                  ? SizedBox.shrink()
                  : !cartStore.inRemoveMode
                      ? TextButton(
                          onPressed: () {
                            cartStore.changeRemoveMode(true);
                          },
                          child: Text(
                            S.of(context).remove,
                            style: GoogleFonts.rubik(
                              color: AppColors.kfa0020,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.41,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: () {
                            cartStore.changeRemoveMode(false);
                          },
                          child: Text(
                            S.of(context).done,
                            style: GoogleFonts.rubik(
                              color: AppColors.k0cbcc5,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.41,
                            ),
                          ),
                        );
            },
          )
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          onTap: () {
            cartStore.resetRemoveMode();
            Navigator.pop(context);
          },
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        centerTitle: true,
        title: Text(
          S.of(context).cart,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Observer(
          builder: (context) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      cartStore.cartItems.isEmpty
                          ? _emptyCart()
                          : Container(
                              child: ListView.builder(
                                physics: NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: cartStore.cartItems.length,
                                itemBuilder: (BuildContext context, index) =>
                                    _listItem(index, context),
                              ),
                            ),
                      SizedBox(height: 20),
                      cartStore.cartItems.isEmpty
                          ? const SizedBox()
                          : _deliveryOptionAndOrderSummary(context)
                    ],
                  ),
                ),
                cartStore.cartItems.isEmpty
                    ? const SizedBox()
                    : Divider(
                        color: AppColors.k010101,
                        height: 0,
                      ),
                cartStore.cartItems.isEmpty
                    ? const SizedBox()
                    : _orderTotalAndCheckout(context)
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyCart() {
    return Container(
      child: Center(
        child: Text(
          S.of(context).cartEmpty,
          style: GoogleFonts.rubik(
            color: AppColors.kfa0020,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _orderTotalAndCheckout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Observer(
            builder: (context) {
              return Row(
                children: [
                  Text(
                    S.of(context).orderTotal,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '  ${cartStore.currency} ${((cartStore.deliveryOption == 2 && deliveryAvailableResponse?.status == true ? cartStore.deliveryFee : 0) + cartStore.subTotal).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              );
            },
          ),
          cartStore.isLoading
              ? Container()
              : TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColors.k0cbcc5),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  onPressed: () async {
                    //check if contain prescription

                    var containPrescription = false;
                    for (var item in cartStore.cartItems) {
                      if (item.keys.first.isPrescriptionItem == true) {
                        containPrescription = true;
                        break;
                      }
                    }

                    if (cartStore.deliveryOption != 0 &&
                        cartStore.termsAndConditions &&
                        cartStore.cartItems.isNotEmpty &&
                        (containPrescription == true
                            ? cartStore.prescriptionPath != null
                            : true)) {
                      var pharmacy =
                          cartStore.cartItems.first.keys.first.pharmacy;

                      if (cartStore.deliveryOption == 2) {
                        if (pharmacy!.isOpen! == 1) {
                          if (cartStore.formKey.currentState?.validate() ??
                              false) {
                            await cartStore.createOrder(widget.services.api);
                          }
                        } else {
                          // show alert
                          shopWarnAlert(context, cartStore,
                              S.of(context).shopNotOpenAlert);
                        }
                      } else {
                        if (pharmacy!.isOpen! == 1) {
                          if (showNearCloseAlert) {
                            // show close open alert
                            shopWarnAlert(
                              context,
                              cartStore,
                              S.of(context).shopNearCloseAlert,
                            );

                            return;
                          }

                          await cartStore.createOrder(widget.services.api);
                        } else {
                          // show alert
                          shopWarnAlert(
                            context,
                            cartStore,
                            S.of(context).shopNotOpenAlert,
                          );
                        }
                      }
                    } else if (cartStore.cartItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(S.of(context).cartIsEmpty),
                        ),
                      );
                    } else if (cartStore.deliveryOption == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(S.of(context).selectDeliveryOption),
                        ),
                      );
                    } else if (!cartStore.termsAndConditions) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text(S.of(context).agreeToTermsAndConditions),
                        ),
                      );
                    } else if (containPrescription == true &&
                        cartStore.prescriptionPath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(S.of(context).uploadPrescription),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Text(
                      S.of(context).checkout,
                      style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
        ],
      ),
    );
  }

  Widget _deliveryOptionAndOrderSummary(BuildContext context) {
    var radioList = <Widget>[];
    var optionsNumnber = 1;

    if (deliveryAvailableResponse?.status == true) {
      optionsNumnber = 2;
    }

    for (var i = 1; i <= optionsNumnber; i++) {
      if (i != 2 ||
          (i == 2 &&
              (deliveryAvailableResponse != null &&
                  deliveryAvailableResponse?.status == true))) {
        radioList.add(radiobuttonContainer(
          child: ListTile(
            minVerticalPadding: 10.0,
            contentPadding: EdgeInsets.all(0),
            dense: true,
            title: Text(
              i == 2 ? S.of(context).deliver : S.of(context).inStore,
              style: GoogleFonts.rubik(
                color: AppColors.k5e5e5e,
                fontSize: 14,
              ),
            ),
            leading: Radio(
              value: i,
              groupValue: cartStore.deliveryOption,
              activeColor: AppColors.k0cbcc5,
              toggleable: true,
              onChanged: i == 2
                  ? (int? value) {
                      cartStore.changeDeliveryOption(value ?? 0);
                    }
                  : (int? value) {
                      cartStore.changeDeliveryOption(value ?? 0);
                    },
            ),
          ),
        ));
      }
    }

    var containsPrescription = false;
    // to change here

    cartStore.cartItems.forEach((element) {
      if (element.keys.first.isPrescriptionItem!) {
        containsPrescription = true;
      }
    });

    if (containsPrescription == false) {
      if (cartStore.prescriptionPath != null) {
        cartStore.prescriptionPath = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).deliveryOption,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          height: 20,
        ),
        radioList.first,
        cartStore.deliveryOption == 1
            ? collectInstructions()
            : SizedBox.shrink(),
        (deliveryAvailableResponse?.status == true)
            ? radioList.last
            : SizedBox.shrink(),
        (cartStore.deliveryOption == 2 &&
                deliveryAvailableResponse?.status == true)
            ? delivery()
            : SizedBox.shrink(),
        if (containsPrescription)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
              ),
              Text(
                S.of(context).addPrescription,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Text(
                S.of(context).addPrescriptionDescription,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 14,
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Row(children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 20),
                  child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.rectangle, color: Colors.white),
                    child: Stack(
                      children: [
                        Container(
                          height: 84,
                          width: 84,
                          margin: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.k0cbcc5),
                            shape: BoxShape.rectangle,
                            image: cartStore.prescriptionPath == null
                                ? DecorationImage(
                                    image: AssetImage(
                                      'assets/images/ic_profile_uploadpicture.png',
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : DecorationImage(
                                    image: CachedNetworkImageProvider(
                                        widget.services.api.baseUrl +
                                            "/storage/" +
                                            cartStore.prescriptionPath!),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 30,
                          child: InkWell(
                            onTap: askImageSource,
                            child: Image(
                              image: AssetImage(
                                'assets/images/ic_profile_uploadpicture.png',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ],
          ),
        SizedBox(
          height: 20,
        ),
        Text(
          S.of(context).orderSummary,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          height: 16,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              S.of(context).subTotal,
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 12,
              ),
            ),
            Text(
              '${cartStore.currency} ${cartStore.subTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 16,
        ),
        Observer(builder: (context) {
          if (cartStore.deliveryOption == 2 &&
              deliveryAvailableResponse?.status == true) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).deliveryFees,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${cartStore.currency} ${cartStore.deliveryFee.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              ],
            );
          }
          return const SizedBox();
        }),
        SizedBox(
          height: 20,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Observer(
              builder: (_) {
                return SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: cartStore.termsAndConditions,
                    onChanged: (v) {
                      cartStore.changeTermsAndConditions();
                    },
                    checkColor: Colors.white,
                    activeColor: AppColors.k0cbcc5,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: AppColors.k0cbcc5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
            ),
            Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  width: MediaQuery.of(context).size.width - 70,
                  child: RichText(
                    textAlign: TextAlign.left,
                    softWrap: true,
                    text: TextSpan(
                      style: GoogleFonts.rubik(
                        color: AppColors.k5e5e5e,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(text: S.of(context).byPurchase),
                        TextSpan(
                          text: S.of(context).tandc,
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      getIt<TermsConditions>(),
                                ),
                              );
                            },
                          style: GoogleFonts.rubik(
                            color: AppColors.k0cbcc5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ],
    );
  }

  void askImageSource() {
    final action = CupertinoActionSheet(
      message: Text(
        S.of(context).pickPrescriptionPhotoFrom,
        style: TextStyle(
          fontSize: 13.0,
          color: AppColors.k8f8e94,
        ),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () async {
            await pickProfilePicture(pick.ImageSource.camera);
          },
          child: Text(
            S.of(context).camera,
            style: TextStyle(
              color: AppColors.k0cbcc5,
              fontSize: 24,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () async {
            await pickProfilePicture(pick.ImageSource.gallery);
          },
          child: Text(
            S.of(context).gallery,
            style: TextStyle(
              color: AppColors.k0cbcc5,
              fontSize: 24,
            ),
          ),
        )
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text(
          S.of(context).cancel,
          style: TextStyle(
            color: AppColors.k0cbcc5,
            fontSize: 20,
          ),
        ),
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> pickProfilePicture(pick.ImageSource source) async {
    Navigator.pop(context);
    final picker = pick.ImagePicker();

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      //developer.log(pickedFile.path);
      try {
        await EasyLoading.show(
          status: S.of(context).uploading,
          maskType: EasyLoadingMaskType.clear,
        );

        await cartStore.updatePrescriptionImage(
            widget.services.api, pickedFile);

        await HttpExceptionNotifyUser.showInfo(S.of(context).uploadSuccess);

        setState(() {});
        // refreshScreenState();
      } catch (e) {
        await HttpExceptionNotifyUser.showError(S.of(context).uploadFailed);
      } finally {
        await EasyLoading.dismiss();
      }
    }
  }

  Widget _listItem(int index, BuildContext context) {
    var product = cartStore.cartItems[index].keys.first;

    return Column(
      children: [
        SizedBox(
          height: 10,
        ),
        miAidCard(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Text(
                //   product.pharmacy!.name!.toString(),
                //   style: GoogleFonts.rubik(
                //     color: AppColors.k5e5e5e,
                //     fontSize: 14,
                //   ),
                // ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 70,
                        width: 70,
                        child: imageContainer(
                          productPhotoUrl: product.productImages == null ||
                                  product.productImages!.isEmpty
                              ? Image.asset(
                                  'assets/images/default_shop_image.png',
                                  height: 160,
                                  width: 160,
                                )
                              : ImageWidget(
                                  imageUrl: product.productImages![0].image!),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 15,
                            right: 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 14,
                                ),
                                child: Text(product.name!,
                                    style: GoogleFonts.rubik(
                                      color: AppColors.k010101,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: AppColors.kf4f4f4,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 7,
                                        right: 7,
                                        top: 3,
                                        bottom: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('${cartStore.currency} '),
                                          Text(
                                            product.unitPrice!
                                                .toStringAsFixed(2),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                  Observer(
                                    builder: (context) {
                                      return cartStore.inRemoveMode
                                          ? InkWell(
                                              onTap: () => showAlertDialog(
                                                  context, product),
                                              child: Image.asset(
                                                  'assets/images/btn_medicine_removeitem.png'),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    if (cartStore
                                                            .cartItems[index]
                                                            .values
                                                            .first >
                                                        1) {
                                                      cartStore
                                                          .decrementQuantity(
                                                              product);
                                                    }
                                                  },
                                                  child: buttonContainer(
                                                    Image.asset(cartStore
                                                                .cartItems[
                                                                    index]
                                                                .values
                                                                .first <=
                                                            1
                                                        ? 'assets/images/btn_medicine_quantity_minus_disabled.png'
                                                        : 'assets/images/btn_medicine_quantity_minus.png'),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 15, right: 15),
                                                  child: Text(
                                                    cartStore.cartItems[index]
                                                        .values.first
                                                        .toString(),
                                                    style: TextStyle(
                                                      color: Color(0xff010101),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    cartStore.addItem(
                                                      product,
                                                      curr: cartStore.currency,
                                                    );
                                                  },
                                                  child: buttonContainer(
                                                    Image.asset(
                                                        'assets/images/btn_medicine_quantity_add.png'),
                                                  ),
                                                ),
                                              ],
                                            );
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget imageContainer({required Widget productPhotoUrl}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: productPhotoUrl,
    );
  }

  Widget delivery() {
    return Form(
      key: cartStore.formKey,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).deliveryAddress,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: cartStore.deliveryAddressController.text
                              .trim()
                              .isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    readOnly: cartStore.isLoading ? true : false,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter delivery address';
                      } else {
                        return null;
                      }
                    },
                    controller: cartStore.deliveryAddressController,
                    onChanged: (value) {},
                    decoration: InputDecoration(
                      hintText: S.of(context).shippingAddress,
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                    ),
                  ),
                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(AppColors.k0cbcc5),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                          onPressed: () async {
                            var sharedPreferences =
                                await SharedPreferences.getInstance();
                            var countryCode =
                                sharedPreferences.getString('countryCode');
                            countryCode ??= 'AU';
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapBoxAutoCompleteWidget(
                                  apiKey: dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
                                  hint: 'Select starting point',
                                  onSelect: (place) {
                                    cartStore.deliveryAddressController.text =
                                        place.placeName!;
                                  },
                                  limit: 10,
                                  country: countryCode,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            S.of(context).findAddress,
                            style: GoogleFonts.rubik(
                              color: AppColors.kffffff,
                              fontSize: 14,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).name,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: cartStore.nameController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    readOnly: cartStore.isLoading ? true : false,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter receiver name';
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {},
                    controller: cartStore.nameController,
                    decoration: InputDecoration(
                      hintText: 'Ex: John Doe',
                      hintStyle: GoogleFonts.rubik(
                        color: AppColors.kb1b1b1,
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.only(
                        left: 16,
                        top: 5,
                        bottom: 5,
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).email,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: cartStore.emailController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    readOnly: cartStore.isLoading ? true : false,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an Email';
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {},
                    keyboardType: TextInputType.emailAddress,
                    controller: cartStore.emailController,
                    decoration: InputDecoration(
                      hintText: 'yourname@example.com',
                      hintStyle: GoogleFonts.rubik(
                        color: AppColors.kb1b1b1,
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.only(
                        left: 16,
                        top: 5,
                        bottom: 5,
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).phone,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.rubik(
                      color: cartStore.phoneController.text.trim().isNotEmpty
                          ? AppColors.kb1b1b1
                          : AppColors.k010101,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  TextFormField(
                    readOnly: cartStore.isLoading ? true : false,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter Phone';
                      } else {
                        return null;
                      }
                    },
                    onChanged: (value) {},
                    keyboardType: TextInputType.phone,
                    controller: cartStore.phoneController,
                    decoration: InputDecoration(
                      hintText: '1 23456 7890',
                      hintStyle: GoogleFonts.rubik(
                        color: AppColors.kb1b1b1,
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.only(
                        left: 0,
                        top: 5,
                        bottom: 5,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.kb1b1b1.withOpacity(0.5),
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
                      errorBorder: kErrorOutlineInputBorder,
                      focusedErrorBorder: kErrorFocusedOutlineInputBorder,
                      prefixIconConstraints: BoxConstraints(
                        maxWidth: 120,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: CountryCodePicker(
                          showDropDownButton: true,
                          alignLeft: false,
                          textStyle: GoogleFonts.rubik(
                            color: AppColors.kb1b1b1,
                            fontSize: 14,
                          ),
                          onChanged: (value) {
                            cartStore.selectedCountry = value;
                          },
                          initialSelection: 'au',
                          showCountryOnly: false,
                          closeIcon: Icon(
                            Icons.close,
                            color: AppColors.k0cbcc5,
                          ),
                          showOnlyCountryWhenClosed: false,
                          padding: EdgeInsets.zero,
                          builder: (country) {
                            return Row(
                              children: [
                                Image.asset(
                                  country!.flagUri!,
                                  package: 'country_code_picker',
                                  width: 32,
                                ),
                                SizedBox(
                                  width: 2,
                                ),
                                Text(
                                  country.dialCode!,
                                  style: GoogleFonts.rubik(
                                    color: AppColors.kb1b1b1,
                                    fontSize: 14,
                                  ),
                                ),
                                // SizedBox(
                                //   width: 6,
                                // ),
                                Image.asset(
                                    'assets/images/ic_pharmacy_location_expand.png'),
                                SizedBox(
                                  width: 6,
                                ),
                                Container(
                                  height: 35,
                                  width: 1,
                                  color: AppColors.kb1b1b1.withOpacity(0.1),
                                )
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder get kErrorFocusedOutlineInputBorder => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.kff3b30,
        ),
      );

  OutlineInputBorder get kErrorOutlineInputBorder => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors.kff3b30,
          width: 0.5,
        ),
      );

  void showAlertDialog(BuildContext context, Product product) {
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.2),
                  blurRadius: 10.0,
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset(
                    0.0, // Move to right 10  horizontally
                    4, // Move to bottom 10 Vertically
                  ),
                ),
              ],
            ),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              onPressed: () {
                cartStore.changeRemoveMode(false);
                Navigator.pop(context);
              },
              child: Text(
                S.of(context).no,
                style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Center(
            child: InkWell(
              onTap: () async {
                setState(() {
                  cartStore.removeProduct(product);
                });

                Navigator.pop(context);
              },
              child: Text(
                S.of(context).remove,
                style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).remove,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
            color: AppColors.k010101, fontWeight: FontWeight.w700),
      ),
      content: Text(
        '${S.of(context).removeAlertMessage}${product.name}${S.of(context).removeAlertMessage2}',
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 13,
        ),
      ),
      actions: [okButton],
    );

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        });
  }

  Widget collectInstructions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: TextFormField(
        maxLines: 6,
        readOnly: cartStore.isLoading ? true : false,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter receiver name';
          } else {
            return null;
          }
        },
        onChanged: (value) {},
        controller: cartStore.collectInstructionsController,
        decoration: InputDecoration(
          hintText: S.of(context).collectInstructions,
          hintStyle: GoogleFonts.rubik(
            color: AppColors.kb1b1b1,
            fontSize: 14,
          ),
          contentPadding: EdgeInsets.only(
            left: 16,
            top: 5,
            bottom: 5,
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
          errorBorder: kErrorOutlineInputBorder,
          focusedErrorBorder: kErrorFocusedOutlineInputBorder,
        ),
      ),
    );
  }

  void shopWarnAlert(
      BuildContext context, CartEShopStore eShopStore, String alertMessage) {
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.2),
                  blurRadius: 10.0,
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset(
                    0.0, // Move to right 10  horizontally
                    4, // Move to bottom 10 Vertically
                  ),
                ),
              ],
            ),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);

                await eShopStore.createOrder(widget.services.api);
              },
              child: Text(
                (showNearCloseAlert
                    ? (S.of(context).okay)
                    : (S.of(context).yes)),
                style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Center(
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: Text(
                S.of(context).cancel,
                style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).alert,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
            color: AppColors.k010101, fontWeight: FontWeight.w700),
      ),
      content: Text(
        alertMessage,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 13,
        ),
      ),
      actions: [okButton],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
