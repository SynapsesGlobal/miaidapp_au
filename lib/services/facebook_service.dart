import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/e_shop/cart_store.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';

class LogEventService {
  static late final FacebookAppEvents _facebook;

  static Future<void> init() async {
    _facebook = FacebookAppEvents();
  }

  static Future<void> logViewProduct({
    required String id,
    required String name,
    required double price,
    required String currency,
    required String brand,
  }) async {
    debugPrint('LogViewProduct ${{
      'name': 'view_content',
      'parameters': {
        'currency': currency,
        'price': price,
        'item_id': id,
        'item_name': name,
        'item_brand': brand,
      },
    }.toString()}');

    await _facebook.logViewContent(
      type: 'product',
      currency: currency,
      price: price,
      content: {
        'item_id': id,
        'item_name': name,
        'item_brand': brand,
      },
    );
  }

  static Future<void> addToCart({
    required String id,
    required String name,
    required double price,
    required int quantity,
    required String currency,
    required String type,
  }) async {
    debugPrint('LogAddToCart ${{
      'name': 'add_to_cart',
      'parameters': {
        'currency': currency,
        'price': price,
        'item_id': id,
        'item_name': name,
        'quantity': quantity,
        'type': type,
      },
    }.toString()}');

    await _facebook.logAddToCart(
      id: id,
      type: 'product',
      currency: currency,
      price: price,
      content: {
        'item_name': name,
        'quantity': quantity,
      },
    );
  }

  static Future<void> removeFromCart({
    required String id,
    required String name,
    required double price,
    required int quantity,
    required String currency,
    required String type,
  }) async {
    debugPrint('LogRemoveFromCart ${{
      'name': 'remove_from_cart',
      'parameters': {
        'currency': currency,
        'price': price,
        'item_id': id,
        'item_name': name,
        'quantity': quantity,
        'type': type,
      },
    }.toString()}');

    await _facebook.logEvent(
      name: 'remove_from_cart',
      parameters: {
        'currency': currency,
        'price': price,
        'item_id': id,
        'item_name': name,
        'quantity': quantity,
        'type': type,
      },
    );
  }

  static Future<void> viewCart({
    required List<Map<Product, int>> cart,
    required String currency,
    required double total,
  }) async {
    debugPrint('LogViewCart ${{
      'name': 'view_cart',
      'parameters': {
        'currency': currency,
        'price': total,
        'lines': cart.map((line) {
          final product = line.keys.first;
          final quantity = line.values.first;

          return {
            'quantity': quantity,
            'item_id': product.id,
            'item_name': product.name,
            'item_brand': product.pharmacy!.name,
            'price': product.unitPrice!.toDouble(),
            'currency': currency,
          };
        }).toList()
      },
    }.toString()}');

    await _facebook.logViewContent(
      type: 'cart',
      currency: currency,
      price: total,
      content: {
        'lines': cart.map((line) {
          final product = line.keys.first;
          final quantity = line.values.first;

          return {
            'quantity': quantity,
            'item_id': product.id,
            'item_name': product.name,
            'item_brand': product.pharmacy!.name,
            'price': product.unitPrice!.toDouble(),
            'currency': currency,
          };
        }).toList()
      },
    );
  }

  static Future<void> beginCheckout({
    required int numItems,
    required String currency,
    required double total,
  }) async {
    debugPrint('LogBeginCheckout ${{
      'name': 'begin_checkout',
      'parameters': {
        'currency': currency,
        'price': total,
        'num_items': numItems,
      },
    }.toString()}');
    await _facebook.logInitiatedCheckout(
      totalPrice: total,
      currency: currency,
      numItems: numItems,
    );
  }

  static Future<void> purchase({
    required List<Product> orderItems,
    required String currency,
    required double total,
    required String orderId,
  }) async {
    debugPrint('LogPurchase ${{
      'name': 'purchase',
      'parameters': {
        'currency': currency,
        'price': total,
        'order_id': orderId,
        'lines': orderItems.map((product) {
          // 再次下单时 order 来自订单列表接口，product.pivot/pharmacy/unitPrice
          // 可能为 null，不能用 ! 断言（否则扣款成功后在这里崩溃报错）
          final quantity = product.pivot?.qty ?? 1;

          return {
            'quantity': quantity,
            'item_id': product.id,
            'item_name': product.name,
            'item_brand': product.pharmacy?.name ?? '',
            'price': product.unitPrice?.toDouble() ?? 0,
            'currency': currency,
          };
        }).toList()
      },
    }.toString()}');

    await _facebook.logPurchase(
      amount: total,
      currency: currency,
      parameters: {
        'order_id': orderId,
        'lines': orderItems.map((product) {
          final quantity = product.pivot?.qty ?? 1;

          return {
            'quantity': quantity,
            'item_id': product.id,
            'item_name': product.name,
            'item_brand': product.pharmacy?.name ?? '',
            'price': product.unitPrice?.toDouble() ?? 0,
            'currency': currency,
          };
        }).toList()
      },
    );
  }

  static Future<void> purchaseSubscription({
    required String currency,
    required double total,
    required String orderId,
  }) async {
    debugPrint('LogPurchaseSubscription ${{
      'name': 'purchase',
      'parameters': {
        'currency': currency,
        'price': total,
        'order_id': orderId,
      },
    }.toString()}');

    await _facebook.logSubscribe(
      price: total,
      currency: currency,
      orderId: orderId,
    );
  }
}
