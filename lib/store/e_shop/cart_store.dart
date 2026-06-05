import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/files.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/main.dart';
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

  @observable
  double deliveryFee = 100;

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

    if (activeSubscriptionStore!.hasActiveSubscription == true) {
      if (activeSubscriptionStore!.activeCustomerSubscriptionDetail != null) {
        if (deliveryFeeDetails!.allowFreeShipping! == true &&
            subTotal >=
                double.parse(
                    deliveryFeeDetails!.freeShippingPriceForMembers!)) {
          deliveryFee = 0.0;
        } else {
          deliveryFee = double.parse(deliveryFeeDetails!.flatRateForMembers!);
        }
      }

      if (activeSubscriptionStore!
          .activeCompanySubscriptionDetails!.isNotEmpty) {
        if (deliveryFeeDetails!.allowFreeShipping! == true &&
            subTotal >=
                double.parse(deliveryFeeDetails!
                    .freeShippingPriceForCorporateMembers!)) {
          deliveryFee = 0.0;
        } else {
          deliveryFee =
              double.parse(deliveryFeeDetails!.flatRateForCorporateMembers!);
        }
      }
    } else {
      if (deliveryFeeDetails!.allowFreeShipping! == true &&
          subTotal >= double.parse(deliveryFeeDetails!.freeShippingPrice!)) {
        deliveryFee = 0.0;
      } else {
        deliveryFee = double.parse(deliveryFeeDetails!.flatRate!);
      }
    }

    // deliveryFee = deliveryFeeTotal;
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

      var placeOrderResponse =
          await apiProvider.apiClient.eShopOrdersPostCreateAOrder(
        accept: 'application/json',
        delivery_fee:
            deliveryOption == 1 ? 0.toString() : deliveryFee.toString(),
        items: orders.toString(),
        order_total: (subtotal).toString(),
        order_type: deliveryOption,
        pharmacy_id: cartItems.first.keys.first.pharmacyId ?? 0,
        location_id: cartItems.first.keys.first.locationId ?? 0,
        sub_total: subTotal.toString(),
        delivery_address: deliveryOption == 1
            ? collectInstructionsController.text
            : deliveryAddressController.text,
        delivery_email: emailController.text,
        delivery_mobile:
            ((selectedCountry?.dialCode ?? '') + phoneController.text),
        delivery_name: nameController.text,
        prescription_image: prescriptionPath,
      );

      isLoading = false;
      // if (prescriptionPath != null) {
      //   prescriptionPath = null;
      // }

      //developer.log('cart store create order: ${placeOrderResponse.bodyString}');
      if (ApiSuccessParser.isSuccessfulWithPayload(placeOrderResponse)) {
        order = placeOrderResponse.body?.payload;
        orderCreated++;

        //developer.log('Create order SuccessFull');
        //developer.log('orderId: ${placeOrderResponse.body?.payload?.id}');
      } else {
        final errorJson = jsonEncode(placeOrderResponse.error,
            toEncodable: (e) => e.toString());
        Map<String, dynamic> errors = jsonDecode(errorJson);

        await HttpExceptionNotifyUser.showError(
            errors["message"] ?? 'Something went wrong');
        await ApiSuccessParser.payloadOrThrowWithMessage(placeOrderResponse);
      }
    } catch (e) {
      isLoading = false;
      rethrow;
    }
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

    // get subscription status
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
