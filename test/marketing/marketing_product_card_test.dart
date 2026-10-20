import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/widget/marketing_product_card.dart';

/// 分类商品页 /category/products 返回的一条商品（含 company 对象）
const Map<String, dynamic> _product = {
  'companyId': 3,
  'productId': 7,
  'title': 'Hair transplant',
  'description': 'Natural results',
  'price': '1000.00',
  'discount_price': '900.00',
  'currency': 'CNY',
  'image': '',
  'company': {
    'companyId': 3,
    'name': 'Beisheng Hair',
    'image': '',
    'distance': 6.7,
    'categories': [{'cateId': 0, 'cateName': 'All Products'}],
  },
};

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: ListView(children: [child])),
    );

void main() {
  group('MarketingCompanyRow.distanceLabel', () {
    test('formats km with one decimal and metres under 1 km', () {
      expect(MarketingCompanyRow.distanceLabel(6.7), '6.7 km');
      expect(MarketingCompanyRow.distanceLabel('12'), '12.0 km');
      expect(MarketingCompanyRow.distanceLabel(0.35), '350 m');
      expect(MarketingCompanyRow.distanceLabel(null), isNull, reason: 'no coordinates → no badge');
      expect(MarketingCompanyRow.distanceLabel('n/a'), isNull);
    });
  });

  testWidgets('card shows product, prices and the company row; taps are routed separately', (tester) async {
    var productTaps = 0;
    var companyTaps = 0;
    final company = _product['company'] as Map;

    await tester.pumpWidget(_host(MarketingProductCard(
      product: _product,
      onTap: () => productTaps++,
      company: MarketingCompanyRow(company: company, onTap: () => companyTaps++),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Hair transplant'), findsOneWidget);
    expect(find.text('Natural results'), findsOneWidget);
    expect(find.text('900.00'), findsOneWidget);
    expect(find.text('CNY 1000.00'), findsOneWidget, reason: 'original price shown struck through when discounted');
    expect(find.text('Beisheng Hair'), findsOneWidget);
    expect(find.text('6.7 km'), findsOneWidget);

    await tester.tap(find.text('Hair transplant'));
    expect(productTaps, 1);
    expect(companyTaps, 0);

    await tester.tap(find.text('Beisheng Hair'));
    expect(productTaps, 1);
    expect(companyTaps, 1);
  });

  testWidgets('card without company (company product list) has no company row', (tester) async {
    final product = Map<String, dynamic>.from(_product)
      ..remove('company')
      ..['discount_price'] = '1000.00';

    await tester.pumpWidget(_host(MarketingProductCard(product: product, onTap: () {})));
    await tester.pumpAndSettle();

    expect(find.byType(MarketingCompanyRow), findsNothing);
    expect(find.text('CNY 1000.00'), findsNothing, reason: 'no struck-through price without a discount');
    expect(find.text('1000.00'), findsOneWidget);
  });
}
