import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/services/facebook_service.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:mobx/mobx.dart';

part 'product_details_store.g.dart';

@injectable
class ProductDetailsStore = _ProductDetailsStore with _$ProductDetailsStore;

abstract class _ProductDetailsStore with Store {
  _ProductDetailsStore();
  Product? productDetails;

  @observable
  bool isLoading = false;

  @observable
  int tabindex = 0;

  @observable
  int quantity = 1;

  @observable
  int currentImageIndex = 0;

  @action
  void incrementQuantity() {
    quantity++;
  }

  @action
  void decrementQuantity() {
    quantity--;
  }

  @action
  void incrementImageIndex() {
    currentImageIndex++;
  }

  @action
  void decrementImageIndex() {
    currentImageIndex--;
  }

  @action
  void resetImageIndex() {
    currentImageIndex = 0;
  }

  @action
  void lastImageIndex() {
    currentImageIndex = productDetails!.productImages!.length - 1;
  }

  @action
  dynamic getProductDetails(
    ApiProvider apiProvider,
    int productId,
    int locationId,
    String currency,
  ) async {
    try {
      isLoading = true;
      final appSettings = getIt<AppSettings>();
      final language = appSettings.languageFull;

      var productDetailsResponse =
          await apiProvider.apiClient.eShopProductsGetViewProduct(
        product_id: productId,
        location_id: locationId,
        lang: language,
      );

      if (productDetailsResponse.statusCode == 200) {
        productDetails = productDetailsResponse.body!.payload;
        LogEventService.logViewProduct(
          id: productDetails!.id.toString(),
          name: productDetails!.name!,
          price: productDetails!.unitPrice!,
          currency: currency,
          brand: productDetails!.pharmacy!.name!,
        );
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
    }
  }
}
