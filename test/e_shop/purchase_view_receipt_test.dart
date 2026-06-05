

import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/e_shop/purchases_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/e_shop/purchase_view_receipt.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPurchasesStore extends Mock implements PurchasesStore{
  @override
  Future<void> getOrderData(ApiProvider apiProvider, int orderId) async {
  }
  @override
  bool get isLoading {
    return false;
  }
}

void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    GetIt.instance.registerSingleton<PurchaseViewReceiptParams>(PurchaseViewReceiptParams(222, 'none'));

    var orderModel = Order(
      id: null,
      customerId: null,
      pharmacyId: null,
      orderType: null,
      subTotal: null,
      deliveryFee: null,
      orderTotal: null,
      orderStatus: null,
      createdAt: '2012-02-27 13:27:00',
      updatedAt: null,
      products: [],
      pharmacy: null,
      pharmacyCurrency: null,
    );

    await configureDependencies(dev.name);

    if(GetIt.I.isRegistered<PurchasesStore>()){
      GetIt.I.unregister<PurchasesStore>();
    }
    GetIt.instance.registerSingleton<PurchasesStore>(MockPurchasesStore());
    when(()=> GetIt.instance.get<PurchasesStore>().orderDetails).thenReturn(orderModel);
    //when(()=> GetIt.instance.get<PurchasesStore>().getOrderData(any(), any())).thenReturn(Future.value(1));
  });
  testWidgets('purchase view receipt test', (WidgetTester tester) async{
    var mainWidget = PurchaseViewReceipt(params: GetIt.instance.get<PurchaseViewReceiptParams>(), services: GetIt.instance.get<PurchaseViewReceiptServices>());
    var app = MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: mainWidget
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseViewReceipt), findsOneWidget);
  });
}