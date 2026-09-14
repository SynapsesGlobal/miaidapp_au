import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:gallery_saver/files.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/main.dart';
import 'package:miaid/services/delivery_availability_service.dart';
import 'package:miaid/services/facebook_service.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
part 'cart_store.g.dart';

@singleton
class CartEShopStore = _CartEShopStore with _$CartEShopStore;

abstract class _CartEShopStore with Store {
  _CartEShopStore();

  TextEditingController deliveryAddressController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController collectInstructionsController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  CountryCode? selectedCountry;

  @observable
  ActiveSubscriptionStore? activeSubscriptionStore;

  @observable
  int goBack = 1;

  @observable
  int orderCreated = 1;

  /// 药房订单寄送运费，由 checkDeliveryAvailable 下发（setDeliveryAvailability 写入），
  /// 不再读国家级运费配置和会员免运费规则；后端下单时按同一配置强制计算
  @observable
  /// App 内没有默认值：后端未下发时 deliveryAvailable 为 false，寄送入口不会出现，这两个值也不会被用到
  double deliveryFee = 0;

  /// 寄送半径（米），同样由后端下发；收货地址与药店直线距离不得超过它
  double deliveryRadiusMeters = 0;

  /// 半径展示文本（"5" / "7.5"），提示文案用
  String get deliveryRadiusLabel => deliveryAvailability?.radiusLabel ?? '';

  @observable
  DeliveryFee? deliveryFeeDetails;

  @observable
  double subTotal = 0;

  @observable
  int deliveryOption = 0; // 1 is for Collect From Pharmacy, 2 is for Delivery

  @observable
  bool inRemoveMode = false;

  @observable
  bool isLoading = false;

  @observable
  bool termsAndConditions = false;

  @observable
  List<Map<Product, int>> cartItems =
      []; // key is product and value is quantity

  @observable
  String? currency;

  @observable
  String? prescriptionPath;

  @action
  void changeDeliveryOption(int option) {
    deliveryOption = option;
  }

  @action
  void changeTermsAndConditions() {
    termsAndConditions = !termsAndConditions;
  }

  @action
  void changeRemoveMode(bool removeMode) {
    inRemoveMode = removeMode;
  }

  @action
  void removeProduct(Product product) {
    late int pIndex;
    late int q;

    for (var i = 0; i < cartItems.length; i++) {
      if (cartItems[i].keys.first.id == product.id) {
        pIndex = i;
        q = cartItems[i].values.first;
        break;
      }
    }

    cartItems.removeAt(pIndex);
    cartItems = cartItems;

    LogEventService.removeFromCart(
      id: product.id!.toString(),
      currency: currency!,
      price: product.unitPrice!,
      name: product.name!,
      quantity: q,
      type: product.isPrescriptionItem! ? 'prescription' : 'product',
    );

    updateCharges();
  }

  Order? order;

  /// 最近一次成功创建的订单是否为到店自取：到店付款，不弹在线支付。
  /// 普通字段（非 @observable），随 orderCreated 变化一起被购物车页读取。
  bool lastOrderPayOnPickup = false;

  /// 进入药店前查询到的该药店配送能力（checkDeliveryAvailable：开关 + 运费 + 半径），
  /// 购物车页用它做初始值，避免页面先按"无选项"渲染再跳变。
  DeliveryAvailability? deliveryAvailability;
  int? deliveryAvailabilityPharmacyId;

  /// 药店坐标（来自 PharmacyLocation），用于地址联想的就近排序和寄送半径校验。
  /// 为空说明药店没有位置信息，此时不允许选择寄送。
  double? pharmacyLatitude;
  double? pharmacyLongitude;
  bool get hasPharmacyLocation => pharmacyLatitude != null && pharmacyLongitude != null;

  /// 用户从地址联想里选中的收货地址坐标；手动改动地址文本后清空，下单时必须有值
  double? deliveryLatitude;
  double? deliveryLongitude;
  bool get hasDeliveryCoordinates => deliveryLatitude != null && deliveryLongitude != null;

  void setDeliveryAvailability(
    int pharmacyId,
    DeliveryAvailability? response, {
    double? pharmacyLatitude,
    double? pharmacyLongitude,
  }) {
    if (deliveryAvailabilityPharmacyId != pharmacyId) {
      // 换了药店，之前选的收货坐标不再有意义
      clearDeliveryCoordinates();
    }
    deliveryAvailabilityPharmacyId = pharmacyId;
    deliveryAvailability = response;
    this.pharmacyLatitude = pharmacyLatitude;
    this.pharmacyLongitude = pharmacyLongitude;
    applyDeliveryAvailability(response);
  }

  /// 把后端下发的运费 / 半径写入 store；接口失败（null）时保留当前值
  @action
  void applyDeliveryAvailability(DeliveryAvailability? response) {
    if (response == null) return;
    deliveryAvailability = response;
    deliveryFee = response.deliveryFee;
    deliveryRadiusMeters = response.radiusMeters;
  }

  void setDeliveryCoordinates(double latitude, double longitude) {
    deliveryLatitude = latitude;
    deliveryLongitude = longitude;
  }

  void clearDeliveryCoordinates() {
    deliveryLatitude = null;
    deliveryLongitude = null;
  }

  @action
  bool? addItem(Product product, {String? curr, int quantity = 1}) {
    if (cartItems.isNotEmpty) {
      var p = null;
      var l = null;

      cartItems.forEach((element) {
        if (element.keys.first.pharmacyId != null) {
          p = element.keys.first.pharmacyId;
          l = element.keys.first.locationId;
        }
      });

      // adding a pharmacy product to cart, check if the product is from the same pharmacy
      // if (product.pharmacyId != p &&
      //     product.isPrescriptionItem! == false &&
      //     product.locationId != l) {
      //   return false;
      // }

      // DIFFERENT PHARMACY or LOCATION
      if (product.pharmacyId != p || product.locationId != l) {
        return false;
      }
    }
    if (curr != null) currency = curr;
    // checkIfProductAlreadyExist
    var alreadyExists = false;
    late int pIndex;
    for (var i = 0; i < cartItems.length; i++) {
      if (cartItems[i].keys.first.id == product.id) {
        alreadyExists = true;
        pIndex = i;
        break;
      }
    }

    if (alreadyExists) {
      var q = cartItems[pIndex].values.first;

      if (product.isPrescriptionItem!) {
        HttpExceptionNotifyUser.showInfo(
            S.of(navigatorKey.currentContext!).prescriptionItemAlreadyInCart);
      } else {
        cartItems[pIndex] = {product: quantity + q};

        LogEventService.addToCart(
          id: product.id!.toString(),
          currency: currency!,
          price: product.unitPrice!,
          name: product.name!,
          quantity: quantity + q,
          type: 'product',
        );
      }
    } else {
      var map = <Product, int>{product: quantity};
      cartItems.add(map);
      LogEventService.addToCart(
        id: product.id!.toString(),
        currency: currency!,
        price: product.unitPrice!,
        name: product.name!,
        quantity: quantity,
        type: product.isPrescriptionItem! ? 'prescription' : 'product',
      );
    }
    //developer.log('pharmacyID: ${cartItems.first.keys.first.pharmacy?.id}');
    //developer.log('pharmacyID: ${cartItems.first.keys.first.pharmacyId}');

    updateCharges();

    return null;
  }

  void updateCharges() {
    var total = 0.0;
    // var deliveryFeeTotal = 0.0;
    cartItems.forEach((mapItem) {
      var product = mapItem.keys.first;
      total = total + product.unitPrice! * mapItem.values.first.toDouble();
      //developer.log('delivery fee of the item: ${product.deliveryFees}');
      // deliveryFeeTotal = deliveryFeeTotal + (product.deliveryFees ?? 0.0);
    });
    subTotal = total;

    // 药房订单运费由后端下发（applyDeliveryAvailability 已写入 deliveryFee），
    // 与是否会员、国家运费配置无关；自取时购物车页不展示运费，下单也按 0 传
  }

  @action
  void decrementQuantity(Product product, {int decrement = 1}) {
    var alreadyExists = false;
    late int pIndex;
    for (var i = 0; i < cartItems.length; i++) {
      if (cartItems[i].keys.first.id == product.id) {
        alreadyExists = true;
        pIndex = i;
        break;
      }
    }

    if (alreadyExists) {
      var q = cartItems[pIndex].values.first;
      cartItems[pIndex] = {product: q - 1};

      LogEventService.removeFromCart(
        id: product.id.toString(),
        name: product.name!,
        price: product.unitPrice!,
        quantity: 1,
        currency: currency!,
        type: product.isPrescriptionItem! ? 'prescription' : 'product',
      );
    }
    cartItems = cartItems;
    updateCharges();
  }

  @action
  Future<void> createOrder(ApiProvider apiProvider) async {
    try {
      isLoading = true;
      await EasyLoading.show(
        status: S.of(navigatorKey.currentContext!).loading,
        maskType: EasyLoadingMaskType.black,
      );
      //developer.log('prescriptionImage: ${prescriptionPath}');

      //developer.log('pharmacy Id: ${cartItems.first.keys.first.pharmacyId}');
      var orders = [];
      cartItems.forEach((o) {
        var id = o.keys.first.id;
        var quanity = o.values.first;
        orders.add({'product_id': id, 'qty': quanity});
      });
      var subtotal = subTotal + (deliveryOption == 2 ? deliveryFee : 0);
      //developer.log('subtotal: $subtotal');

      LogEventService.beginCheckout(
        numItems: cartItems.length,
        currency: currency!,
        total: subtotal,
      );

      // 生成的 swagger 客户端参数固定且手工补丁易被 build_runner 覆盖，这里直接
      // 用 http 发同样的表单请求，以便寄送订单附带收货坐标（delivery_latitude/longitude）
      final body = <String, String>{
        'pharmacy_id': (cartItems.first.keys.first.pharmacyId ?? 0).toString(),
        'location_id': (cartItems.first.keys.first.locationId ?? 0).toString(),
        'order_type': deliveryOption.toString(),
        'sub_total': subTotal.toString(),
        'delivery_fee': deliveryOption == 1 ? 0.toString() : deliveryFee.toString(),
        'order_total': subtotal.toString(),
        'items': orders.toString(),
        'delivery_address': deliveryOption == 1
            ? collectInstructionsController.text
            : deliveryAddressController.text,
        'delivery_email': emailController.text,
        'delivery_mobile': ((selectedCountry?.dialCode ?? '') + phoneController.text),
        'delivery_name': nameController.text,
      };
      if (prescriptionPath != null) {
        body['prescription_image'] = prescriptionPath!;
      }
      if (deliveryOption == 2 && hasDeliveryCoordinates) {
        // 后端据此复核 5 公里范围并固定运费
        body['delivery_latitude'] = deliveryLatitude!.toString();
        body['delivery_longitude'] = deliveryLongitude!.toString();
      }

      final response = await http.post(
        Uri.parse(apiProvider.apiClient.client.baseUrl + '/orders/create'),
        headers: {
          'x-api-key': apiProvider.apiKey,
          'x-access-token': apiProvider.userProvider.user?.accessToken ?? '',
          'Accept': 'application/json',
        },
        body: body,
      );

      isLoading = false;
      await EasyLoading.dismiss();

      var json = <String, dynamic>{};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200 && json['payload'] is Map<String, dynamic>) {
        order = Order.fromJson(_coerceIntFields(json['payload'] as Map<String, dynamic>));
        // 到店自取订单后端不建支付记录、直接完成，购物车页据此跳过支付弹窗
        lastOrderPayOnPickup = deliveryOption == 1;
        orderCreated++;
      } else {
        // 422 校验失败（如超出 5 公里、药店不支持该方式）等：把后端 message 展示给用户
        var message = json['message'] as String? ?? '';
        final errors = json['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) message = first.first.toString();
        }
        await HttpExceptionNotifyUser.showError(
            message.isNotEmpty ? message : 'Something went wrong');
      }
    } catch (e) {
      isLoading = false;
      rethrow;
    }
  }

  /// 下单响应里的 order_type / order_status 可能是字符串（后端把表单值原样写回），
  /// 生成的 Order.fromJson 按 int 解析会抛 type cast 异常，这里先转成 int
  static Map<String, dynamic> _coerceIntFields(Map<String, dynamic> payload) {
    const intKeys = ['id', 'customer_id', 'pharmacy_id', 'order_type', 'order_status'];
    final fixed = Map<String, dynamic>.from(payload);
    for (final key in intKeys) {
      final value = fixed[key];
      if (value is String) fixed[key] = int.tryParse(value);
      if (value is double) fixed[key] = value.toInt();
    }
    return fixed;
  }

  @action
  dynamic fetchDeliveryFee(ApiProvider apiProvider) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    var countryCode = sharedPreferences.getString('countryCode');
    if (countryCode == null) {
      deliveryFeeDetails = null;
      return;
    }

    final response =
        await apiProvider.apiClient.getDeliveryFee(country_code: countryCode);
    deliveryFeeDetails =
        await ApiSuccessParser.payloadOrThrowWithMessage(response);

    // 药房订单运费由 checkDeliveryAvailable 下发，国家级配置只保留读取，不再覆盖 deliveryFee
    // print(deliveryFeeDetails);
  }

  @action
  Future<void> updatePrescriptionImage(
      ApiProvider apiProvider, XFile pickedFile) async {
    var request = http.MultipartRequest('POST',
        Uri.parse(apiProvider.apiClient.client.baseUrl + '/order/uploadImage'));
    request.files
        .add(await http.MultipartFile.fromPath('image', pickedFile.path));
    request.headers['x-access-token'] =
        apiProvider.userProvider.user!.accessToken!;
    request.headers['x-api-key'] = apiProvider.apiKey;
    var response = await apiProvider.apiClient.client.httpClient.send(request);
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final Map<String, dynamic> bodyJson = json.decode(body);
      var prescriptionImage = bodyJson['payload']['path'];
      prescriptionPath = prescriptionImage;
      // print('prescriptionImage: $prescriptionPath');
    } else {
      final body = await response.stream.bytesToString();
      final Map<String, dynamic> bodyJson = json.decode(body);
      final message = bodyJson['message'] ?? '';
      await HttpExceptionNotifyUser.showError(message);
      throw HttpException(response.statusCode, message);
    }
  }

  @action
  dynamic setSubscriptionStatus(ActiveSubscriptionStore subscriptionStatus) {
    activeSubscriptionStore = subscriptionStatus;
    // print('subscription status: $activeSubscriptionStore');
    return;
  }

  void resetEverything() {
    cartItems.clear();
    cartItems = cartItems;
    subTotal = 0;
    deliveryOption = 0;
    if (deliveryFeeDetails != null) {
      if (activeSubscriptionStore!.hasActiveSubscription == true) {
        if (activeSubscriptionStore!.activeCustomerSubscriptionDetail != null) {
          deliveryFee = double.parse(deliveryFeeDetails!.flatRateForMembers!);
        }

        if (activeSubscriptionStore!
            .activeCompanySubscriptionDetails!.isNotEmpty) {
          deliveryFee =
              double.parse(deliveryFeeDetails!.flatRateForCorporateMembers!);
        }
      } else {
        deliveryFee = double.parse(deliveryFeeDetails!.flatRate!);
      }
    } else {
      deliveryFee = 100;
    }

    if (prescriptionPath != null) {
      prescriptionPath = null;
    }

    inRemoveMode = false;
    isLoading = false;
    termsAndConditions = false;
  }

  void resetRemoveMode() {
    inRemoveMode = false;
  }

  @action
  void closeCart() {
    goBack++;
  }
}
