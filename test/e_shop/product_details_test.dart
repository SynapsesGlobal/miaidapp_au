

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/product/product_details_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/e_shop/product_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProductDetailsStore extends Mock implements ProductDetailsStore{

  @override
  Future getProductDetails(ApiProvider apiProvider, int productId) {
    return Future.value(1);
  }

  @override
  bool get isLoading {
    return false;
  }
  @override
  int get tabindex {
    return 0;
  }
}

void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    var params = ProductDetailsParams(1, 'for test');
    await configureDependencies(dev.name);

    if(GetIt.I.isRegistered<ProductDetailsParams>()){
        GetIt.I.unregister<ProductDetailsParams>();
    }
    if(GetIt.I.isRegistered<ProductDetailsStore>()){
        GetIt.I.unregister<ProductDetailsStore>();
    }

    GetIt.I.registerSingleton<ProductDetailsParams>(params);
    GetIt.I.registerSingleton<ProductDetailsStore>(MockProductDetailsStore());

    var pharmacy = Pharmacy(
      id: null,
      userId: null,
      name: 'for test pharmacy name',
      phone: null,
      webSite: null,
      contactPerson: null,
      contactPersonPhone: null,
      contactPersonEmail: null,
      coverUrl: null,
      country: null,
      openingHours: null,
      isOpen: null,
      currency: null,
      pharmacyCurrency: null,
    );

    var product= Product(
      id: null,
      name: null,
      pharmacyId: null,
      productCategoryId: null,
      unitPrice: null,
      deliveryFees: null,
      generalInformation: null,
      warnings: null,
      ingredients: null,
      directions: null,
      productImages: null,
      productCategory: null,
      pharmacy: pharmacy,
      ordersQuantity: null,
    );

    when(()=> GetIt.I.get<ProductDetailsStore>().productDetails).thenReturn(product);

  });
  testWidgets('product details test', (WidgetTester tester) async{
    var mainWidget = ProductDetails(params: getIt.get<ProductDetailsParams>(), services: getIt.get<ProductDetailsServices>());
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

    //TODOFIXAA expect(find.byType(ProductDetails), findsOneWidget);
  });
}