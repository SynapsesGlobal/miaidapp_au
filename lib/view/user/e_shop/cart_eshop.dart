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
import 'package:miaid/component/nav_bar_icons.dart';
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
import 'package:flutter_mapbox_autocomplete/flutter_mapbox_autocomplete.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart' as pick;

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

  // 药店级配送方式开关（后台药店管理页配置，checkDeliveryAvailable 接口返回）。
  // 旧后端没有 pickup_status 字段时默认支持到店取货，保持升级前行为。
  bool get _pickupAvailable => deliveryAvailableResponse?.pickupStatus ?? true;
  bool get _deliveryAvailable => deliveryAvailableResponse?.status == true;

  @override
  void initState() {
    cartStore = widget.services.store;
    deliveryAvailableResponse = null;

    showNearCloseAlert = cartStore.cartItems.isNotEmpty ? isNearCloseTime(cartStore.cartItems.first.keys.first.pharmacy!.openingHours!) : false;

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
                topLeft: Radius.circular(16), topRight: Radius.circular(16)
              ),
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
      widget.services.api.apiClient.settingsCheckIsDeliveryAvailableForPharmacy(pharmacy: cartStore.cartItems.first.keys.first.pharmacy!.id!).then((value) {
        setState(() {
          deliveryAvailableResponse = value.body!;
        });
        _syncDeliveryOptionWithAvailability();
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
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        actions: [
          Observer(
            builder: (context) {
              return cartStore.cartItems.isEmpty ? SizedBox.shrink() : !cartStore.inRemoveMode ? TextButton(
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
              ) : TextButton(
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
      // 商品少时也撑满视口：汇总与条款贴近底部结算栏，页面不留大片空白
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Observer(
                builder: (context) {
                  if (cartStore.cartItems.isEmpty) {
                    return _emptyCart();
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _sectionTitle(
                                  S.of(context).cartProducts),
                            ),
                            // 商品件数徽章
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.keefeff,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                cartStore.cartItems.length.toString(),
                                style: GoogleFonts.rubik(
                                  color: AppColors.k0cbcc5,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 购物车条目有限，直接展开渲染；
                        // ListView(shrinkWrap) 在 IntrinsicHeight 下无法测量会抛异常
                        for (var i = 0;
                            i < cartStore.cartItems.length;
                            i++)
                          _listItem(i, context),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _deliveryOptionAndOrderSummary(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Observer(
        builder: (context) => cartStore.cartItems.isEmpty ? const SizedBox.shrink() : _orderTotalAndCheckout(context),
      ),
    );
  }

  Widget _emptyCart() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFEDEFF2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 44,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).cartEmpty,
              style: GoogleFonts.rubik(
                color: AppColors.k808080,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTotalAndCheckout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.k000000.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Observer(
                builder: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.of(context).orderTotal,
                      style: GoogleFonts.rubik(
                        color: AppColors.k8f8e94,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${cartStore.currency} ',
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          ((cartStore.deliveryOption == 2 && deliveryAvailableResponse?.status == true ? cartStore.deliveryFee : 0) + cartStore.subTotal).toStringAsFixed(2),
                          style: GoogleFonts.rubik(
                            color: AppColors.k0cbcc5,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF12CCD6), AppColors.k0cbcc5],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k0cbcc5.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
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
                      (containPrescription == true ? cartStore.prescriptionPath != null : true)) {
                    var pharmacy = cartStore.cartItems.first.keys.first.pharmacy;

                    if (cartStore.deliveryOption == 2) {
                      if (pharmacy!.isOpen! == 1) {
                        if (cartStore.formKey.currentState?.validate() ?? false) {
                          await cartStore.createOrder(widget.services.api);
                        }
                      } else {
                        // show alert
                        shopWarnAlert(context, cartStore, S.of(context).shopNotOpenAlert);
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
                        content: Text(S.of(context).agreeToTermsAndConditions),
                      ),
                    );
                  } else if (containPrescription == true && cartStore.prescriptionPath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(S.of(context).uploadPrescription),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 22,
                    right: 22,
                    top: 9,
                    bottom: 9,
                  ),
                  child: Text(
                    S.of(context).checkout,
                    style: GoogleFonts.rubik(
                      color: AppColors.kffffff,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// 配送方式标志加载后校正当前选择：
  /// - 选中的方式不可用则清空，避免带着不可用选项去下单；
  /// - 仅剩一种可用方式时自动选中，省一次点击。
  void _syncDeliveryOptionWithAvailability() {
    final option = cartStore.deliveryOption;
    if ((option == 1 && !_pickupAvailable) ||
        (option == 2 && !_deliveryAvailable)) {
      cartStore.changeDeliveryOption(0);
    }
    if (cartStore.deliveryOption == 0) {
      if (_pickupAvailable && !_deliveryAvailable) {
        cartStore.changeDeliveryOption(1);
      } else if (_deliveryAvailable && !_pickupAvailable) {
        cartStore.changeDeliveryOption(2);
      }
    }
  }

  Widget _deliveryOptionAndOrderSummary(BuildContext context) {
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
        _sectionTitle(S.of(context).deliveryOption),
        const SizedBox(height: 16),
        // 按药店后台配置动态展示可用的配送方式
        if (_pickupAvailable) ...[
          _deliveryOptionTile(
              1, S.of(context).inStore, Icons.storefront_outlined),
          cartStore.deliveryOption == 1
              ? collectInstructions()
              : SizedBox.shrink(),
        ],
        if (_deliveryAvailable) ...[
          _deliveryOptionTile(
              2, S.of(context).deliver, Icons.local_shipping_outlined),
          cartStore.deliveryOption == 2 ? delivery() : SizedBox.shrink(),
        ],
        if (deliveryAvailableResponse != null &&
            !_pickupAvailable &&
            !_deliveryAvailable)
          Text(
            S.of(context).noDeliveryOptions,
            style: GoogleFonts.rubik(
              color: AppColors.k5e5e5e,
              fontSize: 13,
            ),
          ),
        if (containsPrescription) ...[
          const SizedBox(height: 16),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(S.of(context).addPrescription),
                const SizedBox(height: 8),
                Text(
                  S.of(context).addPrescriptionDescription,
                  style: GoogleFonts.rubik(
                    color: AppColors.k5e5e5e,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: askImageSource,
                  child: Container(
                    height: 92,
                    width: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.kf4f4f4,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      image: cartStore.prescriptionPath == null ? null : DecorationImage(
                        image: CachedNetworkImageProvider(
                            widget.services.api.baseUrl + '/storage/' + cartStore.prescriptionPath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: cartStore.prescriptionPath == null ? Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.kb1b1b1,
                      size: 28,
                    ) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
        // 弹性空隙：商品少时把汇总和条款推向底部，页面不留大片空白
        const Spacer(),
        const SizedBox(height: 16),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(S.of(context).orderSummary),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context).subTotal,
                    style: GoogleFonts.rubik(
                      color: AppColors.k8f8e94,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${cartStore.currency} ${cartStore.subTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Observer(builder: (context) {
                if (cartStore.deliveryOption == 2 && deliveryAvailableResponse?.status == true) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          S.of(context).deliveryFees,
                          style: GoogleFonts.rubik(
                            color: AppColors.k8f8e94,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${cartStore.currency} ${cartStore.deliveryFee.toStringAsFixed(2)}',
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        )
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
            Expanded(
              // 点击文字也能切换勾选；条款链接的手势在内层，优先响应跳转
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => cartStore.changeTermsAndConditions(),
                child: Padding(
                padding: const EdgeInsets.only(left: 6),
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
                                  builder: (context) => getIt<TermsConditions>(),
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

        await cartStore.updatePrescriptionImage(widget.services.api, pickedFile);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.k010101.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品图
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 76,
              width: 76,
              color: const Color(0xFFEDEFF2),
              child: product.productImages == null ||
                      product.productImages!.isEmpty
                  ? Image.asset(
                      'assets/images/default_shop_image.png',
                      fit: BoxFit.cover,
                    )
                  : ImageWidget(imageUrl: product.productImages![0].image!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 价格：币种小字 + 金额主题色加粗
                    // 注意不能用 baseline 对齐：IntrinsicHeight 下会抛异常
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${cartStore.currency} ',
                            style: GoogleFonts.rubik(
                              color: AppColors.k8f8e94,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          product.unitPrice!.toStringAsFixed(2),
                          style: GoogleFonts.rubik(
                            color: AppColors.k0cbcc5,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    Observer(
                      builder: (context) {
                        return cartStore.inRemoveMode
                            ? InkWell(
                                onTap: () =>
                                    showAlertDialog(context, product),
                                child: Image.asset(
                                  'assets/images/btn_medicine_removeitem.png',
                                  width: 30,
                                ),
                              )
                            : _quantityStepper(index, product);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 数量步进器：与商品数量弹窗同一套描边样式
  Widget _quantityStepper(int index, Product product) {
    final qty = cartStore.cartItems[index].values.first;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: qty > 1
                ? () => cartStore.decrementQuantity(product)
                : null,
            child: SizedBox(
              width: 32,
              height: 28,
              child: Icon(
                CupertinoIcons.minus,
                size: 14,
                color: qty > 1 ? AppColors.k010101 : Colors.grey[350],
              ),
            ),
          ),
          Container(
            width: 36,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(
              qty.toString(),
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () =>
                cartStore.addItem(product, curr: cartStore.currency),
            child: SizedBox(
              width: 32,
              height: 28,
              child: Icon(
                CupertinoIcons.plus,
                size: 14,
                color: AppColors.k010101,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.k0cbcc5,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _deliveryOptionTile(int value, String label, IconData icon) {
    return Observer(
      builder: (_) {
        final selected = cartStore.deliveryOption == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // 再次点击已选中项可取消选择，保持原有 toggleable 行为
            onTap: () =>
                cartStore.changeDeliveryOption(selected ? 0 : value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: selected ? AppColors.keefeff : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      selected ? AppColors.k0cbcc5 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color:
                        selected ? AppColors.k0cbcc5 : AppColors.k8f8e94,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        selected ? AppColors.k0cbcc5 : AppColors.kb1b1b1,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.k010101.withOpacity(0.04),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget delivery() {
    return Form(
      key: cartStore.formKey,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
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
                      color: cartStore.deliveryAddressController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
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
                            backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                          onPressed: () async {
                            var sharedPreferences = await SharedPreferences.getInstance();
                            var countryCode = sharedPreferences.getString('countryCode');
                            countryCode ??= 'AU';
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapBoxAutoCompleteWidget(
                                  apiKey: dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
                                  hint: 'Select starting point',
                                  onSelect: (place) {
                                    cartStore.deliveryAddressController.text = place.placeName!;
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
                      color: cartStore.nameController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
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
                      color: cartStore.emailController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
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
                      color: cartStore.phoneController.text.trim().isNotEmpty ? AppColors.kb1b1b1 : AppColors.k010101,
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
                          builder: (country) => Row(
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
                              Image.asset('assets/images/ic_pharmacy_location_expand.png'),
                              SizedBox(
                                width: 6,
                              ),
                              Container(
                                height: 35,
                                width: 1,
                                color: AppColors.kb1b1b1.withOpacity(0.1),
                              )
                            ],
                          ),
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
      }
    );
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
                (showNearCloseAlert ? (S.of(context).okay) : (S.of(context).yes)),
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
        style: GoogleFonts.rubik(color: AppColors.k010101, fontWeight: FontWeight.w700),
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
