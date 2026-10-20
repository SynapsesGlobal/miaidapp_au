import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/services/targeted_push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const body = '''
  {"products": [
    {"pushKey": "7-1760000000", "productId": 7, "companyId": 3, "companyName": "Beisheng Hair",
     "title": "Hair transplant", "description": "Natural results", "instruction": "Book by phone", "currency": "CNY",
     "price": "1000.00", "discount_price": "900.00", "image": "https://x/storage/products/a.png",
     "location": "Guangzhou", "address": "Dongfeng East Rd 754", "distance": 6.7, "collected": true},
    {"pushKey": "9-1760000100", "productId": 9, "companyId": 3, "companyName": null,
     "title": "Hair care", "description": null, "currency": "CNY",
     "price": "200.00", "discount_price": "200.00", "image": "", "location": "Shenzhen",
     "address": "Nanshan", "distance": 13.2},
    {"pushKey": "", "productId": 11, "companyId": 3, "title": "broken row", "currency": "CNY",
     "price": "1", "discount_price": "1", "image": ""}
  ]}
  ''';

  group('TargetedProduct parsing', () {
    test('parses products', () {
      final products = TargetedProduct.listFromResponse(body);

      expect(products.map((p) => p.productId), ['7', '9'], reason: 'rows without pushKey are dropped');
      final first = products.first;
      expect(first.pushKey, '7-1760000000');
      expect(first.companyId, '3');
      expect(first.companyName, 'Beisheng Hair');
      expect(first.instruction, 'Book by phone');
      expect(first.discountPrice, '900.00');
      expect(first.hasDiscount, isTrue);
      expect(first.distance, closeTo(6.7, 0.001));
      expect(first.location, 'Guangzhou');
      expect(first.collected, isTrue);
      expect(products[1].collected, isFalse, reason: 'missing flag means not collected');

      expect(products[1].hasDiscount, isFalse);
      expect(products[1].companyName, isNull);
    });

    test('tolerates unexpected payloads', () {
      expect(TargetedProduct.listFromResponse('{"products": null}'), isEmpty);
      expect(TargetedProduct.listFromResponse('{}'), isEmpty);
      expect(TargetedProduct.listFromResponse('[]'), isEmpty);
    });
  });

  group('TargetedPushFilter', () {
    final products = TargetedProduct.listFromResponse(body);

    test('removes only products whose current push key was hidden', () {
      expect(
        TargetedPushFilter.select(products, hiddenKeys: {}).map((p) => p.productId),
        ['7', '9'],
      );
      expect(
        TargetedPushFilter.select(products, hiddenKeys: {'9-1760000100'}).map((p) => p.productId),
        ['7'],
      );
      // 后台关掉再开启推送 → key 变化 → 之前的「不再显示」失效
      expect(
        TargetedPushFilter.select(products, hiddenKeys: {'9-1750000000'}).map((p) => p.productId),
        ['7', '9'],
      );
    });
  });

  group('TargetedPushHistory', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists hidden keys across loads', () async {
      final history = await TargetedPushHistory.load();
      final products = TargetedProduct.listFromResponse(body);

      expect(history.visible(products).length, 2);

      await history.hide(products[1]);
      await history.hide(products[1]); // idempotent
      expect(history.visible(products).map((p) => p.productId), ['7']);

      final reloaded = await TargetedPushHistory.load();
      expect(reloaded.hiddenKeys, {'9-1760000100'});
    });

    test('keeps only the most recent hidden keys', () async {
      final history = await TargetedPushHistory.load();
      for (var i = 0; i < TargetedPushHistory.maxHiddenKeys + 5; i++) {
        await history.hide(TargetedProduct(
          pushKey: 'k$i', productId: '$i', companyId: '1', title: '', currency: '', price: '', discountPrice: '', image: '',
        ));
      }
      expect(history.hiddenKeys.length, TargetedPushHistory.maxHiddenKeys);
      expect(history.hiddenKeys, isNot(contains('k0')));
    });
  });

  group('TargetedPushTrigger', () {
    setUp(() => TargetedPushTrigger.reset());

    test('armed once at app start, re-armed by login', () {
      expect(TargetedPushTrigger.consume(), isTrue, reason: 'cold start');
      expect(TargetedPushTrigger.consume(), isFalse, reason: 'drawer → home / back to home');
      TargetedPushTrigger.arm();
      expect(TargetedPushTrigger.consume(), isTrue, reason: 'after login');
      expect(TargetedPushTrigger.consume(), isFalse);
    });
  });
}
